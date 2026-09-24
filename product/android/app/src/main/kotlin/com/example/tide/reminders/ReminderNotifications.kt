package com.example.tide.reminders

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationChannelGroup
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.example.tide.MainActivity
import com.example.tide.R
import kotlin.math.max

/**
 * Every reminder notification, and the channels they arrive on.
 *
 * * **Rising Tide** — a habit's heads-up. A custom card: the habit's mark,
 *   a live countdown, water rising along the foot as the minutes run.
 * * **Beacon** — a to-do's heads-up. The same bones, a different picture: a
 *   lamp, and a beam swinging down to the horizon.
 * * **Gentle** — a reminder that is only a notification, by choice, in quiet
 *   hours, or under Do Not Disturb.
 * * **Missed** — left behind by a call that rang out unanswered.
 * * **The call** — the ringing service's own notification, which carries the
 *   full-screen intent that puts the call over the lock screen. When the
 *   phone is in use Android shows it as a heads-up instead of taking the
 *   screen, and a tap opens the full call.
 *
 * Words come from Dart in each reminder's copy; colours come from the
 * palette Dart sent ([Look]). Button names are string resources.
 */
object ReminderNotifications {
    const val HABIT_HEADS_UP = "tide_habit_heads_up"
    const val HABIT_ALARM = "tide_habit_alarm"
    const val HABIT_GENTLE = "tide_habit_reminders"
    const val TASK_HEADS_UP = "tide_task_heads_up"
    const val TASK_ALARM = "tide_task_alarm"

    /** The id earlier builds posted to-do reminders on, so a person's own
     *  setting for it survives the update. */
    const val TASK_GENTLE = "tide_tasks"
    const val QUIET = "tide_quiet"
    const val MISSED = "tide_missed"

    const val CALL_ID = 7201

    const val EXTRA_TARGET = "tide_reminder_target"
    const val EXTRA_ID = "tide_reminder_id"
    const val EXTRA_KEY = "tide_reminder_key"

    private const val GROUP_HABITS = "tide_habits"
    private const val GROUP_TASKS = "tide_tasks_group"

    fun ensureChannels(context: Context) {
        // Android 7 has no channels: each notification carries its own
        // priority and defaults instead (see [legacySound]).
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannelGroups(
            listOf(
                NotificationChannelGroup(GROUP_HABITS, context.getString(R.string.channel_group_habits)),
                NotificationChannelGroup(GROUP_TASKS, context.getString(R.string.channel_group_tasks)),
            ),
        )
        fun channel(
            id: String,
            name: Int,
            about: Int,
            importance: Int,
            group: String?,
            silent: Boolean = false,
        ) = NotificationChannel(id, context.getString(name), importance).apply {
            description = context.getString(about)
            this.group = group
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            if (silent) {
                setSound(null, null)
                enableVibration(false)
            }
        }
        manager.createNotificationChannels(
            listOf(
                channel(HABIT_HEADS_UP, R.string.channel_habit_heads_up, R.string.channel_habit_heads_up_about, NotificationManager.IMPORTANCE_DEFAULT, GROUP_HABITS),
                // The alarms make no sound of their own: the ringing service
                // plays the chosen tone on the alarm stream, swelling, and
                // vibrates in time with the orb. A channel sound would play
                // once, at full volume, over the top of it.
                channel(HABIT_ALARM, R.string.channel_habit_alarm, R.string.channel_habit_alarm_about, NotificationManager.IMPORTANCE_HIGH, GROUP_HABITS, silent = true).apply {
                    setBypassDnd(true)
                },
                channel(HABIT_GENTLE, R.string.channel_habit_gentle, R.string.channel_habit_gentle_about, NotificationManager.IMPORTANCE_HIGH, GROUP_HABITS),
                channel(TASK_HEADS_UP, R.string.channel_task_heads_up, R.string.channel_task_heads_up_about, NotificationManager.IMPORTANCE_DEFAULT, GROUP_TASKS),
                channel(TASK_ALARM, R.string.channel_task_alarm, R.string.channel_task_alarm_about, NotificationManager.IMPORTANCE_HIGH, GROUP_TASKS, silent = true).apply {
                    setBypassDnd(true)
                },
                channel(TASK_GENTLE, R.string.channel_task_gentle, R.string.channel_task_gentle_about, NotificationManager.IMPORTANCE_HIGH, GROUP_TASKS),
                channel(QUIET, R.string.channel_quiet, R.string.channel_quiet_about, NotificationManager.IMPORTANCE_LOW, null, silent = true),
                channel(MISSED, R.string.channel_missed, R.string.channel_missed_about, NotificationManager.IMPORTANCE_LOW, null, silent = true),
            ),
        )
    }

