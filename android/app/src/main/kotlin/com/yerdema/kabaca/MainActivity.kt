package com.yerdema.kabaca

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
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
