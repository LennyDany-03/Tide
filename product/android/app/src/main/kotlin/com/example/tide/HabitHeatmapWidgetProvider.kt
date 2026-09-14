package com.example.tide

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Pro widget: the pinned habit's last five weeks, as a rendered image (see
 * `HeatmapExport`/`HomeWidgetBridge._writeHabits` on the Dart side — this
 * provider only decodes the PNG path and shows it, RemoteViews never draws
 * the grid itself). Locked exactly like [HabitDashboardWidgetProvider]; a
 * third state — Pro, but no habit pinned yet — reuses the unlocked layout's
 * own empty state rather than a fourth tree.
 */
class HabitHeatmapWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val meta = WidgetPayloadReader.heatmapMeta(widgetData)

        appWidgetIds.forEach { widgetId ->
            val views = if (meta?.isPro == true) {
                buildUnlockedViews(context, widgetData, meta.configured)
            } else {
                LockedWidgetViews.build(
                    context,
                    R.string.widget_heatmap_title,
                    "tide://widget/heatmap-locked",
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun buildUnlockedViews(
        context: Context,
        widgetData: SharedPreferences,
        configured: Boolean,
    ): RemoteViews {
        return RemoteViews(context.packageName, R.layout.widget_habit_heatmap).apply {
            val openIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse(if (configured) "tide://widget/heatmap" else "tide://widget/streak-unconfigured"),
            )
            setOnClickPendingIntent(R.id.heatmap_container, openIntent)

            val imagePath = if (configured) WidgetPayloadReader.heatmapImagePath(widgetData) else null
            val bitmap = imagePath?.let { runCatching { BitmapFactory.decodeFile(it) }.getOrNull() }

            setTextViewText(R.id.heatmap_title, context.getString(R.string.widget_heatmap_title))
            if (bitmap != null) {
                setViewVisibility(R.id.heatmap_image, View.VISIBLE)
                setViewVisibility(R.id.heatmap_empty_state, View.GONE)
                setImageViewBitmap(R.id.heatmap_image, bitmap)
            } else {
                setViewVisibility(R.id.heatmap_image, View.GONE)
                setViewVisibility(R.id.heatmap_empty_state, View.VISIBLE)
            }
        }
    }
}
