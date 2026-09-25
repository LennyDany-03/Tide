package com.example.tide.reminders

import com.example.tide.R
import org.json.JSONObject

/**
 * One planned reminder, exactly as Dart wrote it (`PlannedReminder.toJson`
 * in lib/services/reminders/reminder_plan.dart).
 *
 * A thin view over the JSON rather than a copy of its fields: the object is
 * stored and handed back to Dart as it came, so a field this file does not
 * read — the week under the orb, a to-do's steps — survives the round trip
 * without this file having to know it exists.
 *
 * Every sentence a notification shows is in [copy]. Nothing here writes
 * words of its own.
 */
class ReminderItem(val json: JSONObject) {
    val key: String get() = json.getString("key")
    val occurrence: String get() = json.optString("occurrence", key)
    val kind: String get() = json.getString("kind")
    val at: Long get() = json.getLong("at")
    val dueAt: Long get() = json.optLong("dueAt", at)
    val local: String? get() = json.optString("local").ifEmpty { null }

    /** Milliseconds between the heads-up and what it counts down to. */
    val lead: Long get() = json.optLong("lead", dueAt - at)

    val floating: Boolean get() = json.optBoolean("floating", false)
    val quiet: Boolean get() = json.optBoolean("quiet", false)
    val test: Boolean get() = json.optBoolean("test", false)
    val subject: String get() = json.getString("subject")
    val title: String get() = json.optString("title", "")
    val account: String? get() = json.optString("account").ifEmpty { null }
    val snoozes: Int get() = json.optInt("snoozes", 0)

    val options: JSONObject get() = json.optJSONObject("options") ?: JSONObject()
    val details: JSONObject get() = json.optJSONObject("details") ?: JSONObject()
    private val copyJson: JSONObject get() = json.optJSONObject("copy") ?: JSONObject()

    fun copy(name: String): String = copyJson.optString(name, "")

    val isHabit: Boolean get() = kind.startsWith("habit")
    val isHeadsUp: Boolean get() = kind.endsWith("HeadsUp")
    val isCall: Boolean get() = kind.endsWith("Call")
    val isGentle: Boolean get() = kind.endsWith("Gentle")
    val group: String get() = if (isHabit) ReminderBook.HABITS else ReminderBook.TASKS

    val snoozeMinutes: Int get() = options.optInt("snooze", 10)
    val vibrate: Boolean get() = options.optBoolean("vibrate", true)
    val throughDnd: Boolean get() = options.optBoolean("dnd", false)

    /** The raw resource the tone is in (`tool/reminder_tones_test.dart`). */
    val tone: Int get() = toneFor(options.optString("tone"))

    val glyph: String? get() = details.optString("glyph").ifEmpty { null }

    /** Freezes the habit has left, for "Skip today". */
    val freezes: Int get() = details.optInt("freezes", 0)

    /** Steps still open on a to-do. It cannot be marked done while any are. */
    val stepsLeft: Int
        get() {
            val steps = details.optJSONArray("steps") ?: return 0
            var left = 0
            for (i in 0 until steps.length()) {
                if (!steps.getJSONObject(i).optBoolean("done", false)) left++
            }
            return left
        }

    /** The habit's day this is about, `2026-09-25`, or null for a to-do. */
    val day: String? get() = details.optString("day").ifEmpty { null }

    /** A copy moved to [at] — for a snooze, or a time-zone change. */
    fun movedTo(at: Long, dueAt: Long = at): ReminderItem {
        val moved = JSONObject(json.toString())
        moved.put("at", at)
        moved.put("dueAt", dueAt)
        return ReminderItem(moved)
    }

    fun with(name: String, value: Any): ReminderItem {
        val next = JSONObject(json.toString())
        next.put(name, value)
        return ReminderItem(next)
    }

    companion object {
        /**
         * A tone by its `ReminderTone` name — or by its resource name, which
         * is how the pickers ask for a preview. By `R.raw` rather than looked
         * up by name, so the tones are seen as used and survive shrinking.
         */
        fun toneFor(name: String?): Int = when (name) {
            "ripple", "tone_ripple" -> R.raw.tone_ripple
            "swell", "tone_swell" -> R.raw.tone_swell
            "deepBell", "tone_deep_bell" -> R.raw.tone_deep_bell
            else -> R.raw.tone_low_tide
        }

        fun parse(raw: Any?): ReminderItem? = try {
            when (raw) {
                is JSONObject -> ReminderItem(raw).takeIf { it.valid() }
                is String -> ReminderItem(JSONObject(raw)).takeIf { it.valid() }
                else -> null
            }
        } catch (_: Exception) {
            null
        }

        /**
         * A stable notification id for [name]: FNV-1a, the same hash the Dart
         * side uses for its keys, so an update replaces rather than stacks.
         */
        fun idFor(name: String): Int {
            var hash = 0x811c9dc5.toInt()
            for (unit in name) {
                hash = (hash xor unit.code) * 0x01000193
            }
            return hash and 0x7fffffff
        }
    }

    private fun valid(): Boolean =
        json.has("key") && json.has("kind") && json.has("at") && json.has("subject")
}
