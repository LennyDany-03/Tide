package com.example.tide

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
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
            val views = RemoteViews(context.packageName, R.layout.widget_quick_add).apply {
                setOnClickPendingIntent(R.id.quick_add_container, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
