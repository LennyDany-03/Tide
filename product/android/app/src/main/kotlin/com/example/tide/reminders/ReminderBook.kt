package com.example.tide.reminders

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.example.tide.R
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * Everything reminders keep on the phone, so they can ring with no Dart
 * running and come back after a reboot.
 *
 * * **Plans**, one per group (`habits`, `tasks`, and `test` for the test
 *   button): each is replaced whole whenever Dart hands a new one over, so a
 *   habit edit can never touch a to-do reminder.
 * * **Snoozed** reminders, which Dart never sees: they are made here, by a
 *   button on a notification or the lock screen.
 * * **Ringing**: the calls the ringing service and the lock-screen activity
 *   are showing right now.
 * * **The inbox**: answers given where no store could hear them, handed to
 *   Dart the next time the app runs (`ReminderStore.drain`).
 * * **The look and the timings**, from the palette and `AppConstants`.
 *
 * One lock around all of it. A receiver, the service and the activity all
 * run on the main thread in practice, but the method channel does not have
 * to, and a lost answer is the one failure here nobody would ever notice.
 */
// Writes use commit(), not apply(), on purpose: most of them happen in a
// broadcast receiver, and an answer or a delivery written in the background
// could be lost if the process goes the moment the receiver returns.
@SuppressLint("ApplySharedPref")
object ReminderBook {
    const val HABITS = "habits"
    const val TASKS = "tasks"
    const val TEST = "test"

    private const val FILE = "tide_reminders"
    private const val SNOOZED = "snoozed"
    private const val RINGING = "ringing"
    private const val INBOX = "inbox"
    private const val LOOK = "look"
    private const val TIMING = "timing"
    private const val LIVE = "live"
    private const val ASKED_NOTIFICATIONS = "asked_notifications"
    private const val DELIVERED = "delivered"

    /** How long a delivered reminder is remembered, to be sure it fires once. */
    private const val DELIVERED_MS = 30 * 60_000L

    private val lock = Any()

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    private fun list(context: Context, name: String): MutableList<ReminderItem> {
        val raw = prefs(context).getString(name, null) ?: return mutableListOf()
        return try {
            val array = JSONArray(raw)
            MutableList(array.length()) { array.getJSONObject(it) }
                .mapNotNull { ReminderItem.parse(it) }
                .toMutableList()
        } catch (_: Exception) {
            mutableListOf()
        }
    }

    private fun write(context: Context, name: String, items: List<ReminderItem>) {
        val array = JSONArray()
        items.forEach { array.put(it.json) }
        prefs(context).edit().putString(name, array.toString()).commit()
    }

    private fun planKey(group: String) = "plan.$group"

    // --- Plans ---------------------------------------------------------------

    /**
     * Replaces [group]'s plan. A snoozed or moved copy the new plan now holds
     * itself — a to-do put off to tomorrow, once the app has moved it — is
     * dropped, so the two do not both ring.
     */
    fun setPlan(context: Context, group: String, items: List<ReminderItem>) = synchronized(lock) {
        write(context, planKey(group), items)
        val keys = items.map { it.key }.toSet()
        val snoozed = list(context, SNOOZED)
        if (snoozed.removeAll { it.group == group && it.key in keys }) write(context, SNOOZED, snoozed)
    }

    /** Adds to the test plan rather than replacing it: two taps, two tests. */
    fun addTests(context: Context, items: List<ReminderItem>) = synchronized(lock) {
        val tests = list(context, planKey(TEST))
        tests.removeAll { old -> items.any { it.key == old.key } }
        tests.addAll(items)
        write(context, planKey(TEST), tests)
    }

    /** Everything still to fire: every plan and every snooze. */
    fun pending(context: Context): List<ReminderItem> = synchronized(lock) {
        listOf(HABITS, TASKS, TEST).flatMap { list(context, planKey(it)) } +
            list(context, SNOOZED)
    }

    /**
     * Takes every reminder due by [until] out of the plans and the snoozes and
     * returns them, soonest first. Taken, so it fires once.
     */
    fun takeDue(context: Context, until: Long): List<ReminderItem> = synchronized(lock) {
        val due = mutableListOf<ReminderItem>()
        for (name in listOf(planKey(HABITS), planKey(TASKS), planKey(TEST), SNOOZED)) {
            val items = list(context, name)
            val (now, later) = items.partition { it.at <= until }
            if (now.isEmpty()) continue
            due += now
            write(context, name, later)
        }
        due.sortedBy { it.at }
    }

    /**
     * Drops whatever is still planned for [occurrence] — "Done already" on a
     * heads-up means the call behind it has nothing left to ask.
     */
    fun dropOccurrence(context: Context, occurrence: String) = synchronized(lock) {
        for (name in listOf(planKey(HABITS), planKey(TASKS), planKey(TEST), SNOOZED)) {
            val items = list(context, name)
            if (items.removeAll { it.occurrence == occurrence }) write(context, name, items)
        }
    }

