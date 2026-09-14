package com.example.tide

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Pro widget: up to [MAX_ROWS] habits ranked by current streak.
 *
 * The locked (free) state is a completely different RemoteViews tree
 * ([R.layout.widget_habit_dashboard_locked]), not the unlocked rows dimmed
 * behind a scrim — building and hiding 6 habit rows just to show a lock
 * icon would be wasted work on every render, and Android's RemoteViews
 * can't restructure a tree cheaply anyway. The locked tile is one tap
 * target straight into the Upgrade paywall; the actual animated "unlock"
 * moment lives there, in Flutter, not on the home screen (RemoteViews has
 * no arbitrary-animation API to draw one here).
 */
class HabitDashboardWidgetProvider : HomeWidgetProvider() {
    companion object {
        const val MAX_ROWS = 6
        private val ROW_IDS = intArrayOf(
            R.id.dashboard_row_1, R.id.dashboard_row_2, R.id.dashboard_row_3,
            R.id.dashboard_row_4, R.id.dashboard_row_5, R.id.dashboard_row_6,
        )
        private val STATUS_IDS = intArrayOf(
            R.id.dashboard_status_1, R.id.dashboard_status_2, R.id.dashboard_status_3,
            R.id.dashboard_status_4, R.id.dashboard_status_5, R.id.dashboard_status_6,
        )
        private val NAME_IDS = intArrayOf(
            R.id.dashboard_name_1, R.id.dashboard_name_2, R.id.dashboard_name_3,
            R.id.dashboard_name_4, R.id.dashboard_name_5, R.id.dashboard_name_6,
        )
        private val STREAK_IDS = intArrayOf(
            R.id.dashboard_streak_1, R.id.dashboard_streak_2, R.id.dashboard_streak_3,
            R.id.dashboard_streak_4, R.id.dashboard_streak_5, R.id.dashboard_streak_6,
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload = WidgetPayloadReader.habitDashboard(widgetData)

        appWidgetIds.forEach { widgetId ->
            val views = if (payload?.isPro == true) {
                buildUnlockedViews(context, payload.rows.take(MAX_ROWS))
            } else {
                buildLockedViews(context)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun buildLockedViews(context: Context): RemoteViews {
        return RemoteViews(context.packageName, R.layout.widget_habit_dashboard_locked).apply {
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("tide://widget/dashboard-locked"),
            )
            setOnClickPendingIntent(R.id.dashboard_locked_container, pendingIntent)
        }
    }

    private fun buildUnlockedViews(
        context: Context,
        rows: List<WidgetPayloadReader.DashboardRow>,
    ): RemoteViews {
        return RemoteViews(context.packageName, R.layout.widget_habit_dashboard).apply {
            setViewVisibility(R.id.dashboard_empty_state, if (rows.isEmpty()) View.VISIBLE else View.GONE)

            val openDashboard = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("tide://widget/dashboard"),
            )
            setOnClickPendingIntent(R.id.dashboard_container, openDashboard)

            for (i in ROW_IDS.indices) {
                if (i >= rows.size) {
                    setViewVisibility(ROW_IDS[i], View.GONE)
                    continue
                }
                val row = rows[i]
                setViewVisibility(ROW_IDS[i], View.VISIBLE)
                setTextViewText(NAME_IDS[i], row.name)
                setTextViewText(STREAK_IDS[i], row.streak.toString())
                setImageViewResource(
                    STATUS_IDS[i],
                    if (row.doneToday) R.drawable.widget_status_done else R.drawable.widget_status_due,
                )
            }
        }
    }
}
