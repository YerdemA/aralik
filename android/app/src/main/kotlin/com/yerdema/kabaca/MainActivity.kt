package com.yerdema.kabaca

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import java.security.MessageDigest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Opens the app's Play Store page for the update notice
        // (lib/data/store_link.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.yerdema.kabaca/store")
            .setMethodCallHandler { call, result ->
                if (call.method == "openStore") {
                    result.success(openStore())
                } else {
                    result.notImplemented()
                }
            }
        // The leaderboard's device key (lib/data/device_key.dart): a hash of
        // the per-app device id, which survives reinstalling the app.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.yerdema.kabaca/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "deviceKey") {
                    result.success(deviceKey())
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun deviceKey(): String? {
        val id = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
        if (id.isNullOrEmpty()) return null
        val digest = MessageDigest.getInstance("SHA-256")
            .digest("kabaca-device:$id".toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }

    private fun openStore(): Boolean {
        val pages = listOf(
            "market://details?id=$packageName",
            "https://play.google.com/store/apps/details?id=$packageName",
        )
        for (page in pages) {
            try {
                startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse(page))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                return true
            } catch (_: ActivityNotFoundException) {
                // try the next one
            }
        }
        return false
    }
}
