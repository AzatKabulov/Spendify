package com.azatkabulov.spendly

import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    /**
     * Phase 10 security audit, item 8 (OWASP Mobile M9 — screen capture of
     * sensitive data). FLAG_SECURE blocks screenshots and screen recording of
     * the app and hides its contents in the app switcher — appropriate for an
     * app that shows the user's finances.
     *
     * Release builds only: debuggable builds stay screenshot-able so the app
     * can be captured for the project report and during development.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val debuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!debuggable) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        }
    }
}
