package com.example.tide

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Pro widget: this week's completion rate and the longest streak currently
 * running. Locked exactly like [HabitDashboardWidgetProvider]; unlocked, a
 * tap opens Insights, where both figures come from.
 */
class WeeklyRecapWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload = WidgetPayloadReader.weeklyRecap(widgetData)

        appWidgetIds.forEach { widgetId ->
            val views = if (payload?.isPro == true) {
                RemoteViews(context.packageName, R.layout.widget_weekly_recap).apply {
                    setTextViewText(R.id.recap_percent, "${payload.weekPercent}%")
                    setTextViewText(R.id.recap_streak, payload.bestStreak.toString())
                    setOnClickPendingIntent(
                        R.id.recap_container,
                        HomeWidgetLaunchIntent.getActivity(
                            context,
                            MainActivity::class.java,
                            Uri.parse("tide://widget/insights"),
                        ),
                    )
                }
            } else {
                LockedWidgetViews.build(
                    context,
                    R.string.widget_recap_title,
                    "tide://widget/recap-locked",
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
