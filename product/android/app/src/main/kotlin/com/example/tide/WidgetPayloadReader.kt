package com.example.tide

import android.content.SharedPreferences
import org.json.JSONObject

/**
 * Decodes the JSON [HomeWidgetBridge] (Dart side) writes into
 * `HomeWidgetPreferences` under [KEY_TODAY_HABITS] / [KEY_HABIT_DASHBOARD].
 *
 * This is the one place both providers turn that JSON into typed rows, so
 * the shape only has to be agreed on once between Dart and Kotlin.
 */
object WidgetPayloadReader {
    const val KEY_TODAY_HABITS = "today_habits"
    const val KEY_HABIT_DASHBOARD = "habit_dashboard"

    data class TodayRow(
        val id: String,
        val name: String,
        val type: String,
        val done: Boolean,
    )

    data class TodayPayload(val signedIn: Boolean, val rows: List<TodayRow>)

    data class DashboardRow(
        val id: String,
        val name: String,
        val streak: Int,
        val dueToday: Boolean,
        val doneToday: Boolean,
    )

    data class DashboardPayload(
        val signedIn: Boolean,
        val isPro: Boolean,
        val rows: List<DashboardRow>,
    )

    /** Null when nothing has been written yet, or the JSON can't be parsed. */
    fun todayHabits(widgetData: SharedPreferences): TodayPayload? {
        val raw = widgetData.getString(KEY_TODAY_HABITS, null) ?: return null
        return try {
            val json = JSONObject(raw)
            val signedIn = json.optBoolean("signedIn", false)
            if (!signedIn) return TodayPayload(signedIn = false, rows = emptyList())

            val rowsJson = json.optJSONArray("rows") ?: return TodayPayload(true, emptyList())
            val rows = (0 until rowsJson.length()).map { i ->
                val row = rowsJson.getJSONObject(i)
                TodayRow(
                    id = row.getString("id"),
                    name = row.getString("name"),
                    type = row.optString("type", "binary"),
                    done = row.optBoolean("done", false),
                )
            }
            TodayPayload(signedIn = true, rows = rows)
        } catch (error: Exception) {
            null
        }
    }

    fun habitDashboard(widgetData: SharedPreferences): DashboardPayload? {
        val raw = widgetData.getString(KEY_HABIT_DASHBOARD, null) ?: return null
        return try {
            val json = JSONObject(raw)
            val signedIn = json.optBoolean("signedIn", false)
            val isPro = json.optBoolean("isPro", false)
            if (!signedIn) return DashboardPayload(signedIn = false, isPro = isPro, rows = emptyList())

            val rowsJson = json.optJSONArray("rows") ?: return DashboardPayload(true, isPro, emptyList())
            val rows = (0 until rowsJson.length()).map { i ->
                val row = rowsJson.getJSONObject(i)
                DashboardRow(
                    id = row.getString("id"),
                    name = row.getString("name"),
                    streak = row.optInt("streak", 0),
                    dueToday = row.optBoolean("dueToday", false),
                    doneToday = row.optBoolean("doneToday", false),
                )
            }
            DashboardPayload(signedIn = true, isPro = isPro, rows = rows)
        } catch (error: Exception) {
            null
        }
    }
}
