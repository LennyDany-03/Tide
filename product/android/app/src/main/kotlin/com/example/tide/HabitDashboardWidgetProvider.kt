package com.example.tide

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews

class HabitDashboardWidgetProvider : TideHomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload = WidgetPayloadReader.habitDashboard(widgetData)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, WidgetTheme.layout(context, R.layout.widget_habit_dashboard))
            val alight = payload?.rows?.count { it.streak > 0 } ?: 0

            views.setTextViewText(
                R.id.dashboard_meta,
                when {
                    payload?.signedIn != true || payload.rows.isEmpty() -> ""
                    alight == 0 -> context.getString(R.string.widget_no_streaks)
                    else -> context.getString(R.string.widget_on_streak, alight)
                },
            )
            views.setTextViewText(R.id.dashboard_best, (payload?.best ?: 0).toString())
            views.setTextViewText(
                R.id.dashboard_empty_state,
                context.getString(
                    if (payload?.signedIn == true) {
                        R.string.widget_no_habits
                    } else {
                        R.string.widget_open_tide
                    },
                ),
            )

            WidgetUi.bindList(
                context,
                views,
                R.id.dashboard_list,
                R.id.dashboard_empty_state,
                widgetId,
                WidgetListService.KIND_STREAKS,
            )
            WidgetUi.click(
                context,
                views,
                R.id.dashboard_container,
                android.net.Uri.parse("tide://widget/dashboard"),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
            WidgetUi.refreshList(appWidgetManager, widgetId, R.id.dashboard_list)
        }
    }
}
