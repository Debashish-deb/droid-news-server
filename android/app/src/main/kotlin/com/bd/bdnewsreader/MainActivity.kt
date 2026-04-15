package com.bd.bdnewsreader

import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.provider.Settings
import android.view.WindowManager
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    private companion object {
        const val SECURITY_CHANNEL = "com.bdnews/security"
        const val SPLASH_CHANNEL = "com.bdnews/splash"
    }
    @Volatile
    private var keepLaunchSplashVisible = true

    // ✅ Splash screen must be installed before super.onCreate
    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        splashScreen.setKeepOnScreenCondition { keepLaunchSplashVisible }
        super.onCreate(savedInstanceState)
        ensureDebugBuildIsInspectable()
        setupEdgeToEdge()
        // Failsafe: never allow the splash to get stuck if Dart bootstrap
        // crashes or a method-channel message is missed.
        window.decorView.postDelayed({
            keepLaunchSplashVisible = false
        }, 4000)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupSecurityChannel(flutterEngine)
        setupSplashChannel(flutterEngine)
        PerformanceService(this).setupChannel(flutterEngine)
    }

    // ✅ API 35: edge-to-edge is enforced — opt in explicitly and let Flutter
    //    handle insets via MediaQuery.padding / SafeArea
    private fun setupEdgeToEdge() {
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // Make system bars transparent so Flutter paints behind them
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
    }

    private fun setupSecurityChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SECURITY_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecureFlag" -> {
                    if (shouldAllowSecureFlag()) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    } else {
                        // Keep debug builds inspectable in Android Studio.
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(false)
                    }
                }
                "disableSecureFlag" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                "isSecureFlagAllowed" -> {
                    result.success(shouldAllowSecureFlag())
                }
                "getMonotonicTime" -> {
                    // Monotonic clock in ms — tamper-resistant vs System.currentTimeMillis()
                    result.success(SystemClock.elapsedRealtime())
                }
                "openNotificationSettings" -> {
                    result.success(openNotificationSettings())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setupSplashChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SPLASH_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "release" -> {
                    keepLaunchSplashVisible = false
                    result.success(true)
                }
                "hold" -> {
                    keepLaunchSplashVisible = true
                    result.success(true)
                }
                "isHolding" -> {
                    result.success(keepLaunchSplashVisible)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openNotificationSettings(): Boolean {
        return try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    putExtra("android.provider.extra.APP_PACKAGE", packageName)
                }
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = android.net.Uri.parse("package:$packageName")
                }
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun shouldAllowSecureFlag(): Boolean {
        return !BuildConfig.DEBUG
    }

    private fun ensureDebugBuildIsInspectable() {
        if (BuildConfig.DEBUG) {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    // ✅ Predictive back: let the system handle it via enableOnBackInvokedCallback
    //    in AndroidManifest — no onBackPressed() override needed here
}