    /**
     * Before channels, a notification only sounds if it asks to. From Android
     * 8 the channel decides and this is ignored.
     */
    private fun NotificationCompat.Builder.legacySound(loud: Boolean): NotificationCompat.Builder =
        if (loud) setDefaults(NotificationCompat.DEFAULT_ALL) else this

    fun canPost(context: Context): Boolean =
        NotificationManagerCompat.from(context).areNotificationsEnabled()

    @SuppressLint("MissingPermission")
    private fun post(context: Context, id: Int, notification: Notification) {
        if (!canPost(context)) return
        try {
            NotificationManagerCompat.from(context).notify(id, notification)
        } catch (_: SecurityException) {
            // Notifications withdrawn between the check and the post.
        }
    }

    private fun headsUpId(item: ReminderItem) = ReminderItem.idFor("${item.occurrence}#heads-up")
    private fun gentleId(item: ReminderItem) = ReminderItem.idFor("${item.occurrence}#gentle")

    fun cancelFor(context: Context, item: ReminderItem) {
        val manager = NotificationManagerCompat.from(context)
        manager.cancel(headsUpId(item))
        manager.cancel(gentleId(item))
        ReminderBook.dropLive(context, item.occurrence)
    }

    /** How far a heads-up's countdown has run, 0..1. */
    private fun progress(item: ReminderItem, now: Long): Float {
        val span = max(item.dueAt - item.at, 1L)
        return ((now - item.at).toFloat() / span).coerceIn(0f, 1f)
    }

    // --- Heads-ups -----------------------------------------------------------

    /** Posts [item]'s heads-up, or redraws it with [redraw] set. */
    fun headsUp(context: Context, item: ReminderItem, redraw: Boolean = false) {
        ensureChannels(context)
        val now = System.currentTimeMillis()
        if (item.dueAt <= now) return
        val look = ReminderBook.look(context)
        val progress = progress(item, now)
        // The waves drift a little each minute, so a redraw reads as water.
        val phase = ((now / 60_000L) % 12) * 0.5f
        val collapsed: RemoteViews
        val expanded: RemoteViews
        val mark = if (item.isHabit) {
            ReminderArt.badgeOrDot(look, ReminderBook.glyph(context, item.glyph))
        } else {
            ReminderArt.beaconLamp(look)
        }

        if (item.isHabit) {
            collapsed = RemoteViews(context.packageName, R.layout.notification_rising_tide)
            collapsed.setImageViewBitmap(R.id.reminder_ground, ReminderArt.risingTideStrip(look, progress, phase))
            expanded = RemoteViews(context.packageName, R.layout.notification_rising_tide_big)
            expanded.setImageViewBitmap(R.id.reminder_ground, ReminderArt.risingTideCard(look, progress, phase))
            expanded.setTextViewText(R.id.reminder_streak, item.copy("streakLine"))
            expanded.setTextColor(R.id.reminder_streak, look.accent)
        } else {
            collapsed = RemoteViews(context.packageName, R.layout.notification_beacon)
            collapsed.setImageViewBitmap(R.id.reminder_ground, ReminderArt.beaconCard(look, 48, progress))
            expanded = RemoteViews(context.packageName, R.layout.notification_beacon_big)
            expanded.setImageViewBitmap(R.id.reminder_ground, ReminderArt.beaconCard(look, 196, progress))
            expanded.setTextViewText(R.id.reminder_note, item.details.optString("note"))
            expanded.setTextColor(R.id.reminder_note, look.muted)
            val steps = item.details.optJSONArray("steps")
            val total = steps?.length() ?: 0
            expanded.setTextViewText(R.id.reminder_steps_label, item.copy("steps"))
            expanded.setTextColor(R.id.reminder_steps_label, look.muted)
            val bar = ReminderArt.steps(look, total - item.stepsLeft, total)
            if (bar != null) expanded.setImageViewBitmap(R.id.reminder_steps, bar)
        }

        val countdownBase = SystemClock.elapsedRealtime() + (item.dueAt - now)
        for (views in listOf(collapsed, expanded)) {
            views.setImageViewBitmap(R.id.reminder_mark, mark)
            views.setTextViewText(R.id.reminder_title, item.title)
            views.setTextColor(R.id.reminder_title, look.ink)
            views.setTextViewText(R.id.reminder_subtitle, item.copy("headsUp"))
            views.setTextColor(R.id.reminder_subtitle, look.muted)
            views.setChronometer(R.id.reminder_countdown, countdownBase, null, true)
            views.setChronometerCountDown(R.id.reminder_countdown, true)
            views.setTextColor(R.id.reminder_countdown, look.accent)
        }
        expanded.setTextViewText(R.id.reminder_line, item.copy("headsUpLine"))
        expanded.setTextColor(R.id.reminder_line, look.ink)

        val builder = NotificationCompat.Builder(context, if (item.isHabit) HABIT_HEADS_UP else TASK_HEADS_UP)
            .setSmallIcon(R.drawable.ic_stat_tide)
            .setColor(look.accent)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(collapsed)
            .setCustomBigContentView(expanded)
            .setContentTitle(item.title)
            .setContentText(item.copy("headsUp"))
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setSilent(redraw)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .legacySound(!redraw)
            .setTimeoutAfter(max(1_000L, item.dueAt - now))
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(open(context, item))
            .setAutoCancel(true)
            .addAction(0, context.getString(R.string.reminder_on_it), answer(context, item, CallActions.ON_IT))
        if (item.isHabit || item.stepsLeft == 0) {
            builder.addAction(0, context.getString(R.string.reminder_done_already), answer(context, item, CallActions.DONE))
        }
        if (item.isHabit && item.freezes > 0) {
            builder.addAction(0, context.getString(R.string.reminder_skip_today), answer(context, item, CallActions.SKIP))
        } else if (!item.isHabit) {
            builder.addAction(0, context.getString(R.string.reminder_tomorrow), answer(context, item, CallActions.TOMORROW))
        }
        post(context, headsUpId(item), builder.build())
        if (!redraw) ReminderBook.addLive(context, item)
    }

