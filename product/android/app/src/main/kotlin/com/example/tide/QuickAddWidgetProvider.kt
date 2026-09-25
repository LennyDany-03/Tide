package com.example.tide

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Free widget: a single static "+" tap target, straight into "new habit" —
 * see `_openFromWidget`'s `quick-add` case in lib/main.dart, which also
 * decides there whether that lands on the sheet or the paywall
 * ([TideStore.canAddHabit]). Plain [AppWidgetProvider] rather than
 * [HomeWidgetProvider]: there is no widget data to read at all.
 */
class QuickAddWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val pendingIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("tide://widget/quick-add"),
        )
        appWidgetIds.forEach { widgetId ->
            val wide = WidgetUi.size(context, appWidgetManager, widgetId, 70, 70).widthDp >= LABEL_MIN_WIDTH_DP
            val views = RemoteViews(context.packageName, WidgetTheme.layout(context, R.layout.widget_quick_add)).apply {
                setViewVisibility(R.id.quick_add_label, if (wide) View.VISIBLE else View.GONE)
                setOnClickPendingIntent(R.id.quick_add_container, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    /** Widened past one cell, the button gets its "New habit" label. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    private companion object {
        const val LABEL_MIN_WIDTH_DP = 150
    }
}
