package com.example.lifeos_mobile

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // "ally/system": the battery checks the reminders screen needs. Samsung's
    // battery saver holds back reminders unless Ally is left out of it.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ally/system").setMethodCallHandler { call, result ->
            when (call.method) {
                "isBatteryUnrestricted" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(Build.VERSION.SDK_INT < Build.VERSION_CODES.M || pm.isIgnoringBatteryOptimizations(packageName))
                }
                "requestBatteryUnrestricted" -> {
                    // The system's own "Allow Ally to always run in the background?" dialog;
                    // falls back to the app's settings page if a phone doesn't offer it.
                    val ok = tryStart(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
                    result.success(ok || tryStart(appDetails()))
                }
                "openAppSettings" -> result.success(tryStart(appDetails()))
                else -> result.notImplemented()
            }
        }
    }

    private fun appDetails() = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))

    private fun tryStart(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: Exception) {
        false
    }
}
