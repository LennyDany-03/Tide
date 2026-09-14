package com.example.tide

import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

object LockedWidgetViews {
    fun build(context: Context, titleResId: Int, deepLinkUri: String): RemoteViews {
        return RemoteViews(context.packageName, R.layout.widget_locked).apply {
            setTextViewText(R.id.locked_title, context.getString(titleResId))
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse(deepLinkUri),
            )
            setOnClickPendingIntent(R.id.locked_container, pendingIntent)
        }
    }
}
