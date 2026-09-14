package com.example.tide

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * The native half of lib/services/updates/: which build is installed, where
 * a download may be written, and the install intent itself.
 *
 * Hand-rolled rather than a plugin. Handing an APK to the system installer
 * is a FileProvider URI and one ACTION_VIEW intent, and the packages that
 * wrap it tend to go unmaintained, which a sideloaded app that can only
 * update itself through this code cannot afford.
 */
class UpdateInstaller(private val activity: Activity) {

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "tide/updates").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "installedVersion" -> result.success(installedVersion())
                    "downloadDirectory" -> result.success(downloadDirectory().absolutePath)
                    "canInstallPackages" -> result.success(canInstallPackages())
                    "openInstallPermission" -> {
                        openInstallPermission()
                        result.success(null)
                    }
                    "install" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("bad_args", "No APK path was given.", null)
                        } else {
                            install(File(path))
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("update_failed", error.message, null)
            }
        }
    }

    private fun installedVersion(): String? {
        val pm = activity.packageManager
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getPackageInfo(activity.packageName, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(activity.packageName, 0)
        }
        return info.versionName
    }

    /** Must match res/xml/update_paths.xml. */
    private fun downloadDirectory(): File =
        File(activity.cacheDir, "updates").apply { mkdirs() }

    private fun canInstallPackages(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            activity.packageManager.canRequestPackageInstalls()

    private fun openInstallPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        activity.startActivity(
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${activity.packageName}"),
            ),
        )
    }

    private fun install(apk: File) {
        // Only ever a file this app downloaded into its own update cache: the
        // provider below would refuse anything else anyway, but the check
        // keeps a bad path from reaching the installer at all.
        val root = downloadDirectory().canonicalPath
        require(apk.canonicalPath.startsWith(root) && apk.exists()) {
            "The update file is missing."
        }
        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.updates",
            apk,
        )
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
    }
}

/**
 * A FileProvider of Tide's own. The manifest merger identifies a provider by
 * its class name, so declaring androidx's FileProvider directly would collide
 * with any plugin that declares it too.
 */
class UpdateFileProvider : FileProvider()
