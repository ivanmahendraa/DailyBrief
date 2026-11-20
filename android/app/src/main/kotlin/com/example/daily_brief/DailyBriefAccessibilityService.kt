package com.example.daily_brief

import android.accessibilityservice.AccessibilityButtonController
import android.accessibilityservice.AccessibilityService
import android.app.KeyguardManager
import android.content.Intent
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class DailyBriefAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            accessibilityButtonController.registerAccessibilityButtonCallback(
                object : AccessibilityButtonController.AccessibilityButtonCallback() {
                    override fun onClicked(controller: AccessibilityButtonController) {
                        openDailyBrief()
                    }
                },
            )
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit

    override fun onInterrupt() = Unit

    private fun openDailyBrief() {
        val keyguardManager = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
        if (keyguardManager.isKeyguardLocked) return

        val intent = Intent(this, MainActivity::class.java).apply {
            action = MainActivity.ACTION_ACCESSIBILITY_SHORTCUT
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_ACCESSIBILITY_SHORTCUT, true)
        }

        try {
            startActivity(intent)
        } catch (error: RuntimeException) {
            Log.e(TAG, "Unable to open DailyBrief from accessibility button", error)
        }
    }

    private companion object {
        const val TAG = "DailyBriefAccessibility"
    }
}
