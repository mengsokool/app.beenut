import Cocoa
import CoreVideo
import FlutterMacOS
import IOSurface

private let previewMagic: UInt32 = 0x31565342
private let previewVersion: UInt32 = 1

final class ShmNv12PreviewPlugin: NSObject {
  private let textureRegistry: FlutterTextureRegistry
  private let channel: FlutterMethodChannel
  private var textures: [Int64: ShmNv12Texture] = [:]

  init(registrar: FlutterPluginRegistrar) {
    self.textureRegistry = registrar.textures
    self.channel = FlutterMethodChannel(
      name: "beenut/preview_texture",
      binaryMessenger: registrar.messenger)
    super.init()

    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "create":
      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String,
        !path.isEmpty
      else {
        result(FlutterError(code: "bad_args", message: "Missing shared memory path", details: nil))
        return
      }
      let texture = ShmNv12Texture(path: path, registry: textureRegistry)
      let textureId = textureRegistry.register(texture)
      texture.attach(textureId: textureId)
      textures[textureId] = texture
      texture.start()
      result(textureId)

    case "dispose":
      guard
        let args = call.arguments as? [String: Any],
        let textureId = args["textureId"] as? Int64
      else {
        result(FlutterError(code: "bad_args", message: "Missing textureId", details: nil))
        return
      }
      if let texture = textures.removeValue(forKey: textureId) {
        texture.stop()
        textureRegistry.unregisterTexture(textureId)
      }
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

final class ShmNv12Texture: NSObject, FlutterTexture {
  private let path: String
  private weak var registry: FlutterTextureRegistry?
  private let stateLock = NSRecursiveLock()
  private var timer: DispatchSourceTimer?
  private var textureId: Int64?
  private var fd: Int32 = -1
  private var mapped: UnsafeMutableRawPointer?
  private var mappedSize = 0
  private var mappedDevice: dev_t = 0
  private var mappedInode: ino_t = 0
  private var notifiedFrameIndex: UInt64 = 0
  private var copiedFrameIndex: UInt64 = 0
  private var pixelBuffers: [CVPixelBuffer?] = [nil, nil]
  private var activeBufferIndex = 0
  private var pixelBufferWidth = 0
  private var pixelBufferHeight = 0
  private var importedPixelBuffers: [UInt32: CVPixelBuffer] = [:]
  private var lastGoodIoSurfaceBuffer: CVPixelBuffer?
  private var lastPresentedBuffer: CVPixelBuffer?

  init(path: String, registry: FlutterTextureRegistry) {
    self.path = path
    self.registry = registry
    super.init()
  }

  func start() {
    timer?.cancel()
    let newTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
    newTimer.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(4))
    newTimer.setEventHandler { [weak self] in
      guard let self, let textureId = self.textureId else { return }
      if self.hasNewFrame() {
        self.registry?.textureFrameAvailable(textureId)
      }
    }
    timer = newTimer
    newTimer.resume()
  }

  func attach(textureId: Int64) {
    self.textureId = textureId
  }

  func stop() {
    timer?.cancel()
    timer = nil
    withStateLock {
      unmap(clearLastPresented: true)
    }
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    withStateLock {
      copyPixelBufferLocked()
    }
  }

  private func copyPixelBufferLocked() -> Unmanaged<CVPixelBuffer>? {
    guard ensureMapped(), let base = mapped else {
      return retainedLastPresentedBuffer()
    }
    let magic = base.load(fromByteOffset: 0, as: UInt32.self)
    let version = base.load(fromByteOffset: 4, as: UInt32.self)
    let width = Int(base.load(fromByteOffset: 12, as: UInt32.self))
    let height = Int(base.load(fromByteOffset: 16, as: UInt32.self))
    let yStride = Int(base.load(fromByteOffset: 20, as: UInt32.self))
    let uvStride = Int(base.load(fromByteOffset: 24, as: UInt32.self))
    let yOffset = Int(base.load(fromByteOffset: 28, as: UInt32.self))
    let uvOffset = Int(base.load(fromByteOffset: 32, as: UInt32.self))
    let frameIndex = base.load(fromByteOffset: 48, as: UInt64.self)
    let storageMode = base.load(fromByteOffset: 64, as: UInt32.self)
    let surfaceId = base.load(fromByteOffset: 68, as: UInt32.self)

    guard
      magic == previewMagic,
      version == previewVersion,
      frameIndex > 0,
      frameIndex.isMultiple(of: 2),
      width > 0,
      height > 0
    else {
      return retainedLastPresentedBuffer()
    }

    if storageMode == 1, surfaceId != 0,
       let pixelBuffer = ensureImportedPixelBuffer(surfaceId: surfaceId, width: width, height: height)
    {
      // Seqlock validation: re-read frameIndex after importing the surface.
      // If the daemon started writing a new frame, surfaceId may point to a
      // buffer the daemon is about to overwrite → show last good surface instead.
      let postFrameIndex = base.load(fromByteOffset: 48, as: UInt64.self)
      if postFrameIndex == frameIndex {
        lastGoodIoSurfaceBuffer = pixelBuffer
        lastPresentedBuffer = pixelBuffer
        copiedFrameIndex = frameIndex
        return Unmanaged.passRetained(pixelBuffer)
      }
      // Torn: return last known-good surface if available
      if let fallback = lastGoodIoSurfaceBuffer {
        lastPresentedBuffer = fallback
        return Unmanaged.passRetained(fallback)
      }
      if let fallback = retainedLastPresentedBuffer() {
        return fallback
      }
      // No fallback yet (first frame was torn) — use this one anyway
      lastPresentedBuffer = pixelBuffer
      copiedFrameIndex = frameIndex
      return Unmanaged.passRetained(pixelBuffer)
    }

    guard
      yOffset > 0,
      uvOffset > yOffset,
      uvOffset + uvStride * ((height + 1) / 2) <= mappedSize
    else {
      return retainedLastPresentedBuffer()
    }

    // Double-buffer: copy into back buffer, validate, then swap
    let backIndex = 1 - activeBufferIndex
    guard let backBuffer = ensurePixelBuffer(index: backIndex, width: width, height: height) else {
      return retainedLastPresentedBuffer()
    }

    if copiedFrameIndex != frameIndex {
      CVPixelBufferLockBaseAddress(backBuffer, [])
      if
        let yDst = CVPixelBufferGetBaseAddressOfPlane(backBuffer, 0),
        let uvDst = CVPixelBufferGetBaseAddressOfPlane(backBuffer, 1)
      {
        let dstYStride = CVPixelBufferGetBytesPerRowOfPlane(backBuffer, 0)
        let dstUvStride = CVPixelBufferGetBytesPerRowOfPlane(backBuffer, 1)
        let ySrc = base.advanced(by: yOffset)
        let uvSrc = base.advanced(by: uvOffset)
        for row in 0..<height {
          memcpy(yDst.advanced(by: row * dstYStride), ySrc.advanced(by: row * yStride), width)
        }
        for row in 0..<((height + 1) / 2) {
          memcpy(uvDst.advanced(by: row * dstUvStride), uvSrc.advanced(by: row * uvStride), width)
        }
      }
      CVPixelBufferUnlockBaseAddress(backBuffer, [])

      // Seqlock validation: re-read frameIndex after copy.
      // If it changed, the daemon overwrote the frame mid-copy (torn frame).
      let postFrameIndex = base.load(fromByteOffset: 48, as: UInt64.self)
      if postFrameIndex == frameIndex {
        // Frame is intact — swap back → front
        activeBufferIndex = backIndex
        copiedFrameIndex = frameIndex
      }
      // If torn, activeBufferIndex stays unchanged → front buffer still has last good frame
    }

    // Always return the active (front) buffer with last known-good frame
    if let frontBuffer = pixelBuffers[activeBufferIndex] {
      lastPresentedBuffer = frontBuffer
      return Unmanaged.passRetained(frontBuffer)
    }
    // First frame ever was torn — return back buffer as fallback
    lastPresentedBuffer = backBuffer
    return Unmanaged.passRetained(backBuffer)
  }

  private func retainedLastPresentedBuffer() -> Unmanaged<CVPixelBuffer>? {
    guard let lastPresentedBuffer else { return nil }
    return Unmanaged.passRetained(lastPresentedBuffer)
  }

  private func hasNewFrame() -> Bool {
    withStateLock {
      hasNewFrameLocked()
    }
  }

  private func hasNewFrameLocked() -> Bool {
    guard ensureMapped(), let base = mapped else { return false }
    let magic = base.load(fromByteOffset: 0, as: UInt32.self)
    let version = base.load(fromByteOffset: 4, as: UInt32.self)
    let frameIndex = base.load(fromByteOffset: 48, as: UInt64.self)
    if magic != previewMagic || version != previewVersion || frameIndex == 0 || !frameIndex.isMultiple(of: 2) {
      return false
    }
    if frameIndex == notifiedFrameIndex {
      return false
    }
    notifiedFrameIndex = frameIndex
    return true
  }

  private func ensurePixelBuffer(index: Int, width: Int, height: Int) -> CVPixelBuffer? {
    // If dimensions changed, invalidate both buffers
    if pixelBufferWidth != width || pixelBufferHeight != height {
      clearPixelBuffers()
      pixelBufferWidth = width
      pixelBufferHeight = height
      activeBufferIndex = 0
      copiedFrameIndex = 0
    }

    if let existing = pixelBuffers[index] {
      return existing
    }

    var newPixelBuffer: CVPixelBuffer?
    let attrs = [
      kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary,
      kCVPixelBufferMetalCompatibilityKey as String: true,
    ] as CFDictionary
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
      attrs,
      &newPixelBuffer)
    guard status == kCVReturnSuccess, let newPixelBuffer else { return nil }

    pixelBuffers[index] = newPixelBuffer
    return newPixelBuffer
  }

