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
 * Free widget: one pinned habit's name and current streak (picked in the
 * app's Settings → Home screen widgets, not through a native configure
 * activity — see `DeviceFlags.streakWidgetHabitId` on the Dart side). Tap
 * opens the same `habit`/`habit-detail` deep link Today's Habits rows use;
 * with nothing pinned yet, it opens the widget gallery to pin one.
 */
class SingleHabitStreakWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload = WidgetPayloadReader.singleHabitStreak(widgetData)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_single_habit_streak).apply {
                if (payload?.configured == true) {
                    setViewVisibility(R.id.streak_content, View.VISIBLE)
                    setViewVisibility(R.id.streak_unconfigured, View.GONE)
                    setTextViewText(R.id.streak_number, payload.streak.toString())
                    setTextViewText(R.id.streak_name, payload.name)
                    setImageViewResource(
                        R.id.streak_status,
                        if (payload.doneToday) R.drawable.widget_status_done else R.drawable.widget_status_due,
                    )
                    val host = if (payload.type == "binary") "habit" else "habit-detail"
                    setOnClickPendingIntent(
                        R.id.streak_container,
                        HomeWidgetLaunchIntent.getActivity(
                            context,
                            MainActivity::class.java,
                            Uri.parse("tide://widget/$host?id=${payload.id}"),
                        ),
                    )
                } else {
                    setViewVisibility(R.id.streak_content, View.GONE)
                    setViewVisibility(R.id.streak_unconfigured, View.VISIBLE)
                    setOnClickPendingIntent(
                        R.id.streak_container,
                        HomeWidgetLaunchIntent.getActivity(
                            context,
                            MainActivity::class.java,
                            Uri.parse("tide://widget/streak-unconfigured"),
                        ),
                    )
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
