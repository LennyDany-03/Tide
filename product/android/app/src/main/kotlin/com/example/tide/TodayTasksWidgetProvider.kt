package com.example.tide

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews

class TodayTasksWidgetProvider : TideHomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload = WidgetPayloadReader.todayTasks(widgetData)
        val signedIn = payload?.signedIn == true
        val overdue = payload?.overdue ?: 0
        val total = payload?.total ?: 0

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, WidgetTheme.layout(context, R.layout.widget_today_tasks))

            views.setTextViewText(
                R.id.tasks_meta,
                when {
                    !signedIn || total == 0 -> ""
                    total == 1 -> context.getString(R.string.widget_one_due)
                    else -> context.getString(R.string.widget_n_due, total)
                },
            )
            views.setViewVisibility(
                R.id.tasks_overdue,
                if (signedIn && overdue > 0) View.VISIBLE else View.GONE,
            )
            views.setTextViewText(
                R.id.tasks_overdue,
                if (overdue == 1) {
                    context.getString(R.string.widget_one_overdue)
                } else {
                    context.getString(R.string.widget_n_overdue, overdue)
                },
            )
            views.setTextViewText(
                R.id.tasks_empty_state,
                context.getString(
                    if (signedIn) R.string.widget_tasks_empty else R.string.widget_open_tide,
                ),
            )

            WidgetUi.bindList(
                context,
                views,
                R.id.tasks_list,
                R.id.tasks_empty_state,
                widgetId,
                WidgetListService.KIND_TASKS,
            )
            WidgetUi.click(
                context,
                views,
                R.id.tasks_container,
                android.net.Uri.parse("tide://widget/tasks"),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
            WidgetUi.refreshList(appWidgetManager, widgetId, R.id.tasks_list)
        }
    }
}
