package com.yerdema.kabaca

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import android.net.Uri
import android.provider.Settings
import java.io.File
import java.security.MessageDigest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Short sound effects (lib/data/sound.dart). Dart sends each Ogg once;
    // it is kept in the cache directory and loaded into a SoundPool.
    private var soundPool: SoundPool? = null
    private val soundIds = mutableMapOf<String, Int>()

    // Samples the pool has finished decoding, and plays asked for before
    // that (the intro sound is played right after it is sent).
    private val readyIds = mutableSetOf<Int>()
    private val pendingIds = mutableSetOf<Int>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.yerdema.kabaca/sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "load" -> {
                        val name = call.argument<String>("name")
                        val bytes = call.argument<ByteArray>("bytes")
                        result.success(name != null && bytes != null && loadSound(name, bytes))
                    }
                    "play" -> result.success(playSound(call.argument<String>("name") ?: ""))
                    else -> result.notImplemented()
                }
            }
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

    override fun onDestroy() {
        soundPool?.release()
        soundPool = null
        soundIds.clear()
        readyIds.clear()
        pendingIds.clear()
        super.onDestroy()
    }

    private fun pool(): SoundPool = soundPool ?: SoundPool.Builder()
        .setMaxStreams(4)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        .build()
        .also { pool ->
            pool.setOnLoadCompleteListener { _, id, status ->
                if (status != 0) return@setOnLoadCompleteListener
                readyIds.add(id)
                if (pendingIds.remove(id)) startSound(id)
            }
            soundPool = pool
        }

    private fun loadSound(name: String, bytes: ByteArray): Boolean {
        if (soundIds.containsKey(name)) return true
        return try {
            val file = File(File(cacheDir, "sounds").apply { mkdirs() }, "$name.ogg")
            file.writeBytes(bytes)
            soundIds[name] = pool().load(file.path, 1)
            true
        } catch (_: Exception) {
            false
        }
    }

    /** Plays [name] unless the phone is on silent or vibrate. */
    private fun playSound(name: String): Boolean {
        val id = soundIds[name] ?: return false
        if (id !in readyIds) {
            pendingIds.add(id)
            return true
        }
        return startSound(id)
    }

    private fun startSound(id: Int): Boolean {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) return false
        return pool().play(id, 0.7f, 0.7f, 1, 0, 1f) != 0
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
