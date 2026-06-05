package com.atanhx.markdone

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.atanhx.markdone/app_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setAppIcon") {
                val iconName = call.argument<String>("icon") ?: "default"
                setAppIcon(iconName)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun setAppIcon(iconName: String) {
        val allAliases = listOf("default", "red", "yellow")

        for (alias in allAliases) {
            val state = if (alias == iconName) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }

            val componentName = ComponentName(
                packageName,
                "$packageName.MainActivity_$alias"
            )

            packageManager.setComponentEnabledSetting(
                componentName,
                state,
                PackageManager.DONT_KILL_APP
            )
        }
    }
}