  private func ensureImportedPixelBuffer(surfaceId: UInt32, width: Int, height: Int) -> CVPixelBuffer? {
    if let importedPixelBuffer = importedPixelBuffers[surfaceId] {
      if
        CVPixelBufferGetWidth(importedPixelBuffer) == width,
        CVPixelBufferGetHeight(importedPixelBuffer) == height
      {
        return importedPixelBuffer
      }
      importedPixelBuffers.removeValue(forKey: surfaceId)
    }

    guard let surface = IOSurfaceLookup(surfaceId) else { return nil }
    var unmanagedPixelBuffer: Unmanaged<CVPixelBuffer>?
    let attrs = [
      kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary,
      kCVPixelBufferMetalCompatibilityKey as String: true,
    ] as CFDictionary
    let status = CVPixelBufferCreateWithIOSurface(
      kCFAllocatorDefault,
      surface,
      attrs,
      &unmanagedPixelBuffer)
    guard
      status == kCVReturnSuccess,
      let newPixelBuffer = unmanagedPixelBuffer?.takeRetainedValue(),
      CVPixelBufferGetWidth(newPixelBuffer) == width,
      CVPixelBufferGetHeight(newPixelBuffer) == height,
      CVPixelBufferGetPlaneCount(newPixelBuffer) >= 2
    else { return nil }

    importedPixelBuffers[surfaceId] = newPixelBuffer
    copiedFrameIndex = 0
    return newPixelBuffer
  }

