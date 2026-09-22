package com.example.tide

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews

class HabitHeatmapWidgetProvider : TideHomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val header = WidgetPayloadReader.heatmapHeader(widgetData, widgetId)
            val configured = header?.configured == true
            val views = RemoteViews(context.packageName, R.layout.widget_habit_heatmap)

            // A 4×1 widget has no room for the name: the grid gets it all.
            val size = WidgetUi.size(context, appWidgetManager, widgetId, 250, 140)
            val showHeader = !configured || size.heightDp >= HEADER_MIN_HEIGHT_DP
            views.setViewVisibility(R.id.heatmap_header, if (showHeader) View.VISIBLE else View.GONE)

            views.setTextViewText(
                R.id.heatmap_title,
                if (configured) header.name else context.getString(R.string.widget_heatmap_title),
            )
            views.setTextViewText(
                R.id.heatmap_streak,
                if (configured) header.streak.toString() else "",
            )
            views.setViewVisibility(
                R.id.heatmap_flame,
                if (configured) View.VISIBLE else View.GONE,
            )
            if (configured) {
                views.setImageViewResource(R.id.heatmap_flame, WidgetUi.flame(header.streak))
            }

            val bitmap = if (configured) {
                runCatching {
                    WidgetHeatmap.render(
                        context,
                        header.series,
                        size.widthDp - PADDING_H_DP,
                        size.heightDp - PADDING_V_DP - (if (showHeader) HEADER_DP else 0),
                    )
                }.getOrNull()
            } else {
                null
            }

            if (bitmap != null) {
                views.setViewVisibility(R.id.heatmap_image, View.VISIBLE)
                views.setViewVisibility(R.id.heatmap_empty_state, View.GONE)
                views.setImageViewBitmap(R.id.heatmap_image, bitmap)
            } else {
                views.setViewVisibility(R.id.heatmap_image, View.GONE)
                views.setViewVisibility(R.id.heatmap_empty_state, View.VISIBLE)
            }

            val setupTap = WidgetUi.setupUri("heatmap", widgetId)
            val habitTap = if (configured && header.id != null) {
                WidgetUi.habitUri(header.id, header.type)
            } else {
                setupTap
            }
            WidgetUi.click(context, views, R.id.heatmap_header, setupTap)
            WidgetUi.click(context, views, R.id.heatmap_image, habitTap)
            WidgetUi.click(context, views, R.id.heatmap_empty_state, setupTap)
            WidgetUi.click(context, views, R.id.heatmap_container, habitTap)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private companion object {
        /** widget_habit_heatmap.xml's padding, both sides. */
        const val PADDING_H_DP = 28
        const val PADDING_V_DP = 24

        /** The header row plus the gap under it. */
        const val HEADER_DP = 26

        const val HEADER_MIN_HEIGHT_DP = 100
    }
}
