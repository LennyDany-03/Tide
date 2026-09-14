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
 * Free widget: up to [MAX_ROWS] of today's due habits. Tapping a binary row
 * logs it and lands on Today; a quantity/duration row can't be logged from a
 * tap alone (there's no amount to guess), so it opens that habit's detail
 * instead — see `_openFromWidget` in lib/main.dart for the other half of
 * both of those deep links.
 */
class TodayHabitsWidgetProvider : HomeWidgetProvider() {
    companion object {
        const val MAX_ROWS = 5
        private val ROW_IDS =
            intArrayOf(R.id.today_row_1, R.id.today_row_2, R.id.today_row_3, R.id.today_row_4, R.id.today_row_5)
        private val STATUS_IDS = intArrayOf(
            R.id.today_status_1, R.id.today_status_2, R.id.today_status_3,
            R.id.today_status_4, R.id.today_status_5,
        )
        private val NAME_IDS = intArrayOf(
            R.id.today_name_1, R.id.today_name_2, R.id.today_name_3,
            R.id.today_name_4, R.id.today_name_5,
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload = WidgetPayloadReader.todayHabits(widgetData)
        val rows = payload?.rows.orEmpty().take(MAX_ROWS)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_today_habits).apply {
                setViewVisibility(R.id.today_empty_state, if (rows.isEmpty()) View.VISIBLE else View.GONE)

                for (i in ROW_IDS.indices) {
                    if (i >= rows.size) {
                        setViewVisibility(ROW_IDS[i], View.GONE)
                        continue
                    }
                    val row = rows[i]
                    setViewVisibility(ROW_IDS[i], View.VISIBLE)
                    setTextViewText(NAME_IDS[i], row.name)
                    setImageViewResource(
                        STATUS_IDS[i],
                        if (row.done) R.drawable.widget_status_done else R.drawable.widget_status_due,
                    )
                    val host = if (row.type == "binary") "habit" else "habit-detail"
                    val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("tide://widget/$host?id=${row.id}"),
                    )
                    setOnClickPendingIntent(ROW_IDS[i], pendingIntent)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
