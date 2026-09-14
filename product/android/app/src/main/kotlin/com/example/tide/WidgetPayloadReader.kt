package com.example.tide

import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Decodes the JSON [HomeWidgetBridge] writes into HomeWidgetPreferences.
 *
 * Streak and Heatmap payloads are keyed per placed widget
 * (`single_habit_streak_<id>`), because two Heatmap widgets side by side
 * are two habits. Shared keys (`today_habits`, `habit_dashboard`, …) are
 * still one payload for every instance of that type.
 */
object WidgetPayloadReader {
    const val KEY_TODAY_HABITS = "today_habits"
    const val KEY_HABIT_DASHBOARD = "habit_dashboard"
    const val KEY_WEEKLY_RECAP = "weekly_recap"
    const val KEY_TODAY_TASKS = "today_tasks"

    data class TodayRow(
        val id: String,
        val name: String,
        val type: String,
        val done: Boolean,
        val streak: Int,
    )

    data class TodayPayload(
        val signedIn: Boolean,
        val done: Int,
        val total: Int,
        val rows: List<TodayRow>,
    )

    data class DashboardRow(
        val id: String,
        val name: String,
        val streak: Int,
        val week: IntArray,
    )

    data class DashboardPayload(
        val signedIn: Boolean,
        val isPro: Boolean,
        val best: Int,
        val rows: List<DashboardRow>,
    )

    data class StreakPayload(
        val configured: Boolean,
        val id: String? = null,
        val name: String? = null,
        val type: String = "binary",
        val streak: Int = 0,
        val doneToday: Boolean = false,
    )

    data class HeatmapPayload(
        val configured: Boolean,
        val id: String? = null,
        val type: String = "binary",
        val name: String? = null,
        val streak: Int = 0,
        /** One value per day ending today; see [WidgetHeatmap]. */
        val series: DoubleArray = DoubleArray(0),
    )

    data class TaskRow(
        val id: String,
        val title: String,
        val overdue: Boolean,
        val due: String,
    )

    data class TasksPayload(
        val signedIn: Boolean,
        val overdue: Int,
        val total: Int,
        val rows: List<TaskRow>,
    )

    data class RecapPayload(
        val signedIn: Boolean,
        val isPro: Boolean,
        val weekPercent: Int,
        val lastWeekPercent: Int,
        val bestStreak: Int,
        val checkIns: Int,
        val scheduled: Int,
        val range: String,
        /** Monday through today; see `WidgetPayload.weeklyRecap`. */
        val days: DoubleArray = DoubleArray(0),
    )

    fun todayHabits(widgetData: SharedPreferences): TodayPayload? {
        val json = json(widgetData, KEY_TODAY_HABITS) ?: return null
        if (!json.optBoolean("signedIn", false)) {
            return TodayPayload(signedIn = false, done = 0, total = 0, rows = emptyList())
        }
        return TodayPayload(
            signedIn = true,
            done = json.optInt("done", 0),
            total = json.optInt("total", 0),
            rows = json.optJSONArray("rows").rows { row ->
                TodayRow(
                    id = row.getString("id"),
                    name = row.getString("name"),
                    type = row.optString("type", "binary"),
                    done = row.optBoolean("done", false),
                    streak = row.optInt("streak", 0),
                )
            },
        )
    }

    fun habitDashboard(widgetData: SharedPreferences): DashboardPayload? {
        val json = json(widgetData, KEY_HABIT_DASHBOARD) ?: return null
        val isPro = json.optBoolean("isPro", false)
        if (!json.optBoolean("signedIn", false)) {
            return DashboardPayload(signedIn = false, isPro = isPro, best = 0, rows = emptyList())
        }
        return DashboardPayload(
            signedIn = true,
            isPro = isPro,
            best = json.optInt("best", 0),
            rows = json.optJSONArray("rows").rows { row ->
                DashboardRow(
                    id = row.getString("id"),
                    name = row.getString("name"),
                    streak = row.optInt("streak", 0),
                    week = weekCodes(row.optJSONArray("week")),
                )
            },
        )
    }

    fun singleHabitStreak(widgetData: SharedPreferences, widgetId: Int): StreakPayload? {
        val json = json(widgetData, "single_habit_streak_$widgetId") ?: return null
        if (!json.optBoolean("configured", false)) return StreakPayload(configured = false)
        return StreakPayload(
            configured = true,
            id = json.getString("id"),
            name = json.getString("name"),
            type = json.optString("type", "binary"),
            streak = json.optInt("streak", 0),
            doneToday = json.optBoolean("doneToday", false),
        )
    }

    fun heatmapHeader(widgetData: SharedPreferences, widgetId: Int): HeatmapPayload? {
        val json = json(widgetData, "habit_heatmap_$widgetId") ?: return null
        if (!json.optBoolean("configured", false)) return HeatmapPayload(configured = false)
        return HeatmapPayload(
            configured = true,
            id = json.getString("id"),
            type = json.optString("type", "binary"),
            name = json.getString("name"),
            streak = json.optInt("streak", 0),
            series = doubles(json.optJSONArray("series")),
        )
    }

    fun todayTasks(widgetData: SharedPreferences): TasksPayload? {
        val json = json(widgetData, KEY_TODAY_TASKS) ?: return null
        if (!json.optBoolean("signedIn", false)) {
            return TasksPayload(signedIn = false, overdue = 0, total = 0, rows = emptyList())
        }
        return TasksPayload(
            signedIn = true,
            overdue = json.optInt("overdue", 0),
            total = json.optInt("total", 0),
            rows = json.optJSONArray("rows").rows { row ->
                TaskRow(
                    id = row.getString("id"),
                    title = row.getString("title"),
                    overdue = row.optBoolean("overdue", false),
                    due = row.optString("due", ""),
                )
            },
        )
    }

    fun weeklyRecap(widgetData: SharedPreferences): RecapPayload? {
        val json = json(widgetData, KEY_WEEKLY_RECAP) ?: return null
        val isPro = json.optBoolean("isPro", false)
        if (!json.optBoolean("signedIn", false)) {
            return RecapPayload(
                signedIn = false,
                isPro = isPro,
                weekPercent = 0,
                lastWeekPercent = 0,
                bestStreak = 0,
                checkIns = 0,
                scheduled = 0,
                range = "",
            )
        }
        return RecapPayload(
            signedIn = true,
            isPro = isPro,
            weekPercent = json.optInt("weekPercent", 0),
            lastWeekPercent = json.optInt("lastWeekPercent", 0),
            bestStreak = json.optInt("bestStreak", 0),
            checkIns = json.optInt("checkIns", 0),
            scheduled = json.optInt("scheduled", 0),
            range = json.optString("range", ""),
            days = doubles(json.optJSONArray("days")),
        )
    }

    private fun json(widgetData: SharedPreferences, key: String): JSONObject? {
        val raw = widgetData.getString(key, null) ?: return null
        return try {
            JSONObject(raw)
        } catch (_: Exception) {
            null
        }
    }

    private fun <T> JSONArray?.rows(parse: (JSONObject) -> T): List<T> {
        if (this == null) return emptyList()
        return try {
            (0 until length()).map { parse(getJSONObject(it)) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun doubles(array: JSONArray?): DoubleArray {
        if (array == null) return DoubleArray(0)
        return DoubleArray(array.length()) { array.optDouble(it, -1.0) }
    }

    private fun weekCodes(array: JSONArray?): IntArray {
        val codes = IntArray(7)
        if (array == null) return codes
        for (i in 0 until minOf(7, array.length())) {
            codes[i] = array.optInt(i, 0)
        }
        return codes
    }
}
