package com.example.tide.reminders

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/**
 * What answering a reminder does, wherever it was answered: on the lock
 * screen, or with a button on a notification with the app closed.
 *
 * Native code never changes a habit or a to-do. An answer is queued in the
 * book's inbox and applied by the app's stores the next time it runs — at
 * once, when it already is (`ReminderBridge.notifyActions`). What happens
 * here is only what has to happen *now*: the ringing stops, a snooze is
 * armed, and nothing else rings about something already answered.
 */
object CallActions {
    const val DONE = "done"
    const val SKIP = "skip"
    const val SNOOZE = "snooze"
    const val TOMORROW = "tomorrow"
    const val DISMISS = "dismiss"
    const val ON_IT = "onIt"

    fun resolve(context: Context, item: ReminderItem, outcome: String) {
        when (outcome) {
            DONE -> {
                queue(context, item, if (item.isHabit) "habitDone" else "taskDone")
                if (item.isHabit) {
                    ReminderBook.dropOccurrence(context, item.occurrence)
                } else {
                    // A to-do done is done: none of its other reminders has
                    // anything left to ask either.
                    dropSubject(context, item)
                }
            }
            SKIP -> {
                queue(context, item, "habitSkip")
                ReminderBook.dropOccurrence(context, item.occurrence)
            }
            TOMORROW -> {
                queue(context, item, "taskTomorrow")
                ReminderBook.dropOccurrence(context, item.occurrence)
                tomorrow(context, item)
            }
            SNOOZE -> snooze(context, item)
            // "I'm on it" keeps the call; "Dismiss" leaves the habit open.
            ON_IT, DISMISS -> Unit
        }
        ReminderNotifications.cancelFor(context, item)
        TideCallService.answered(context, item.key)
        ReminderScheduler.rearm(context)
    }

    /** A step ticked or unticked on the lock screen. */
    fun step(context: Context, item: ReminderItem, stepId: String, value: Boolean) {
        queue(context, item, "taskStep", step = stepId, value = value)
        // The call's own copy follows, so a reload shows the tick.
        val steps = item.details.optJSONArray("steps") ?: return
        val next = JSONArray()
        for (i in 0 until steps.length()) {
            val step = JSONObject(steps.getJSONObject(i).toString())
            if (step.optString("id") == stepId) step.put("done", value)
            next.put(step)
        }
        val details = JSONObject(item.details.toString()).put("steps", next)
        ReminderBook.addRinging(context, listOf(item.with("details", details)))
    }

    fun snooze(context: Context, item: ReminderItem) {
        val timing = ReminderBook.timing(context)
        if (item.snoozes >= timing.maxSnoozes) {
            // The last "later" has been spent: it goes out as missed.
            ReminderNotifications.missed(context, item)
            return
        }
        if (item.test) return
        val at = System.currentTimeMillis() + item.snoozeMinutes * 60_000L
        ReminderBook.addSnoozed(
            context,
            item.movedTo(at).with("snoozes", item.snoozes + 1).with("floating", false),
        )
    }

    /** A snooze chosen inside the app, where the app counted the snoozes. */
    fun snoozeFromApp(context: Context, item: ReminderItem, after: Long, snoozes: Int) {
        if (item.test) return
        val at = System.currentTimeMillis() + after
        ReminderBook.addSnoozed(context, item.movedTo(at).with("snoozes", snoozes).with("floating", false))
        ReminderScheduler.rearm(context)
    }

    /**
     * The reminder that rang, again tomorrow at the same time of day — under
     * the key the app's own plan will give it once it has moved the to-do,
     * so the two are one reminder rather than two when the app catches up.
     */
    private fun tomorrow(context: Context, item: ReminderItem) {
        if (item.test || item.isHabit) return
        val zone = ZoneId.systemDefault()
        val next = Instant.ofEpochMilli(item.dueAt).atZone(zone)
            .truncatedTo(ChronoUnit.MINUTES)
            .plusDays(1)
            .toInstant()
            .toEpochMilli()
        val occurrence = "t:${item.subject}:$next"
        val moved = item.movedTo(next)
            .with("occurrence", occurrence)
            .with("key", "$occurrence:${item.key.substringAfterLast(':')}")
            .with("snoozes", 0)
        ReminderBook.addSnoozed(context, moved)
    }

    private fun dropSubject(context: Context, item: ReminderItem) {
        for (other in ReminderBook.pending(context)) {
            if (other.subject == item.subject && other.group == item.group) {
                ReminderBook.dropOccurrence(context, other.occurrence)
            }
        }
    }

    private fun queue(
        context: Context,
        item: ReminderItem,
        type: String,
        step: String? = null,
        value: Boolean = true,
    ) {
        if (item.test) return
        val answer = JSONObject()
            .put("id", "${item.key}:$type:${System.nanoTime()}")
            .put("type", type)
            .put("subject", item.subject)
            .put("at", System.currentTimeMillis())
            .put("value", value)
        item.day?.let { answer.put("day", it) }
        item.account?.let { answer.put("account", it) }
        step?.let { answer.put("step", it) }
        ReminderBook.addAnswer(context, answer)
        ReminderBridge.notifyActions()
    }
}
