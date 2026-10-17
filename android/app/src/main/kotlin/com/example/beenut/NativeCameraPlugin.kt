package com.example.beenut

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Handler
import android.os.Looper
import android.util.Size
import android.view.Surface
import androidx.annotation.Keep
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

class NativeCameraPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var textureRegistry: TextureRegistry? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var previewSurface: Surface? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val cameraExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()
    private var context: Context? = null
    private var activity: android.app.Activity? = null
    private var pendingCameraPermissionResult: MethodChannel.Result? = null

    private val permissionRequestCode = 4102
    private val requestedPermissionPreference = "beenut_camera_permission_requested"

    companion object {
        init {
            System.loadLibrary("beenut_core")
        }
    }

    private lateinit var permissionChannel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.example.beenut/native_camera")
        channel.setMethodCallHandler(this)
        permissionChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "beenut/system_permissions")
        permissionChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "cameraStatus" -> result.success(cameraPermissionStatus())
                "requestCamera" -> requestCameraPermission(result)
                "openCameraSettings" -> {
                    val ctx = context
                    if (ctx != null) {
                        try {
                            val intent = android.content.Intent(
                                android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                android.net.Uri.fromParts("package", ctx.packageName, null)
                            )
                            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            ctx.startActivity(intent)
                        } catch (_: Exception) {}
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        textureRegistry = flutterPluginBinding.textureRegistry
        context = flutterPluginBinding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        permissionChannel.setMethodCallHandler(null)
        releasePreview()
        textureRegistry = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener { requestCode, _, grantResults ->
            if (requestCode != permissionRequestCode) return@addRequestPermissionsResultListener false
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingCameraPermissionResult?.success(if (granted) "authorized" else "denied")
            pendingCameraPermissionResult = null
            true
        }
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        pendingCameraPermissionResult?.error(
            "activity_detached",
            "Camera permission request was interrupted.",
            null,
        )
        pendingCameraPermissionResult = null
        activity = null
    }

    private fun cameraPermissionStatus(): String {
        val ctx = context ?: return "unknown"
        if (ContextCompat.checkSelfPermission(ctx, android.Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return "authorized"
        }
        val requested = ctx.getSharedPreferences("beenut", Context.MODE_PRIVATE)
            .getBoolean(requestedPermissionPreference, false)
        return if (requested) "denied" else "not_determined"
    }

    private fun requestCameraPermission(result: MethodChannel.Result) {
        if (cameraPermissionStatus() == "authorized") {
            result.success("authorized")
            return
        }
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("activity_unavailable", "No Android activity is available to request camera permission.", null)
            return
        }
        if (pendingCameraPermissionResult != null) {
            result.error("permission_in_progress", "A camera permission request is already in progress.", null)
            return
        }
        context?.getSharedPreferences("beenut", Context.MODE_PRIVATE)?.edit()
            ?.putBoolean(requestedPermissionPreference, true)?.apply()
        pendingCameraPermissionResult = result
        ActivityCompat.requestPermissions(
            currentActivity,
            arrayOf(android.Manifest.permission.CAMERA),
            permissionRequestCode,
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAvailableCameras" -> {
                result.success(getAvailableCameras())
            }
            "createPreview" -> {
                val cameraId = call.argument<String>("cameraId")
                val previewInfo = createPreview(cameraId)
                result.success(previewInfo)
            }
            "startCamera" -> {
                val cameraId = call.argument<String>("cameraId")
                cameraExecutor.execute {
                    val success = nativeStartCamera(cameraId ?: "")
                    mainHandler.post { result.success(success) }
                }
            }
            "getDisplayRotation" -> {
                result.success(currentDisplayRotationDegrees())
            }
            "stopCamera" -> {
                cameraExecutor.execute {
                    nativeStopCamera()
                    mainHandler.post { result.success(null) }
                }
            }
            "updateEngineSettings" -> {
                val engineHandle = call.argument<Long>("engineHandle") ?: 0L
                val partType = call.argument<String>("partType") ?: ""
                val keywords = call.argument<String>("keywords") ?: ""
                val maxFps = call.argument<Double>("maxFps") ?: 6.0
                cameraExecutor.execute {
                    nativeUpdateEngineSettings(engineHandle, partType, keywords, maxFps)
                    mainHandler.post { result.success(null) }
                }
            }
            "releasePreview" -> {
                val oldEntry = textureEntry
                val oldSurface = previewSurface
                textureEntry = null
                previewSurface = null
                cameraExecutor.execute {
                    nativeClearPreviewSurface()
                    mainHandler.post {
                        oldSurface?.release()
                        oldEntry?.release()
                        result.success(null)
                    }
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun getAvailableCameras(): List<Map<String, Any>> {
        val ctx = context ?: return emptyList()
        val cameraManager = ctx.getSystemService(Context.CAMERA_SERVICE) as? CameraManager ?: return emptyList()
        val list = mutableListOf<Map<String, Any>>()
        try {
            for (id in cameraManager.cameraIdList) {
                val chars = cameraManager.getCameraCharacteristics(id)
                val facing = chars.get(CameraCharacteristics.LENS_FACING)
                val orientation = chars.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0
                val focalLengths = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                val focalLength = focalLengths?.firstOrNull() ?: 0.0f

                val facingStr = when (facing) {
                    CameraCharacteristics.LENS_FACING_FRONT -> "front"
                    CameraCharacteristics.LENS_FACING_EXTERNAL -> "external"
                    else -> "back"
                }

                val label = when {
                    facing == CameraCharacteristics.LENS_FACING_FRONT -> "Front Camera (ID $id)"
                    facing == CameraCharacteristics.LENS_FACING_EXTERNAL -> "External Camera (ID $id)"
                    focalLength > 0.0f && focalLength < 2.5f -> "Ultra-Wide Camera 0.5x (ID $id)"
                    focalLength > 6.0f -> "Telephoto Camera (ID $id)"
                    else -> "Back Main Camera (ID $id)"
                }

                list.add(
                    mapOf(
                        "id" to id,
                        "name" to label,
                        "facing" to facingStr,
                        "orientation" to orientation
                    )
                )
            }
        } catch (_: Exception) {}
        return list
    }

    private fun createPreview(targetCameraId: String? = null): Map<String, Any> {
        val registry = textureRegistry ?: return emptyMap()
        releasePreview()

        val previewSize = selectPreviewSize(targetCameraId)
        val entry = registry.createSurfaceTexture()
        entry.surfaceTexture().setDefaultBufferSize(previewSize.width, previewSize.height)
        val surface = Surface(entry.surfaceTexture())
        textureEntry = entry
        previewSurface = surface
        nativeSetPreviewSurface(surface)

        var sensorOrientation = 90
        val ctx = context
        if (ctx != null) {
            try {
                val cameraManager = ctx.getSystemService(Context.CAMERA_SERVICE) as CameraManager
                val idToQuery = targetCameraId ?: cameraManager.cameraIdList.firstOrNull { id ->
                    cameraManager.getCameraCharacteristics(id).get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
                } ?: cameraManager.cameraIdList.firstOrNull()

                if (idToQuery != null) {
                    val characteristics = cameraManager.getCameraCharacteristics(idToQuery)
                    sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
                }
            } catch (e: Exception) {
                // Fallback to 90
            }
        }

        return mapOf(
            "textureId" to entry.id(),
            "sensorOrientation" to sensorOrientation,
            "displayRotation" to currentDisplayRotationDegrees(),
            "previewWidth" to previewSize.width,
            "previewHeight" to previewSize.height,
        )
    }

    private fun currentDisplayRotationDegrees(): Int {
        @Suppress("DEPRECATION")
        val rotation = activity?.windowManager?.defaultDisplay?.rotation
            ?: Surface.ROTATION_0
        return when (rotation) {
            Surface.ROTATION_90 -> 90
            Surface.ROTATION_180 -> 180
            Surface.ROTATION_270 -> 270
            else -> 0
        }
    }

    private fun selectPreviewSize(targetCameraId: String? = null): Size {
        val ctx = context ?: return Size(640, 480)
        return try {
            val cameraManager = ctx.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = targetCameraId ?: cameraManager.cameraIdList.firstOrNull { id ->
                cameraManager.getCameraCharacteristics(id)
                    .get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
            } ?: cameraManager.cameraIdList.firstOrNull() ?: return Size(640, 480)
            val sizes = cameraManager.getCameraCharacteristics(cameraId)
                .get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                ?.getOutputSizes(SurfaceTexture::class.java)
                ?.filter { it.width * 3 == it.height * 4 }
                .orEmpty()
            sizes.filter { it.width <= 1920 && it.height <= 1440 }
                .maxByOrNull { it.width.toLong() * it.height }
                ?: sizes.maxByOrNull { it.width.toLong() * it.height }
                ?: Size(640, 480)
        } catch (_: Exception) {
            Size(640, 480)
        }
    }

    private fun releasePreview() {
        val oldEntry = textureEntry
        val oldSurface = previewSurface
        textureEntry = null
        previewSurface = null
        nativeClearPreviewSurface()
        oldSurface?.release()
        oldEntry?.release()
    }

    private val isPostingDetections = java.util.concurrent.atomic.AtomicBoolean(false)

    // Called natively from C++ NdkCameraEngine background thread with Zero-GC flat payload
    @Keep
    fun onDetectionsAvailable(count: Int, processingMs: Int, flatDetections: DoubleArray?, labels: Array<String>?) {
        if (!isPostingDetections.compareAndSet(false, true)) {
            return
        }
        mainHandler.post {
            try {
                val detections = ArrayList<Map<String, Any>>()
                if (flatDetections != null && labels != null && labels.size * 5 <= flatDetections.size) {
                    for (i in labels.indices) {
                        val offset = i * 5
                        val map = HashMap<String, Any>(6)
                        map["x"] = flatDetections[offset]
                        map["y"] = flatDetections[offset + 1]
                        map["w"] = flatDetections[offset + 2]
                        map["h"] = flatDetections[offset + 3]
                        map["confidence"] = flatDetections[offset + 4]
                        map["label"] = labels[i]
                        detections.add(map)
                    }
                }
                channel.invokeMethod(
                    "onDetections",
                    mapOf(
                        "count" to count,
                        "processingMs" to processingMs,
                        "detections" to detections
                    )
                )
            } finally {
                isPostingDetections.set(false)
            }
        }
    }

    // Native JNI functions
    private external fun nativeSetPreviewSurface(surface: Surface)
    private external fun nativeClearPreviewSurface()
    private external fun nativeStartCamera(cameraId: String): Boolean
    private external fun nativeStopCamera()
    private external fun nativeUpdateEngineSettings(engineHandle: Long, partType: String, keywords: String, maxFps: Double)
}
