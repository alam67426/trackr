package com.trackr.app

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private val channel = "trackr/notification_access"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "openSettings" -> {
                    startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"))
                    result.success(null)
                }
                "isEnabled" -> {
                    val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners").orEmpty()
                    result.success(enabled.contains(packageName))
                }
                "consume" -> {
                    val preferences = getSharedPreferences("trackr_business_notifications", MODE_PRIVATE)
                    val rows = JSONArray(preferences.getString("items", "[]") ?: "[]")
                    val values = mutableListOf<Map<String, Any>>()
                    for (index in 0 until rows.length()) {
                        val row = rows.getJSONObject(index)
                        values.add(mapOf(
                            "sender" to row.optString("sender"),
                            "body" to row.optString("body"),
                            "timestamp" to row.optLong("timestamp")
                        ))
                    }
                    preferences.edit().remove("items").apply()
                    result.success(values)
                }
                else -> result.notImplemented()
            }
        }
    }
}
