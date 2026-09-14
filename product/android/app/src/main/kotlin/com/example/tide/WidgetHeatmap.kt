package com.example.tide

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

/**
 * Draws the Habit Heatmap grid natively, at the exact size the launcher gave
 * the widget, so the cells fill the card edge to edge at any resize.
 *
 * It used to be a fixed 26-week PNG rendered off-screen by Flutter: on a
 * normal 4×2 widget that left tiny cells floating in the middle of the card,
 * and a habit started this week was a field of near-invisible squares. Here
 * the row height sets the cell size, the width decides how many weeks fit,
 * and the newest week is always the right-hand column.
 *
 * Columns are Monday-to-Sunday weeks; [series] (from
 * `WidgetPayload.heatmapSeries`) is one value per day ending today — -1 for
 * a day nothing was asked, 0..1 for how much was kept.
 */
object WidgetHeatmap {
    private const val ROWS = 7

    /** Gap and corner radius, as fractions of a cell. */
    private const val GAP = 0.22f
    private const val RADIUS = 0.26f

    /** Past this a wider widget shows more weeks, not bigger cells. */
    private const val MAX_CELL_DP = 26f

    /** How far a cell may stretch sideways to fill the width exactly. */
    private const val MAX_STRETCH = 1.12f

    private const val MAX_BITMAP_PX = 1600f

    /** Weeks drawn when there is no series yet: an empty grid, not a blank. */
    private const val EMPTY_WEEKS = 26

    fun render(context: Context, series: DoubleArray, widthDp: Int, heightDp: Int): Bitmap? {
        if (widthDp <= 0 || heightDp <= 0) return null
        val density = context.resources.displayMetrics.density
        val scale = min(1f, MAX_BITMAP_PX / (max(widthDp, heightDp) * density))
        val unit = density * scale
        val width = widthDp * unit
        val height = heightDp * unit

        val today = series.size - 1
        val totalWeeks = if (series.isEmpty()) EMPTY_WEEKS else (series.size + 6) / 7

        val cellH = min(height / (ROWS + (ROWS - 1) * GAP), MAX_CELL_DP * unit)
        val gap = cellH * GAP
        val columns = floor((width + gap) / (cellH + gap)).toInt().coerceIn(1, totalWeeks)
        val cellW = min((width - (columns - 1) * gap) / columns, cellH * MAX_STRETCH)

        val gridW = columns * cellW + (columns - 1) * gap
        val gridH = ROWS * cellH + (ROWS - 1) * gap
        val left = (width - gridW) / 2
        val top = (height - gridH) / 2
        val radius = min(cellW, cellH) * RADIUS

        val bitmap = Bitmap.createBitmap(
            width.toInt().coerceAtLeast(1),
            height.toInt().coerceAtLeast(1),
            Bitmap.Config.ARGB_8888,
        )
        val canvas = Canvas(bitmap)
        val fill = Paint(Paint.ANTI_ALIAS_FLAG)
        val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = max(1.2f * unit, cellH * 0.12f)
            color = context.getColor(R.color.tide_lantern)
        }
        val tiers = intArrayOf(
            context.getColor(R.color.tide_cell_rest),
            context.getColor(R.color.tide_cell_empty),
            context.getColor(R.color.tide_cell_1),
            context.getColor(R.color.tide_cell_2),
            context.getColor(R.color.tide_cell_3),
            context.getColor(R.color.tide_cell_4),
        )
        val rect = RectF()

        val firstWeek = totalWeeks - columns
        for (col in 0 until columns) {
            for (row in 0 until ROWS) {
                val index = (firstWeek + col) * 7 + row
                val x = left + col * (cellW + gap)
                val y = top + row * (cellH + gap)
                rect.set(x, y, x + cellW, y + cellH)

                if (index > today) {
                    // The rest of this week: there, but not yet anything.
                    fill.color = tiers[0]
                    fill.alpha = 110
                    canvas.drawRoundRect(rect, radius, radius, fill)
                    fill.alpha = 255
                    continue
                }

                val value = series[index]
                fill.color = tiers[tier(value)]
                canvas.drawRoundRect(rect, radius, radius, fill)

                if (index == today && value in 0.0..0.999) {
                    val inset = ring.strokeWidth / 2
                    rect.inset(inset, inset)
                    canvas.drawRoundRect(rect, radius - inset, radius - inset, ring)
                }
            }
        }
        return bitmap
    }

    /** 0 rest, 1 missed, 2..5 kept from a little to all of it. */
    private fun tier(value: Double): Int = when {
        value < 0 -> 0
        value <= 0.0 -> 1
        value < 0.34 -> 2
        value < 0.67 -> 3
        value < 1.0 -> 4
        else -> 5
    }
}
