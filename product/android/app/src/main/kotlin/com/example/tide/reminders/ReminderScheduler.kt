package com.example.tide.reminders

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.example.tide.MainActivity

/**
 * Arms the phone's alarms for whatever is due next.
 *
 * **One alarm for the next call, one for the next of everything else**, not
 * one per reminder. When either fires, the receiver takes every reminder due
 * by then out of the book, delivers them together — which is how three habits
 * at 07:30 become one call with three orbs — and arms the next. Android caps
 * how many alarms an app may hold; this holds two however long the plan is.
 *
 * **Calls use `setAlarmClock`.** It is the one kind of alarm Doze never
 * holds back, and it puts the next one on the lock screen the way a clock
 * app does — which is what a call is. Heads-ups and gentle reminders use
 * `setExactAndAllowWhileIdle`. Without the exact-alarm permission both fall
 * back to an inexact alarm, late rather than lost.
 */
object ReminderScheduler {
    const val ACTION_FIRE = "com.example.tide.reminders.FIRE"
    const val ACTION_TICK = "com.example.tide.reminders.TICK"

    private const val REQUEST_CALL = 7101
    private const val REQUEST_OTHER = 7102
    private const val REQUEST_TICK = 7103

    /** How often a heads-up on screen redraws its wave. */
    private const val TICK_MS = 60_000L

    fun rearm(context: Context) {
        val pending = ReminderBook.pending(context)
        val loud = pending.filter { it.isCall && !it.quiet }
        val rest = pending.filterNot { it.isCall && !it.quiet }
        arm(context, REQUEST_CALL, loud.minOfOrNull { it.at }, alarmClock = true)
        arm(context, REQUEST_OTHER, rest.minOfOrNull { it.at }, alarmClock = false)
    }

    fun canExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
    }

    private fun arm(context: Context, request: Int, at: Long?, alarmClock: Boolean) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val fire = PendingIntent.getBroadcast(
            context,
            request,
            Intent(context, ReminderReceiver::class.java).setAction(ACTION_FIRE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (at == null) {
            alarms.cancel(fire)
            return
        }
        // Already due — after a reboot, or a plan handed over late — fires
        // straight away, and the receiver decides whether it is too late to
        // ring.
        val time = maxOf(at, System.currentTimeMillis() + 500)
        try {
            when {
                alarmClock && canExact(context) -> alarms.setAlarmClock(
                    AlarmManager.AlarmClockInfo(time, showApp(context)),
                    fire,
                )
                canExact(context) ->
                    alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, fire)
                else -> alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, fire)
            }
        } catch (_: SecurityException) {
            // The exact-alarm permission was withdrawn between the check and
            // the call.
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, fire)
        }
    }

    /**
     * Redraws heads-ups still counting down, once a minute, so the wave in
     * them keeps rising. Inexact on purpose: nobody is owed a wave to the
     * second, and when the phone is asleep nobody is looking.
     */
    fun armTick(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val tick = PendingIntent.getBroadcast(
            context,
            REQUEST_TICK,
            Intent(context, ReminderReceiver::class.java).setAction(ACTION_TICK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val now = System.currentTimeMillis()
        if (ReminderBook.live(context).none { it.dueAt > now }) {
            alarms.cancel(tick)
            return
        }
        alarms.set(AlarmManager.RTC, now + TICK_MS, tick)
    }

    /** What tapping the alarm icon in the status bar opens. */
    private fun showApp(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        REQUEST_CALL,
        Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
