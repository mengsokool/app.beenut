import Cocoa
import FlutterMacOS
import AVFoundation

class MainFlutterWindow: NSWindow {
  private static let autosaveName = "BeeNut.MainWindow"
  private var previewPlugin: ShmNv12PreviewPlugin?
  private var permissionsChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.title = "BeeNut"
    self.minSize = NSSize(width: 420, height: 300)
    self.collectionBehavior.insert(.fullScreenPrimary)
    self.setFrameAutosaveName(Self.autosaveName)
    self.setFrameUsingName(Self.autosaveName)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let previewRegistrar = flutterViewController.registrar(forPlugin: "ShmNv12PreviewPlugin")
    previewPlugin = ShmNv12PreviewPlugin(registrar: previewRegistrar)
    permissionsChannel = FlutterMethodChannel(
      name: "beenut/system_permissions",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    permissionsChannel?.setMethodCallHandler { call, result in
      switch call.method {
      case "cameraStatus":
        result(Self.cameraPermissionStatus())
      case "requestCamera":
        Self.requestCameraPermission(result: result)
      case "openCameraSettings":
        Self.openCameraSettings()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let themeChannel = FlutterMethodChannel(
      name: "beenut/theme",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    themeChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "updateTheme":
        if let theme = call.arguments as? String {
          self.updateTheme(theme)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Theme string expected", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  private func updateTheme(_ theme: String) {
    if #available(macOS 10.14, *) {
      switch theme {
      case "dark":
        self.appearance = NSAppearance(named: .darkAqua)
      case "light":
        self.appearance = NSAppearance(named: .aqua)
      default:
        self.appearance = nil
      }
    }
  }

  private static func cameraPermissionStatus() -> String {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      return "authorized"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    case .notDetermined:
      return "not_determined"
    @unknown default:
      return "unknown"
    }
  }

  private static func requestCameraPermission(result: @escaping FlutterResult) {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      result("authorized")
    case .denied:
      result("denied")
    case .restricted:
      result("restricted")
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
          result(granted ? "authorized" : "denied")
        }
      }
    @unknown default:
      result("unknown")
    }
  }

  private static func openCameraSettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
      NSWorkspace.shared.open(url)
    }
  }
}
