package com.habitq.mobile

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighestRefreshRate()
    }

    /**
     * Asks Android for the display's highest refresh rate at the current
     * resolution. Some manufacturers keep apps at 60 Hz unless they ask, which
     * makes scrolling and animations look choppier than the screen allows.
     * Flutter then renders at whatever rate the system grants.
     */
    @Suppress("DEPRECATION")
    private fun requestHighestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val screen = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay
            val current = screen?.mode ?: return
            val best = screen.supportedModes
                .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
                .maxByOrNull { it.refreshRate } ?: return
            val params = window.attributes
            params.preferredDisplayModeId = best.modeId
            window.attributes = params
        } catch (_: Exception) {
            // The default refresh rate is fine if the display cannot be queried.
        }
    }
}