    /**
     * After a time-zone change: a habit at 07:30 is at 07:30 wherever the
     * phone now is, so each floating reminder's instant is worked out again
     * from the wall-clock time Dart wrote beside it.
     */
    fun refloat(context: Context) = synchronized(lock) {
        val zone = ZoneId.systemDefault()
        for (name in listOf(planKey(HABITS), planKey(TASKS))) {
            val items = list(context, name).map { item ->
                val local = item.local
                if (!item.floating || local == null) return@map item
                try {
                    val due = LocalDateTime.parse(local).atZone(zone).toInstant().toEpochMilli()
                    item.movedTo(due - item.lead, due)
                } catch (_: Exception) {
                    item
                }
            }
            write(context, name, items)
        }
    }

    /**
     * Keeps only [due] reminders not already delivered, and remembers these.
     *
     * A plan handed over a second before an alarm fires can put back a
     * reminder the receiver has just taken and delivered — it was still in
     * the future when Dart worked the plan out. By key and time, so a snooze
     * (the same key, later) is a new delivery and still rings.
     */
    fun firstDeliveries(context: Context, due: List<ReminderItem>): List<ReminderItem> = synchronized(lock) {
        val prefs = prefs(context)
        val now = System.currentTimeMillis()
        val seen = try {
            JSONObject(prefs.getString(DELIVERED, "{}") ?: "{}")
        } catch (_: Exception) {
            JSONObject()
        }
        val kept = JSONObject()
        for (name in seen.keys()) {
            val at = seen.optLong(name)
            if (now - at < DELIVERED_MS) kept.put(name, at)
        }
        val fresh = due.filter { item -> !kept.has("${item.key}@${item.at}") }
        fresh.forEach { kept.put("${it.key}@${it.at}", now) }
        prefs.edit().putString(DELIVERED, kept.toString()).commit()
        fresh
    }

    // --- Snoozes -------------------------------------------------------------

    fun addSnoozed(context: Context, item: ReminderItem) = synchronized(lock) {
        val items = list(context, SNOOZED)
        items.removeAll { it.occurrence == item.occurrence }
        items.add(item)
        write(context, SNOOZED, items)
    }

    /** Drops snoozes in [group] about anything no longer in [open]. */
    fun pruneSnoozed(context: Context, group: String, open: Set<String>) = synchronized(lock) {
        val items = list(context, SNOOZED)
        if (items.removeAll { it.group == group && !it.test && it.subject !in open }) {
            write(context, SNOOZED, items)
        }
    }

    // --- Ringing -------------------------------------------------------------

    fun ringing(context: Context): List<ReminderItem> =
        synchronized(lock) { list(context, RINGING) }

    fun addRinging(context: Context, items: List<ReminderItem>) = synchronized(lock) {
        val ringing = list(context, RINGING)
        ringing.removeAll { old -> items.any { it.key == old.key } }
        ringing.addAll(items)
        write(context, RINGING, ringing)
    }

    fun removeRinging(context: Context, key: String): ReminderItem? = synchronized(lock) {
        val ringing = list(context, RINGING)
        val found = ringing.firstOrNull { it.key == key }
        if (found != null) {
            ringing.remove(found)
            write(context, RINGING, ringing)
        }
        found
    }

    fun clearRinging(context: Context): List<ReminderItem> = synchronized(lock) {
        val ringing = list(context, RINGING)
        write(context, RINGING, emptyList())
        ringing
    }

    /** A reminder by key, wherever it is kept. */
    fun find(context: Context, key: String): ReminderItem? = synchronized(lock) {
        list(context, RINGING).firstOrNull { it.key == key }
            ?: list(context, LIVE).firstOrNull { it.key == key }
            ?: pending(context).firstOrNull { it.key == key }
    }

    // --- Heads-ups on screen -------------------------------------------------

    /** Heads-ups posted and still counting down, for the minute redraw. */
    fun live(context: Context): List<ReminderItem> = synchronized(lock) { list(context, LIVE) }

    fun addLive(context: Context, item: ReminderItem) = synchronized(lock) {
        val live = list(context, LIVE)
        live.removeAll { it.key == item.key }
        live.add(item)
        write(context, LIVE, live)
    }

    fun setLive(context: Context, items: List<ReminderItem>) =
        synchronized(lock) { write(context, LIVE, items) }

    fun dropLive(context: Context, occurrence: String) = synchronized(lock) {
        val live = list(context, LIVE)
        if (live.removeAll { it.occurrence == occurrence }) write(context, LIVE, live)
    }

    // --- The inbox -----------------------------------------------------------

