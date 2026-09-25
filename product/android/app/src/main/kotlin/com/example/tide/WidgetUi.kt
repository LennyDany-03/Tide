package com.example.tide

import android.app.ActivityOptions
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Shared drawing decisions for every Tide home-screen widget.
 *
 * The Dart side mirrors the `tide_signed_in` key so a widget placed before
 * the next Flutter sync still draws the setup prompt rather than a habit it
 * has nothing to show for.
 */
object WidgetUi {
    const val KEY_SIGNED_IN = "tide_signed_in"

    data class Size(val widthDp: Int, val heightDp: Int)

    fun signedIn(data: SharedPreferences): Boolean = data.getBoolean(KEY_SIGNED_IN, false)

    /**
     * The widget's current size in dp. Launchers report a range: portrait
     * uses the min width and max height, landscape the max width and min
     * height. Falls back to the given size before the launcher has said.
     */
    fun size(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        fallbackWidthDp: Int,
        fallbackHeightDp: Int,
    ): Size {
        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        val landscape =
            context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        val width = options.getInt(
            if (landscape) AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH else AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,
            0,
        )
        val height = options.getInt(
            if (landscape) AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT else AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT,
            0,
        )
        return Size(
            if (width > 0) width else fallbackWidthDp,
            if (height > 0) height else fallbackHeightDp,
        )
    }

    /**
     * Points a scrolling list at [WidgetListService] for [kind], with the
     * tap template every row's fill-in intent completes, and shows
     * [emptyViewId] while the list has no rows.
     *
     * The adapter intent's data is made unique per widget and kind, or the
     * system hands every list the first factory it built.
     */
    @Suppress("DEPRECATION")
    fun bindList(
        context: Context,
        views: RemoteViews,
        listViewId: Int,
        emptyViewId: Int,
        widgetId: Int,
        kind: String,
    ) {
        val adapter = Intent(context, WidgetListService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            putExtra(WidgetListService.EXTRA_KIND, kind)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(listViewId, adapter)
        views.setEmptyView(listViewId, emptyViewId)

        // Mutable on purpose: a row's fill-in intent has to be able to set
        // the data URI on this template. Nothing else about it can change.
        val template = Intent(context, MainActivity::class.java).apply {
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 31) {
            flags = flags or PendingIntent.FLAG_MUTABLE
        }
        views.setPendingIntentTemplate(
            listViewId,
            activity(context, "list:$kind:$widgetId".hashCode(), template, flags),
        )
    }

    /** Re-reads a bound list's rows after the provider has redrawn. */
    @Suppress("DEPRECATION")
    fun refreshList(appWidgetManager: AppWidgetManager, widgetId: Int, listViewId: Int) {
        appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, listViewId)
    }

    /** A lit flame for a running streak, an unlit one for zero. */
    fun flame(context: Context, streak: Int): Int = WidgetTheme.drawable(
        context,
        if (streak > 0) R.drawable.ic_widget_flame else R.drawable.ic_widget_flame_out,
    )

    fun setupUri(kind: String, widgetId: Int): Uri =
        Uri.parse("tide://widget/setup?id=$widgetId&kind=$kind")


    fun habitUri(id: String, type: String): Uri {
        val host = if (type == "binary") "habit" else "habit-detail"
        return Uri.parse("tide://widget/$host?id=$id")
    }

    /**
     * [requestCode] must differ per tap target: Android matches PendingIntents
     * by action+data, but several widgets used requestCode 0 and
     * FLAG_UPDATE_CURRENT, so the last widget drawn stole every earlier tap.
     */
    fun click(
        context: Context,
        views: RemoteViews,
        viewId: Int,
        uri: Uri,
        requestCode: Int = uri.hashCode(),
    ) {
        val intent = Intent(context, MainActivity::class.java).apply {
            data = uri
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        views.setOnClickPendingIntent(viewId, activity(context, requestCode, intent, flags))
    }

    private fun activity(context: Context, requestCode: Int, intent: Intent, flags: Int): PendingIntent {
        if (Build.VERSION.SDK_INT < 34) {
            return PendingIntent.getActivity(context, requestCode, intent, flags)
        }
        val options = ActivityOptions.makeBasic()
        if (Build.VERSION.SDK_INT >= 35) {
            options.setPendingIntentCreatorBackgroundActivityStartMode(
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED,
            )
        } else {
            options.pendingIntentBackgroundActivityStartMode =
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
        }
        return PendingIntent.getActivity(context, requestCode, intent, flags, options.toBundle())
    }

    /**
     * A Weekly Recap day-strip cell: [value] is that day's share kept (-1
     * nothing asked), or null for a day still to come.
     */
    fun dayDrawable(context: Context, value: Double?, isToday: Boolean): Int =
        WidgetTheme.drawable(context, dayOriginal(value, isToday))

    private fun dayOriginal(value: Double?, isToday: Boolean): Int = when {
        value == null -> R.drawable.widget_day_future
        value < 0 -> R.drawable.widget_day_rest
        value >= 1.0 -> R.drawable.widget_day_4
        isToday -> R.drawable.widget_day_today
        value <= 0.0 -> R.drawable.widget_day_empty
        value < 0.34 -> R.drawable.widget_day_1
        value < 0.67 -> R.drawable.widget_day_2
        else -> R.drawable.widget_day_3
    }

    fun weekDrawable(context: Context, code: Int): Int =
        WidgetTheme.drawable(context, weekOriginal(code))

    private fun weekOriginal(code: Int): Int = when (code) {
        2 -> R.drawable.widget_week_kept
        1 -> R.drawable.widget_week_missed
        3 -> R.drawable.widget_week_today
        else -> R.drawable.widget_week_rest
    }
}
