package com.example.daily_brief

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingShortcutRequest = false
    private var shortcutChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingShortcutRequest =
            pendingShortcutRequest || intent?.getBooleanExtra(
                EXTRA_ACCESSIBILITY_SHORTCUT,
                false,
            ) == true

        shortcutChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumePendingShortcut" -> {
                        result.success(pendingShortcutRequest)
                        pendingShortcutRequest = false
                    }
                    "openAccessibilitySettings" -> openSettings(
                        Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS),
                        result,
                    )
                    "openAppSettings" -> openSettings(
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName"),
                        ),
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(EXTRA_ACCESSIBILITY_SHORTCUT, false)) {
            pendingShortcutRequest = true
            shortcutChannel?.invokeMethod("shortcutRequested", null)
        }
    }

    private fun openSettings(settingsIntent: Intent, result: MethodChannel.Result) {
        try {
            startActivity(settingsIntent)
            result.success(null)
        } catch (error: RuntimeException) {
            result.error("settings_unavailable", error.message, null)
        }
    }

    companion object {
        const val ACTION_ACCESSIBILITY_SHORTCUT =
            "com.example.daily_brief.ACCESSIBILITY_SHORTCUT"
        const val EXTRA_ACCESSIBILITY_SHORTCUT = "accessibility_shortcut"
        private const val CHANNEL_NAME = "dailybrief/accessibility_shortcut"
    }
}
