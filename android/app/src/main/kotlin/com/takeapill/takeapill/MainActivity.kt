package com.takeapill.takeapill

import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockScreenIfAlarm(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "takeapill/call")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "fullScreenState" -> result.success(fullScreenState())
                    "openFullScreenSettings" -> {
                        openFullScreenSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isMiui(): Boolean =
        Build.MANUFACTURER.lowercase() in listOf("xiaomi", "redmi", "poco")

    // "miui": Xiaomi'de kilit ekranı/arka plan açılış izinleri elle verilmeli.
    // "system": Android 14+ tam ekran bildirim izni kapalı. null: sorun yok.
    private fun fullScreenState(): String? {
        if (Build.VERSION.SDK_INT >= 34) {
            val nm = getSystemService(NotificationManager::class.java)
            if (!nm.canUseFullScreenIntent()) return "system"
        }
        return if (isMiui()) "miui" else null
    }

    private fun openFullScreenSettings() {
        val pkg = packageName
        val intents = mutableListOf<Intent>()
        if (Build.VERSION.SDK_INT >= 34 && fullScreenState() == "system") {
            intents += Intent(
                Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                Uri.parse("package:$pkg"),
            )
        }
        if (isMiui()) {
            intents += Intent("miui.intent.action.APP_PERM_EDITOR")
                .setClassName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.permissions.PermissionsEditorActivity",
                )
                .putExtra("extra_pkgname", pkg)
        }
        intents += Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg"))
        for (i in intents) {
            try {
                startActivity(i)
                return
            } catch (_: ActivityNotFoundException) {
            } catch (_: SecurityException) {
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        showOverLockScreenIfAlarm(intent)
    }

    // Alarm bildirimi tam ekran açıldığında kilit ekranının üstünde görünür ve
    // ekranı yakar; normal açılışlar kilidi aşmaz. Son ek notification_planner.dart'taki
    // isCallPayload ile aynıdır.
    private fun showOverLockScreenIfAlarm(intent: Intent?) {
        if (intent?.getStringExtra("payload")?.endsWith("|call") != true) return
        setShowWhenLocked(true)
        setTurnScreenOn(true)
    }
}
