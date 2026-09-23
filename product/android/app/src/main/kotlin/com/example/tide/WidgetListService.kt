package com.example.tide

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService

/**
 * Rows for the scrolling list widgets — Today, Tasks and Streaks.
 *
 * Every row the payload carries is reachable by scrolling, so a widget no
 * longer has to guess how many fit and hide the rest behind "+N more". The
 * provider binds the list and calls `notifyAppWidgetViewDataChanged` on each
 * update; [Factory.onDataSetChanged] then re-reads the same JSON the provider
 * drew its header from.
 *
 * Row taps use the list's PendingIntent template (see [WidgetUi.bindList])
 * with a fill-in intent carrying only the row's `tide://widget/…` URI.
 */
class WidgetListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        Factory(applicationContext, intent.getStringExtra(EXTRA_KIND).orEmpty())

    private class Factory(
        private val context: Context,
        private val kind: String,
    ) : RemoteViewsFactory {
        private var today: List<WidgetPayloadReader.TodayRow> = emptyList()
        private var tasks: List<WidgetPayloadReader.TaskRow> = emptyList()
        private var streaks: List<WidgetPayloadReader.DashboardRow> = emptyList()

        private val weekIds = intArrayOf(
            R.id.dashboard_d1, R.id.dashboard_d2, R.id.dashboard_d3,
            R.id.dashboard_d4, R.id.dashboard_d5, R.id.dashboard_d6, R.id.dashboard_d7,
        )

        override fun onCreate() = Unit

        override fun onDataSetChanged() {
            val data = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            when (kind) {
                KIND_TODAY -> today = WidgetPayloadReader.todayHabits(data)
                    ?.takeIf { it.signedIn }?.rows.orEmpty()
                KIND_TASKS -> tasks = WidgetPayloadReader.todayTasks(data)
                    ?.takeIf { it.signedIn }?.rows.orEmpty()
                KIND_STREAKS -> streaks = WidgetPayloadReader.habitDashboard(data)
                    ?.takeIf { it.signedIn }?.rows.orEmpty()
            }
        }

        override fun onDestroy() = Unit

        override fun getCount(): Int = when (kind) {
            KIND_TODAY -> today.size
            KIND_TASKS -> tasks.size
            KIND_STREAKS -> streaks.size
            else -> 0
        }

        override fun getViewAt(position: Int): RemoteViews? = when (kind) {
            KIND_TODAY -> today.getOrNull(position)?.let(::todayRow)
            KIND_TASKS -> tasks.getOrNull(position)?.let(::taskRow)
            KIND_STREAKS -> streaks.getOrNull(position)?.let(::streakRow)
            else -> null
        }

        private fun todayRow(row: WidgetPayloadReader.TodayRow) =
            RemoteViews(context.packageName, WidgetTheme.layout(context, R.layout.widget_today_row)).apply {
                setTextViewText(R.id.today_name, row.name)
                setTextColor(
                    R.id.today_name,
                    WidgetTheme.color(context, if (row.done) R.color.tide_silt else R.color.tide_bone),
                )
                setImageViewResource(
                    R.id.today_status,
                    WidgetTheme.drawable(context, if (row.done) R.drawable.widget_check_done else R.drawable.widget_check_open),
                )
                setImageViewResource(R.id.today_flame, WidgetUi.flame(context, row.streak))
                setTextViewText(R.id.today_streak, row.streak.toString())
                setTextColor(
                    R.id.today_streak,
                    WidgetTheme.color(context, if (row.streak > 0) R.color.tide_bone else R.color.tide_silt),
                )
                fillIn(this, R.id.today_row, WidgetUi.habitUri(row.id, row.type))
            }

        private fun taskRow(row: WidgetPayloadReader.TaskRow) =
            RemoteViews(context.packageName, WidgetTheme.layout(context, R.layout.widget_task_row)).apply {
                setTextViewText(R.id.tasks_title, row.title)
                setTextViewText(R.id.tasks_due, row.due)
                setImageViewResource(
                    R.id.tasks_status,
                    WidgetTheme.drawable(context, if (row.overdue) R.drawable.widget_check_overdue else R.drawable.widget_check_open),
                )
                setTextColor(
                    R.id.tasks_due,
                    WidgetTheme.color(context, if (row.overdue) R.color.tide_coral else R.color.tide_silt),
                )
                setInt(
                    R.id.tasks_due,
                    "setBackgroundResource",
                    WidgetTheme.drawable(context, if (row.overdue) R.drawable.widget_pill_coral else R.drawable.widget_pill),
                )
                fillIn(this, R.id.tasks_row, Uri.parse("tide://widget/task?id=${row.id}"))
            }

        private fun streakRow(row: WidgetPayloadReader.DashboardRow) =
            RemoteViews(context.packageName, WidgetTheme.layout(context, R.layout.widget_dashboard_row)).apply {
                setTextViewText(R.id.dashboard_name, row.name)
                setTextViewText(R.id.dashboard_streak, row.streak.toString())
                setTextColor(
                    R.id.dashboard_streak,
                    WidgetTheme.color(context, if (row.streak > 0) R.color.tide_bone else R.color.tide_silt),
                )
                setImageViewResource(R.id.dashboard_flame, WidgetUi.flame(context, row.streak))
                for (i in weekIds.indices) {
                    setImageViewResource(weekIds[i], WidgetUi.weekDrawable(context, row.week.getOrElse(i) { 0 }))
                }
                fillIn(this, R.id.dashboard_row, WidgetUi.habitUri(row.id, "binary"))
            }

        private fun fillIn(views: RemoteViews, viewId: Int, uri: Uri) {
            views.setOnClickFillInIntent(viewId, Intent().setData(uri))
        }

        override fun getLoadingView(): RemoteViews =
            RemoteViews(context.packageName, WidgetTheme.layout(context, R.layout.widget_list_loading))

        override fun getViewTypeCount(): Int = 1

        override fun getItemId(position: Int): Long = position.toLong()

        override fun hasStableIds(): Boolean = false
    }

    companion object {
        const val EXTRA_KIND = "com.example.tide.widget.LIST_KIND"
        const val KIND_TODAY = "today"
        const val KIND_TASKS = "tasks"
        const val KIND_STREAKS = "streaks"

        /** HomeWidgetPlugin.PREFERENCES, which the plugin keeps internal. */
        private const val PREFERENCES = "HomeWidgetPreferences"
    }
}