    /**
     * Redraws every heads-up still counting down and still on screen. One
     * swiped away or tapped is let go rather than posted again, which would
     * bring back something the person had already dealt with.
     */
    fun refreshHeadsUps(context: Context) {
        val now = System.currentTimeMillis()
        val showing = context.getSystemService(NotificationManager::class.java)
            .activeNotifications
            .map { it.id }
            .toSet()
        val live = ReminderBook.live(context)
        val (running, done) = live.partition { it.dueAt > now && headsUpId(it) in showing }
        ReminderBook.setLive(context, running)
        done.forEach { NotificationManagerCompat.from(context).cancel(headsUpId(it)) }
        running.forEach { headsUp(context, it, redraw = true) }
    }

    // --- Gentle and missed ---------------------------------------------------

    /**
     * A reminder as a plain notification. [silent] for quiet hours and Do Not
     * Disturb: it lands in the shade without a sound or the screen.
     */
    fun gentle(context: Context, item: ReminderItem, silent: Boolean) {
        ensureChannels(context)
        val look = ReminderBook.look(context)
        val channel = when {
            silent -> QUIET
            item.isHabit -> HABIT_GENTLE
            else -> TASK_GENTLE
        }
        val detail = if (item.isHabit) item.copy("subtitle") else item.copy("steps")
        val body = item.copy("callBody")
        val builder = NotificationCompat.Builder(context, channel)
            .setSmallIcon(R.drawable.ic_stat_tide)
            .setColor(look.accent)
            .setLargeIcon(
                if (item.isHabit) {
                    ReminderArt.badgeOrDot(look, ReminderBook.glyph(context, item.glyph))
                } else {
                    ReminderArt.beaconLamp(look)
                },
            )
            .setContentTitle(item.title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(listOf(body, detail).filter { it.isNotEmpty() }.joinToString("\n")))
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(if (silent) NotificationCompat.PRIORITY_LOW else NotificationCompat.PRIORITY_HIGH)
            .legacySound(!silent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(open(context, item))
            .setAutoCancel(true)
        answers(context, builder, item)
        post(context, gentleId(item), builder.build())
    }

    /** "The tide went out on Gym — still time today." */
    fun missed(context: Context, item: ReminderItem) {
        ensureChannels(context)
        val look = ReminderBook.look(context)
        val builder = NotificationCompat.Builder(context, MISSED)
            .setSmallIcon(R.drawable.ic_stat_tide)
            .setColor(look.accent)
            .setContentTitle(item.title)
            .setContentText(item.copy("missed"))
            .setStyle(NotificationCompat.BigTextStyle().bigText(item.copy("missed")))
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(open(context, item))
            .setAutoCancel(true)
        if (item.isHabit || item.stepsLeft == 0) {
            builder.addAction(0, context.getString(R.string.reminder_done), answer(context, item, CallActions.DONE))
        }
        post(context, gentleId(item), builder.build())
    }

    private fun answers(context: Context, builder: NotificationCompat.Builder, item: ReminderItem) {
        if (item.isHabit || item.stepsLeft == 0) {
            builder.addAction(0, context.getString(R.string.reminder_done), answer(context, item, CallActions.DONE))
        }
        builder.addAction(0, context.getString(R.string.reminder_snooze, item.snoozeMinutes), answer(context, item, CallActions.SNOOZE))
        if (item.isHabit && item.freezes > 0) {
            builder.addAction(0, context.getString(R.string.reminder_skip_today), answer(context, item, CallActions.SKIP))
        } else if (!item.isHabit) {
            builder.addAction(0, context.getString(R.string.reminder_tomorrow), answer(context, item, CallActions.TOMORROW))
        }
    }

    // --- The call ------------------------------------------------------------

    /**
     * The ringing service's notification: every call ringing, the newest
     * named. Colourised in the accent — Android allows it only on a
     * foreground service's notification, which this is.
     */
    fun call(context: Context, ringing: List<ReminderItem>): Notification {
        ensureChannels(context)
        val look = ReminderBook.look(context)
        val newest = ringing.last()
        val title = if (ringing.size == 1) {
            newest.title
        } else {
            context.resources.getQuantityString(R.plurals.reminder_and_more, ringing.size - 1, newest.title, ringing.size - 1)
        }
        val full = callIntent(context, newest)
        val builder = NotificationCompat.Builder(context, if (ringing.any { it.isHabit }) HABIT_ALARM else TASK_ALARM)
            .setSmallIcon(R.drawable.ic_stat_tide)
            .setColor(look.accent)
            .setColorized(true)
            .setLargeIcon(
                if (newest.isHabit) {
                    ReminderArt.badgeOrDot(look, ReminderBook.glyph(context, newest.glyph))
                } else {
                    ReminderArt.beaconLamp(look)
                },
            )
            .setContentTitle(title)
            .setContentText(newest.copy("callBody"))
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setUsesChronometer(true)
            .setWhen(newest.dueAt)
            .setFullScreenIntent(full, true)
            .setContentIntent(full)
        if (newest.isHabit || newest.stepsLeft == 0) {
            builder.addAction(0, context.getString(R.string.reminder_done), answer(context, newest, CallActions.DONE))
        }
        val timing = ReminderBook.timing(context)
        if (newest.snoozes < timing.maxSnoozes) {
            builder.addAction(0, context.getString(R.string.reminder_snooze, newest.snoozeMinutes), answer(context, newest, CallActions.SNOOZE))
        }
        return builder.build()
    }

    /** The alarm stream, for the ringing service and the tone previews. */
    val alarmAudio: AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    // --- Intents -------------------------------------------------------------

    /** Opens the app on what [item] is about — a habit, or a to-do. */
    fun open(context: Context, item: ReminderItem): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction("com.example.tide.OPEN_REMINDER")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(EXTRA_TARGET, if (item.isHabit) "habit" else "task")
            .putExtra(EXTRA_ID, item.subject)
        return PendingIntent.getActivity(
            context,
            ReminderItem.idFor("open:${item.occurrence}"),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Opens the call over the lock screen. */
    fun callIntent(context: Context, item: ReminderItem): PendingIntent {
        val intent = Intent(context, TideCallActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
            .putExtra(EXTRA_KEY, item.key)
        return PendingIntent.getActivity(
            context,
            CALL_ID,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun answer(context: Context, item: ReminderItem, outcome: String): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java)
            .setAction(ReminderReceiver.ACTION_ANSWER)
            .putExtra(EXTRA_KEY, item.key)
            .putExtra(ReminderReceiver.EXTRA_OUTCOME, outcome)
            // The whole reminder rides along: a heads-up that has been taken
            // out of the plan is no longer anywhere else to look it up.
            .putExtra(ReminderReceiver.EXTRA_ITEM, item.json.toString())
        return PendingIntent.getBroadcast(
            context,
            ReminderItem.idFor("${item.key}:$outcome"),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
