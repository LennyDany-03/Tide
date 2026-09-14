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
 * Free widget: up to [MAX_ROWS] of today's due-or-overdue tasks. Tapping a
 * row opens that task (see `_openTask` in lib/main.dart) rather than
 * completing it — v1 widgets are deep-link only, no native business logic.
 */
class TodayTasksWidgetProvider : HomeWidgetProvider() {
    companion object {
        const val MAX_ROWS = 5
        private val ROW_IDS =
            intArrayOf(R.id.tasks_row_1, R.id.tasks_row_2, R.id.tasks_row_3, R.id.tasks_row_4, R.id.tasks_row_5)
        private val STATUS_IDS = intArrayOf(
            R.id.tasks_status_1, R.id.tasks_status_2, R.id.tasks_status_3,
            R.id.tasks_status_4, R.id.tasks_status_5,
        )
        private val TITLE_IDS = intArrayOf(
            R.id.tasks_title_1, R.id.tasks_title_2, R.id.tasks_title_3,
            R.id.tasks_title_4, R.id.tasks_title_5,
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload = WidgetPayloadReader.todayTasks(widgetData)
        val rows = payload?.rows.orEmpty().take(MAX_ROWS)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_today_tasks).apply {
                setViewVisibility(R.id.tasks_empty_state, if (rows.isEmpty()) View.VISIBLE else View.GONE)

                for (i in ROW_IDS.indices) {
                    if (i >= rows.size) {
                        setViewVisibility(ROW_IDS[i], View.GONE)
                        continue
                    }
                    val row = rows[i]
                    setViewVisibility(ROW_IDS[i], View.VISIBLE)
                    setTextViewText(TITLE_IDS[i], row.title)
                    setImageViewResource(
                        STATUS_IDS[i],
                        if (row.overdue) R.drawable.widget_status_overdue else R.drawable.widget_status_due,
                    )
                    val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("tide://widget/task?id=${row.id}"),
                    )
                    setOnClickPendingIntent(ROW_IDS[i], pendingIntent)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
