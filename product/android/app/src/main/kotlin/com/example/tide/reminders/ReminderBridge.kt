package com.example.tide.reminders

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.lang.ref.WeakReference

/**
 * The app's side of reminders, on `tide/reminders`
 * (`AndroidReminderPlatform` in lib/services/reminders/).
 *
 * Dart hands over plans, asks what the phone allows and asks for it, and
 * collects the answers given while it was not listening. The other way, this
 * says when an answer has just been queued, and when a reminder was tapped.
 */
class ReminderBridge(private val activity: Activity) {
    private var channel: MethodChannel? = null
    private var waitingForNotifications: MethodChannel.Result? = null

    /** The tap that launched the app, until Dart asks for it. */
    private var launch: Map<String, String>? = null

    companion object {
        const val REQUEST_NOTIFICATIONS = 7301

        /** Weakly: the bridge holds the activity, which must be free to go. */
        private var active = WeakReference<ReminderBridge>(null)
        private val main = Handler(Looper.getMainLooper())

        /** An answer was queued: the running app applies it now. */
        fun notifyActions() = main.post { active.get()?.channel?.invokeMethod("actionsQueued", null) }

        fun openOf(intent: Intent?): Map<String, String>? {
            val target = intent?.getStringExtra(ReminderNotifications.EXTRA_TARGET) ?: return null
            val id = intent.getStringExtra(ReminderNotifications.EXTRA_ID) ?: return null
            return mapOf("target" to target, "id" to id)
        }
    }

    fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "tide/reminders").also {
            it.setMethodCallHandler(::onCall)
        }
        active = WeakReference(this)
        launch = openOf(activity.intent)
    }

    fun onNewIntent(intent: Intent) {
        val open = openOf(intent) ?: return
        channel?.invokeMethod("open", open)
    }

    /** True when the result was for the notification request made here. */
    fun onPermissionResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_NOTIFICATIONS) return false
        waitingForNotifications?.success(ReminderPermissions.states(activity)["notifications"])
        waitingForNotifications = null
        return true
    }

    fun dispose() {
        if (active.get() === this) active = WeakReference(null)
        channel?.setMethodCallHandler(null)
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        val context = activity.applicationContext
        when (call.method) {
            "schedule" -> {
                val group = call.argument<String>("group")
                if (group == null) {
                    result.error("group", "No group", null)
                    return
                }
                takeLook(context, call)
                ReminderBook.setPlan(context, group, items(call.argument<String>("items")))
                ReminderBook.pruneSnoozed(
                    context,
                    group,
                    (call.argument<List<String>>("open") ?: emptyList()).toSet(),
                )
                ReminderScheduler.rearm(context)
                result.success(null)
            }
            "test" -> {
                takeLook(context, call)
                ReminderBook.addTests(context, items(call.argument<String>("items")))
                ReminderScheduler.rearm(context)
                result.success(null)
            }
            "snooze" -> {
                val item = ReminderItem.parse(call.argument<String>("item"))
                if (item != null) {
                    CallActions.snoozeFromApp(
                        context,
                        item,
                        (call.argument<Number>("after") ?: 600_000).toLong(),
                        call.argument<Int>("snoozes") ?: 1,
                    )
                }
                result.success(null)
            }
            "permissions" -> result.success(ReminderPermissions.states(context))
            "request" -> request(call.argument<String>("permission"), result)
            "takeActions" -> result.success(ReminderBook.takeAnswers(context))
            "takeLaunch" -> {
                result.success(launch)
                launch = null
            }
            "previewTone" -> {
                TonePreview.play(context, call.argument<String>("tone"))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun takeLook(context: Context, call: MethodCall) {
        ReminderBook.setLook(context, call.argument<Map<*, *>>("look"))
        ReminderBook.setTiming(context, call.argument<Map<*, *>>("timing"))
        ReminderBook.saveGlyphs(context, call.argument<Map<*, *>>("glyphs"))
    }

    private fun items(raw: String?): List<ReminderItem> {
        if (raw == null) return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { ReminderItem.parse(array.getJSONObject(it)) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun request(name: String?, result: MethodChannel.Result) {
        val context = activity.applicationContext
        val states = ReminderPermissions.states(context)
        if (name == null || states[name] != ReminderPermissions.DENIED) {
            result.success(states[name] ?: ReminderPermissions.NOT_APPLICABLE)
            return
        }
        val pkg = Uri.parse("package:${context.packageName}")
        when (name) {
            "notifications" -> {
                ReminderNotifications.ensureChannels(context)
                // The system dialog, while Android will still show it: the
                // first time, and again after one "don't allow". After that
                // only the app's settings can change it.
                val canAsk = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    (!ReminderBook.askedForNotifications(context) ||
                        ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.POST_NOTIFICATIONS))
                if (canAsk) {
                    ReminderBook.markAskedForNotifications(context)
                    waitingForNotifications?.success(ReminderPermissions.DENIED)
                    waitingForNotifications = result
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        REQUEST_NOTIFICATIONS,
                    )
                    return
                }
                open(
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName),
                )
            }
            "exactAlarms" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                open(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkg))
            }
            "fullScreen" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                open(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, pkg))
            }
            "battery" -> if (!open(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pkg))) {
                open(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            }
        }
        // Granted in the system's own screen, if at all; the app asks again
        // when it comes back to the foreground.
        result.success(ReminderPermissions.states(context)[name])
    }

    private fun open(intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (_: Exception) {
        false
    }
}

/** What the phone allows reminders, in the names Dart uses. */
object ReminderPermissions {
    const val GRANTED = "granted"
    const val DENIED = "denied"
    const val NOT_APPLICABLE = "notApplicable"

    fun states(context: Context): Map<String, String> {
        fun of(ok: Boolean) = if (ok) GRANTED else DENIED
        val notifications = context.getSystemService(NotificationManager::class.java)
        val power = context.getSystemService(PowerManager::class.java)
        val notificationsOn = notifications.areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)
        return mapOf(
            "notifications" to of(notificationsOn),
            "exactAlarms" to if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                NOT_APPLICABLE
            } else {
                of(ReminderScheduler.canExact(context))
            },
            "fullScreen" to if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                NOT_APPLICABLE
            } else {
                of(notifications.canUseFullScreenIntent())
            },
            "battery" to of(power.isIgnoringBatteryOptimizations(context.packageName)),
        )
    }
}

/** A tone from the pickers, played once on the alarm stream it will ring on. */
object TonePreview {
    private var player: MediaPlayer? = null

    fun play(context: Context, tone: String?) {
        stop()
        val resource = ReminderItem.toneFor(tone)
        player = try {
            MediaPlayer().apply {
                setAudioAttributes(ReminderNotifications.alarmAudio)
                setDataSource(context, Uri.parse("android.resource://${context.packageName}/$resource"))
                setOnCompletionListener { stop() }
                prepare()
                start()
            }
        } catch (_: Exception) {
            null
        }
    }

    fun stop() {
        player?.release()
        player = null
    }
}