    fun addAnswer(context: Context, answer: JSONObject) = synchronized(lock) {
        val prefs = prefs(context)
        val inbox = try {
            JSONArray(prefs.getString(INBOX, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        inbox.put(answer)
        prefs.edit().putString(INBOX, inbox.toString()).commit()
    }

    /** Every answer waiting, as JSON, and none left behind. */
    fun takeAnswers(context: Context): String = synchronized(lock) {
        val prefs = prefs(context)
        val inbox = prefs.getString(INBOX, "[]") ?: "[]"
        prefs.edit().remove(INBOX).commit()
        inbox
    }

    /** Answers waiting, without taking them — for the call's figures. */
    fun peekAnswers(context: Context): JSONArray = synchronized(lock) {
        try {
            JSONArray(prefs(context).getString(INBOX, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
    }

    // --- The look, the timings, the marks -----------------------------------

    fun setLook(context: Context, look: Map<*, *>?) {
        if (look == null) return
        prefs(context).edit().putString(LOOK, JSONObject(look).toString()).apply()
    }

    fun setTiming(context: Context, timing: Map<*, *>?) {
        if (timing == null) return
        prefs(context).edit().putString(TIMING, JSONObject(timing).toString()).apply()
    }

    fun look(context: Context): Look {
        val raw = prefs(context).getString(LOOK, null)
        val json = try {
            if (raw == null) null else JSONObject(raw)
        } catch (_: Exception) {
            null
        }
        return Look.from(context, json)
    }

    fun timing(context: Context): Timing {
        val raw = prefs(context).getString(TIMING, null)
        val json = try {
            if (raw == null) JSONObject() else JSONObject(raw)
        } catch (_: Exception) {
            JSONObject()
        }
        return Timing(
            ringMinutes = json.optInt("ringMinutes", 2),
            swellSeconds = json.optInt("swellSeconds", 10),
            staleMinutes = json.optInt("staleMinutes", 10),
            maxSnoozes = json.optInt("maxSnoozes", 3),
            pulseMillis = json.optLong("pulseMillis", 3000),
        )
    }

    private fun glyphDir(context: Context) = File(context.filesDir, "reminder_glyphs")

    fun saveGlyphs(context: Context, glyphs: Map<*, *>?) {
        if (glyphs.isNullOrEmpty()) return
        val dir = glyphDir(context).apply { mkdirs() }
        for ((name, bytes) in glyphs) {
            if (name !is String || bytes !is ByteArray) continue
            // Names are TideGlyph enum names, but nothing from a channel is
            // trusted with a path.
            if (!name.matches(Regex("[A-Za-z0-9]+"))) continue
            File(dir, "$name.png").writeBytes(bytes)
        }
    }

    fun glyph(context: Context, name: String?): Bitmap? {
        if (name == null || !name.matches(Regex("[A-Za-z0-9]+"))) return null
        val file = File(glyphDir(context), "$name.png")
        return if (file.exists()) BitmapFactory.decodeFile(file.path) else null
    }

    // --- Permissions ---------------------------------------------------------

    fun askedForNotifications(context: Context): Boolean =
        prefs(context).getBoolean(ASKED_NOTIFICATIONS, false)

    fun markAskedForNotifications(context: Context) {
        prefs(context).edit().putBoolean(ASKED_NOTIFICATIONS, true).apply()
    }
}

/** The numbers reminders ring by. Dart's `AppConstants` is the authority. */
data class Timing(
    val ringMinutes: Int,
    val swellSeconds: Int,
    val staleMinutes: Int,
    val maxSnoozes: Int,
    val pulseMillis: Long,
)

/**
 * The palette, as Dart sent it: `TideColors` roles as ARGB. Before Dart has
 * sent one, Midnight's own widget colours stand in — never a colour made up
 * here.
 */
data class Look(
    val light: Boolean,
    val ground: Int,
    val surface: Int,
    val raised: Int,
    val recess: Int,
    val ink: Int,
    val muted: Int,
    val accent: Int,
    val onAccent: Int,
    val frost: Int,
    val flare: Int,
    val ember: Int,
) {
    companion object {
        fun from(context: Context, json: JSONObject?): Look {
            fun res(id: Int) = context.getColor(id)
            fun pick(name: String, fallback: Int): Int =
                if (json != null && json.has(name)) json.getLong(name).toInt() else fallback
            return Look(
                light = json?.optBoolean("light", false) ?: false,
                ground = pick("ground", res(R.color.tide_ground)),
                surface = pick("surface", res(R.color.tide_shelf)),
                raised = pick("raised", res(R.color.tide_shoal)),
                recess = pick("recess", res(R.color.tide_ground)),
                ink = pick("ink", res(R.color.tide_bone)),
                muted = pick("muted", res(R.color.tide_silt)),
                accent = pick("accent", res(R.color.tide_lantern)),
                onAccent = pick("onAccent", res(R.color.tide_on_lantern)),
                frost = pick("frost", res(R.color.tide_bone)),
                flare = pick("flare", res(R.color.tide_flare)),
                ember = pick("ember", res(R.color.tide_ember)),
            )
        }
    }
}
