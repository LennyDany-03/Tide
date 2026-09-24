package com.example.tide

import android.app.Activity
import android.content.ClipData
import android.content.ComponentName
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Telephony
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * The native half of lib/services/share/: sends a rendered milestone card to
 * WhatsApp, Instagram, the messaging app or the gallery, or to the system
 * share sheet for anything else.
 *
 * Hand-rolled for the same reason as UpdateInstaller: it is one ACTION_SEND
 * intent and one MediaStore insert, and the share plugins cannot aim at a
 * single app — which is the point of a "WhatsApp status" button.
 */
class CardShare(private val activity: Activity) {

    private companion object {
        val WHATSAPP = listOf("com.whatsapp", "com.whatsapp.w4b")
        const val INSTAGRAM = "com.instagram.android"
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "tide/share").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "directory" -> result.success(directory().absolutePath)
                    "targets" -> result.success(targets())
                    "send" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("bad_args", "No image path was given.", null)
                        } else {
                            result.success(
                                send(
                                    File(path),
                                    call.argument<String>("target"),
                                    call.argument<String>("caption"),
                                ),
                            )
                        }
                    }
                    "save" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("bad_args", "No image path was given.", null)
                        } else {
                            result.success(save(File(path)))
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("share_failed", error.message, null)
            }
        }
    }

    /** Must match res/xml/share_paths.xml. */
    private fun directory(): File =
        File(activity.cacheDir, "share").apply { mkdirs() }

    private fun targets(): List<String> {
        val targets = mutableListOf<String>()
        if (whatsapp() != null) targets += "whatsapp"
        if (installed(INSTAGRAM)) targets += "instagram"
        if (messages() != null) targets += "messages"
        // Scoped storage: from Android 10 a picture can go into the shared
        // Pictures folder with no permission at all. Before that it would
        // need storage access, and the share sheet can save it there instead.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) targets += "save"
        return targets
    }

    private fun installed(pkg: String): Boolean = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.packageManager.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            activity.packageManager.getPackageInfo(pkg, 0)
        }
        true
    } catch (missing: PackageManager.NameNotFoundException) {
        false
    }

    private fun whatsapp(): String? = WHATSAPP.firstOrNull { installed(it) }

    private fun messages(): String? = Telephony.Sms.getDefaultSmsPackage(activity)

    private fun uriFor(image: File): Uri {
        // Only a card this app rendered into its own share cache.
        val root = directory().canonicalPath
        require(image.canonicalPath.startsWith(root) && image.exists()) {
            "The card image is missing."
        }
        return FileProvider.getUriForFile(activity, "${activity.packageName}.share", image)
    }

    private fun send(image: File, target: String?, caption: String?): Boolean {
        val uri = uriFor(image)
        val intent = Intent(Intent.ACTION_SEND)
            .setType("image/png")
            .putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        // ClipData as well as the extra: it is what carries the read grant to
        // the chosen app, and what gives the system sheet its preview.
        intent.clipData = ClipData.newRawUri(null, uri)
        // A story has nowhere to put a caption.
        if (caption != null && target != "instagram") {
            intent.putExtra(Intent.EXTRA_TEXT, caption)
        }

        when (target) {
            "whatsapp" -> intent.setPackage(whatsapp() ?: return false)
            "instagram" -> {
                val story = instagramStory(intent)
                if (story != null) intent.component = story else intent.setPackage(INSTAGRAM)
            }
            "messages" -> intent.setPackage(messages() ?: return false)
            else -> {
                val chooser = Intent.createChooser(intent, "Share milestone")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                activity.startActivity(chooser)
                return true
            }
        }
        activity.startActivity(intent)
        return true
    }

    /**
     * Instagram lists its story composer as its own share target. Aiming at
     * it opens straight on the story editor; if a future Instagram renames
     * it, the send falls back to Instagram's package and Instagram asks.
     */
    private fun instagramStory(intent: Intent): ComponentName? {
        val probe = Intent(intent).setPackage(INSTAGRAM)
        val matches = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.packageManager.queryIntentActivities(
                probe,
                PackageManager.ResolveInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            activity.packageManager.queryIntentActivities(probe, 0)
        }
        val story = matches.firstOrNull {
            it.activityInfo.name.contains("Story", ignoreCase = true)
        } ?: return null
        return ComponentName(story.activityInfo.packageName, story.activityInfo.name)
    }

    private fun save(image: File): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val resolver = activity.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, image.name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/Tide")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: return false
        val written = resolver.openOutputStream(uri)?.use { out ->
            image.inputStream().use { it.copyTo(out) }
            true
        } ?: false
        if (!written) {
            resolver.delete(uri, null, null)
            return false
        }
        values.clear()
        values.put(MediaStore.Images.Media.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        return true
    }
}

/**
 * Tide's own FileProvider for shared cards, a second class for the same
 * reason as UpdateFileProvider: the manifest merger keys providers by class
 * name, and each one exposes only its own directory.
 */
class CardShareProvider : FileProvider()
