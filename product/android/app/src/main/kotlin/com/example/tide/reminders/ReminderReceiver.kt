package com.example.tide.reminders

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Where the phone hands reminders back to the app.
 *
 * * An alarm firing: every reminder due is taken out of the book and
 *   delivered — heads-ups posted, calls rung together, gentle ones posted —
 *   and the next alarm is armed.
 * * The once-a-minute redraw of heads-ups still counting down.
 * * A button pressed on a notification, with or without the app running.
 * * A reboot, an app update, a clock or time-zone change, or the exact-alarm
 *   permission changing: the alarms are armed again, from the book, with no
 *   Dart running. After a force stop Android delivers none of these; the
 *   plan is handed over again when the app next opens.
 */
class ReminderReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_ANSWER = "com.example.tide.reminders.ANSWER"
        const val EXTRA_OUTCOME = "tide_reminder_outcome"
        const val EXTRA_ITEM = "tide_reminder_item"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ReminderScheduler.ACTION_FIRE -> fire(context)
            ReminderScheduler.ACTION_TICK -> {
                ReminderNotifications.refreshHeadsUps(context)
                ReminderScheduler.armTick(context)
            }
            ACTION_ANSWER -> answer(context, intent)
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            -> {
                // Whatever was ringing went down with the phone, and the
                // heads-ups with it.
                ReminderBook.clearRinging(context)
                ReminderBook.setLive(context, emptyList())
                ReminderScheduler.rearm(context)
            }
            Intent.ACTION_TIMEZONE_CHANGED -> {
                ReminderBook.refloat(context)
                ReminderScheduler.rearm(context)
            }
            Intent.ACTION_TIME_CHANGED,
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED,
            -> ReminderScheduler.rearm(context)
        }
    }

    private fun fire(context: Context) {
        val now = System.currentTimeMillis()
        val stale = ReminderBook.timing(context).staleMinutes * 60_000L
        val due = ReminderBook.firstDeliveries(
            context,
            ReminderBook.takeDue(context, now + 1_500).distinctBy { it.key },
        )
        val ring = mutableListOf<ReminderItem>()
        for (item in due) {
            val late = now - item.at
            if (!item.isHeadsUp) {
                // The reminder itself has arrived: its heads-up has said its
                // piece.
                ReminderNotifications.cancelFor(context, item)
            }
            when {
                item.isHeadsUp -> if (item.dueAt > now) ReminderNotifications.headsUp(context, item)
                // The phone was off, or asleep past any alarm's reach: ringing
                // now would be for something already gone by.
                late > stale -> ReminderNotifications.missed(context, item)
                item.isGentle -> ReminderNotifications.gentle(context, item, silent = item.quiet)
                item.quiet || heldByDoNotDisturb(context, item) ->
                    ReminderNotifications.gentle(context, item, silent = true)
                else -> ring += item
            }
        }
        if (ring.isNotEmpty()) TideCallService.ring(context, ring)
        ReminderScheduler.rearm(context)
        ReminderScheduler.armTick(context)
    }

    /**
     * Do Not Disturb is on and this reminder was not allowed through it. It
     * still arrives — silently, in the shade — so nothing is lost by it.
     */
    private fun heldByDoNotDisturb(context: Context, item: ReminderItem): Boolean {
        if (item.throughDnd) return false
        val filter = context.getSystemService(NotificationManager::class.java).currentInterruptionFilter
        return filter != NotificationManager.INTERRUPTION_FILTER_ALL &&
            filter != NotificationManager.INTERRUPTION_FILTER_UNKNOWN
    }

    private fun answer(context: Context, intent: Intent) {
        val key = intent.getStringExtra(ReminderNotifications.EXTRA_KEY) ?: return
        val outcome = intent.getStringExtra(EXTRA_OUTCOME) ?: return
        val item = ReminderBook.find(context, key)
            ?: ReminderItem.parse(intent.getStringExtra(EXTRA_ITEM))
            ?: return
        CallActions.resolve(context, item, outcome)
    }
}
