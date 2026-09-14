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
    const val KEY_SINGLE_HABIT_STREAK = "single_habit_streak"
    const val KEY_HABIT_HEATMAP_META = "habit_heatmap_meta"
    const val KEY_HABIT_HEATMAP_IMAGE = "habit_heatmap_image"
    const val KEY_WEEKLY_RECAP = "weekly_recap"
    const val KEY_TODAY_TASKS = "today_tasks"

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

    data class StreakPayload(
        val configured: Boolean,
        val id: String? = null,
        val name: String? = null,
        val type: String = "binary",
        val streak: Int = 0,
        val doneToday: Boolean = false,
    )

    /** Null only when nothing has been written yet or the JSON is bad — not
     * the same as "not configured", which is a real, expected value. */
    fun singleHabitStreak(widgetData: SharedPreferences): StreakPayload? {
        val raw = widgetData.getString(KEY_SINGLE_HABIT_STREAK, null) ?: return null
        return try {
            val json = JSONObject(raw)
            if (!json.optBoolean("signedIn", false) || !json.optBoolean("configured", false)) {
                return StreakPayload(configured = false)
            }
            StreakPayload(
                configured = true,
                id = json.getString("id"),
                name = json.getString("name"),
                type = json.optString("type", "binary"),
                streak = json.optInt("streak", 0),
                doneToday = json.optBoolean("doneToday", false),
            )
        } catch (error: Exception) {
            null
        }
    }

    data class TaskRow(val id: String, val title: String, val overdue: Boolean)

    data class TasksPayload(val signedIn: Boolean, val rows: List<TaskRow>)

    fun todayTasks(widgetData: SharedPreferences): TasksPayload? {
        val raw = widgetData.getString(KEY_TODAY_TASKS, null) ?: return null
        return try {
            val json = JSONObject(raw)
            val signedIn = json.optBoolean("signedIn", false)
            if (!signedIn) return TasksPayload(signedIn = false, rows = emptyList())

            val rowsJson = json.optJSONArray("rows") ?: return TasksPayload(true, emptyList())
            val rows = (0 until rowsJson.length()).map { i ->
                val row = rowsJson.getJSONObject(i)
                TaskRow(
                    id = row.getString("id"),
                    title = row.getString("title"),
                    overdue = row.optBoolean("overdue", false),
                )
            }
            TasksPayload(signedIn = true, rows = rows)
        } catch (error: Exception) {
            null
        }
    }

    data class HeatmapMeta(val isPro: Boolean, val configured: Boolean)

    fun heatmapMeta(widgetData: SharedPreferences): HeatmapMeta? {
        val raw = widgetData.getString(KEY_HABIT_HEATMAP_META, null) ?: return null
        return try {
            val json = JSONObject(raw)
            HeatmapMeta(
                isPro = json.optBoolean("isPro", false),
                configured = json.optBoolean("configured", false),
            )
        } catch (error: Exception) {
            null
        }
    }

    /** The image path [HomeWidget.renderFlutterWidget] wrote — same key the
     * plugin's own `saveFile`/`saveImage` use, read like any other string. */
    fun heatmapImagePath(widgetData: SharedPreferences): String? =
        widgetData.getString(KEY_HABIT_HEATMAP_IMAGE, null)

    data class RecapPayload(val isPro: Boolean, val weekPercent: Int, val bestStreak: Int)

    fun weeklyRecap(widgetData: SharedPreferences): RecapPayload? {
        val raw = widgetData.getString(KEY_WEEKLY_RECAP, null) ?: return null
        return try {
            val json = JSONObject(raw)
            if (!json.optBoolean("signedIn", false)) return null
            RecapPayload(
                isPro = json.optBoolean("isPro", false),
                weekPercent = json.optInt("weekPercent", 0),
                bestStreak = json.optInt("bestStreak", 0),
            )
        } catch (error: Exception) {
            null
        }
    }
}
