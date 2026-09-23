package com.example.tide

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews

class SingleHabitStreakWidgetProvider : TideHomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val payload = WidgetPayloadReader.singleHabitStreak(widgetData, widgetId)
            val configured = payload?.configured == true
            val views = RemoteViews(context.packageName, WidgetTheme.layout(context, R.layout.widget_single_habit_streak))

            views.setViewVisibility(R.id.streak_content, if (configured) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.streak_unconfigured, if (configured) View.GONE else View.VISIBLE)
            views.setViewVisibility(
                R.id.streak_done,
                if (configured && payload.doneToday) View.VISIBLE else View.GONE,
            )

            if (configured) {
                views.setImageViewResource(R.id.streak_flame, WidgetUi.flame(context, payload.streak))
                views.setTextViewText(R.id.streak_number, payload.streak.toString())
                views.setTextViewText(R.id.streak_name, payload.name)
                WidgetUi.click(
                    context,
                    views,
                    R.id.streak_container,
                    WidgetUi.habitUri(payload.id ?: "", payload.type),
                )
                WidgetUi.click(
                    context,
                    views,
                    R.id.streak_name,
                    WidgetUi.setupUri("streak", widgetId),
                )
            } else {
                val setup = WidgetUi.setupUri("streak", widgetId)
                WidgetUi.click(context, views, R.id.streak_container, setup, widgetId)
                WidgetUi.click(context, views, R.id.streak_unconfigured, setup, widgetId + 1)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
