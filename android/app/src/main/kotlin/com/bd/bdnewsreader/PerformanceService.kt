package com.bd.bdnewsreader

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class PerformanceService(private val context: Context) {
    companion object {
        const val CHANNEL = "com.newsapp.performance/android"
    }

    fun setupChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isLowRamDevice" -> {
                        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        result.success(activityManager.isLowRamDevice)
                    }
                    "isBatterySaverEnabled" -> {
                        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(powerManager.isPowerSaveMode)
                    }
                    "getTotalRam" -> {
                        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val memInfo = ActivityManager.MemoryInfo()
                        activityManager.getMemoryInfo(memInfo)
                        result.success((memInfo.totalMem / 1024 / 1024).toInt())  // Convert to MB
                    }
                    "getAvailableRam" -> {
                        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val memInfo = ActivityManager.MemoryInfo()
                        activityManager.getMemoryInfo(memInfo)
                        result.success((memInfo.availMem / 1024 / 1024).toInt())
                    }
                    "getDeviceBrand" -> {
                        result.success(Build.BRAND)
                    }
                    "getAndroidSdkVersion" -> {
                        result.success(Build.VERSION.SDK_INT)
                    }
                    "isEmulator" -> {
                        result.success(isEmulator())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isEmulator(): Boolean {
        val fingerprint = Build.FINGERPRINT.lowercase()
        val model = Build.MODEL.lowercase()
        val product = Build.PRODUCT.lowercase()
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        val device = Build.DEVICE.lowercase()
        val hardware = Build.HARDWARE.lowercase()
        val board = Build.BOARD.lowercase()

        return fingerprint.contains("generic") ||
            fingerprint.contains("emulator") ||
            fingerprint.contains("unknown") ||
            model.contains("emulator") ||
            model.contains("google_sdk") ||
            model.contains("android sdk built for x86") ||
            product.contains("sdk") ||
            product.contains("emulator") ||
            product.contains("simulator") ||
            manufacturer.contains("genymotion") ||
            brand.contains("generic") ||
            (brand.startsWith("generic") && device.startsWith("generic")) ||
            hardware.contains("goldfish") ||
            hardware.contains("ranchu") ||
            board.contains("goldfish")
    }
}
