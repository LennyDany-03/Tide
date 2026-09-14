package com.example.tide

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews

class WeeklyRecapWidgetProvider : TideHomeWidgetProvider() {
    private val dayIds = intArrayOf(
        R.id.recap_day_1, R.id.recap_day_2, R.id.recap_day_3, R.id.recap_day_4,
        R.id.recap_day_5, R.id.recap_day_6, R.id.recap_day_7,
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload = WidgetPayloadReader.weeklyRecap(widgetData)

        appWidgetIds.forEach { widgetId ->
            if (payload?.isPro != true) {
                appWidgetManager.updateAppWidget(
                    widgetId,
                    LockedWidgetViews.build(
                        context,
                        R.string.widget_recap_title,
                        WidgetUi.upgradeUri().toString(),
                    ),
                )
                return@forEach
            }

            val views = RemoteViews(context.packageName, R.layout.widget_weekly_recap)
            val delta = payload.weekPercent - payload.lastWeekPercent
            val up = delta >= 0

            views.setTextViewText(R.id.recap_range, payload.range)
            views.setTextViewText(R.id.recap_percent, "${payload.weekPercent}%")
            views.setProgressBar(R.id.recap_progress, 100, payload.weekPercent.coerceIn(0, 100), false)
            views.setTextViewText(R.id.recap_streak, payload.bestStreak.toString())
            views.setTextViewText(R.id.recap_checks, "${payload.checkIns}/${payload.scheduled}")

            views.setTextViewText(R.id.recap_delta, if (up) "+$delta%" else "$delta%")
            views.setTextColor(
                R.id.recap_delta,
                context.getColor(if (up) R.color.tide_lantern else R.color.tide_coral),
            )
            views.setImageViewResource(
                R.id.recap_delta_icon,
                if (up) R.drawable.ic_widget_trend else R.drawable.ic_widget_trend_down,
            )
            views.setInt(
                R.id.recap_delta_pill,
                "setBackgroundResource",
                if (up) R.drawable.widget_pill_lantern else R.drawable.widget_pill_coral,
            )

            // Short widgets drop the day strip before squeezing the ring.
            val size = WidgetUi.size(context, appWidgetManager, widgetId, 250, 180)
            val showDays = size.heightDp >= DAYS_MIN_HEIGHT_DP
            views.setViewVisibility(R.id.recap_days, if (showDays) View.VISIBLE else View.GONE)
            val today = payload.days.size - 1
            for (i in dayIds.indices) {
                views.setImageViewResource(
                    dayIds[i],
                    WidgetUi.dayDrawable(payload.days.getOrNull(i), isToday = i == today),
                )
            }

            WidgetUi.click(
                context,
                views,
                R.id.recap_container,
                android.net.Uri.parse("tide://widget/insights"),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private companion object {
        const val DAYS_MIN_HEIGHT_DP = 160
    }
}