  private func ensureMapped() -> Bool {
    var pathInfo = stat()
    if stat(path, &pathInfo) != 0 || pathInfo.st_size <= 0 {
      unmap(clearLastPresented: false)
      return false
    }

    var fdInfo = stat()
    if fd >= 0, fstat(fd, &fdInfo) == 0, mapped != nil {
      if
        Int(fdInfo.st_size) == mappedSize,
        fdInfo.st_dev == pathInfo.st_dev,
        fdInfo.st_ino == pathInfo.st_ino,
        mappedDevice == pathInfo.st_dev,
        mappedInode == pathInfo.st_ino
      {
        return true
      }
      unmap(clearLastPresented: false)
    } else if mapped != nil {
      unmap(clearLastPresented: false)
    }

    fd = open(path, O_RDONLY)
    if fd < 0 { return false }

    if fstat(fd, &fdInfo) != 0 || fdInfo.st_size <= 0 {
      unmap(clearLastPresented: false)
      return false
    }
    mappedSize = Int(fdInfo.st_size)
    let pointer = mmap(nil, mappedSize, PROT_READ, MAP_SHARED, fd, 0)
    if pointer == MAP_FAILED {
      unmap(clearLastPresented: false)
      return false
    }
    mapped = pointer
    mappedDevice = fdInfo.st_dev
    mappedInode = fdInfo.st_ino
    return true
  }

  private func unmap(clearLastPresented: Bool = true) {
    if let mapped {
      munmap(mapped, mappedSize)
      self.mapped = nil
    }
    if fd >= 0 {
      close(fd)
      fd = -1
    }
    mappedSize = 0
    mappedDevice = 0
    mappedInode = 0
    notifiedFrameIndex = 0
    copiedFrameIndex = 0
    clearPixelBuffers()
    activeBufferIndex = 0
    pixelBufferWidth = 0
    pixelBufferHeight = 0
    importedPixelBuffers.removeAll()
    lastGoodIoSurfaceBuffer = nil
    if clearLastPresented {
      lastPresentedBuffer = nil
    }
  }

  private func clearPixelBuffers() {
    if pixelBuffers.count == 2 {
      pixelBuffers[0] = nil
      pixelBuffers[1] = nil
    } else {
      pixelBuffers = [nil, nil]
    }
  }

  private func withStateLock<T>(_ body: () -> T) -> T {
    stateLock.lock()
    defer { stateLock.unlock() }
    return body()
  }
}
