package com.example.tide

import android.appwidget.AppWidgetManager
import android.content.Context
import android.os.Bundle
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Redraws on resize. List widgets hide rows that no longer fit, and the
 * heatmap image scales with the cell count the launcher just assigned —
 * without this, a drag-to-resize would keep the old layout until the next
 * 30-minute update.
 */
abstract class TideHomeWidgetProvider : HomeWidgetProvider() {
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }
}
