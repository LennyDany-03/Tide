package com.example.tide

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews

class TodayHabitsWidgetProvider : TideHomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload = WidgetPayloadReader.todayHabits(widgetData)
        val signedIn = payload?.signedIn == true
        val done = payload?.done ?: 0
        val total = payload?.total ?: 0
        val percent = if (total > 0) done * 100 / total else 0

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_today_habits)

            views.setTextViewText(
                R.id.today_meta,
                when {
                    !signedIn || total == 0 -> ""
                    done >= total -> context.getString(R.string.widget_all_done, total)
                    else -> context.getString(R.string.widget_done_of, done, total)
                },
            )
            views.setProgressBar(R.id.today_progress, 100, percent, false)
            views.setTextViewText(R.id.today_percent, if (signedIn && total > 0) "$percent%" else "–")
            views.setTextViewText(
                R.id.today_empty_state,
                context.getString(
                    if (signedIn) R.string.widget_nothing_due else R.string.widget_open_tide,
                ),
            )

            WidgetUi.bindList(
                context,
                views,
                R.id.today_list,
                R.id.today_empty_state,
                widgetId,
                WidgetListService.KIND_TODAY,
            )
            WidgetUi.click(
                context,
                views,
                R.id.today_container,
                android.net.Uri.parse("tide://widget/today"),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
            WidgetUi.refreshList(appWidgetManager, widgetId, R.id.today_list)
        }
    }
}
