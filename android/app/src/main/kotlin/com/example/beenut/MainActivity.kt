package com.example.beenut

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var isAppReady = false
    private val splashTimeoutHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        super.onCreate(savedInstanceState)

        // Keep native splash on screen until Flutter notifies that AI/camera is ready
        splashScreen.setKeepOnScreenCondition { !isAppReady }

        // Safety fallback: dismiss splash after 6 seconds maximum if no signal is received
        splashTimeoutHandler.postDelayed({
            isAppReady = true
        }, 6000)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(NativeCameraPlugin())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "beenut/splash")
            .setMethodCallHandler { call, result ->
                if (call.method == "dismissSplash" || call.method == "appReady") {
                    isAppReady = true
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        splashTimeoutHandler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
