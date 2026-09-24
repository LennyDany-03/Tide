package com.example.tide.reminders

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

/**
 * The pictures inside the reminder notifications, drawn from the palette
 * Dart sent (see [Look]) — the same water and the same light as the app,
 * since a notification layout cannot read the theme.
 *
 * Notifications cannot animate, so each picture is a moment: [progress] is
 * how far the countdown has run, 0 at the heads-up and 1 at the reminder
 * itself. The receiver redraws a heads-up once a minute, which is enough
 * for the water to be seen rising.
 */
object ReminderArt {
    /** Pixels per dp the pictures are drawn at. Enough for any screen. */
    private const val SCALE = 2.5f

    private fun alpha(color: Int, a: Float): Int =
        Color.argb((Color.alpha(color) * a).toInt().coerceIn(0, 255), Color.red(color), Color.green(color), Color.blue(color))

    private fun card(widthDp: Int, heightDp: Int, look: Look): Pair<Bitmap, Canvas> {
        val bitmap = Bitmap.createBitmap(
            (widthDp * SCALE).toInt(),
            (heightDp * SCALE).toInt(),
            Bitmap.Config.ARGB_8888,
        )
        val canvas = Canvas(bitmap)
        val rect = RectF(0f, 0f, bitmap.width.toFloat(), bitmap.height.toFloat())
        val radius = 14 * SCALE
        val ground = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            // Top to bottom, like every ramp in the app: night above, the
            // water's colour gathering below.
            shader = LinearGradient(
                0f, 0f, 0f, rect.height(),
                look.recess, look.ground, Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRoundRect(rect, radius, radius, ground)
        canvas.clipPath(Path().apply { addRoundRect(rect, radius, radius, Path.Direction.CW) })
        return bitmap to canvas
    }

    private fun surface(width: Float, baseline: Float, amplitude: Float, waves: Float, phase: Float): Path {
        val path = Path()
        path.moveTo(0f, baseline)
        val steps = 48
        for (i in 0..steps) {
            val u = i / steps.toFloat()
            val theta = u * 2 * PI * waves + phase
            val y = baseline + (sin(theta) * amplitude + sin(theta * 2.3 - phase * 0.7) * amplitude * 0.35).toFloat()
            path.lineTo(width * u, y)
        }
        return path
    }

    private fun body(surface: Path, width: Float, height: Float): Path =
        Path(surface).apply {
            lineTo(width, height)
            lineTo(0f, height)
            close()
        }

    // --- Rising Tide -----------------------------------------------------------

    /**
     * The collapsed heads-up's ground: a thin wave along the foot of the card
     * that fills from the left as the countdown runs.
     */
    fun risingTideStrip(look: Look, progress: Float, phase: Float): Bitmap {
        val (bitmap, canvas) = card(360, 56, look)
        val w = bitmap.width.toFloat()
        val h = bitmap.height.toFloat()
        val baseline = h - 7 * SCALE
        val wave = surface(w, baseline, 2.2f * SCALE, 5f, phase)
        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 2 * SCALE
            strokeCap = Paint.Cap.ROUND
            color = alpha(look.muted, 0.35f)
        }
        canvas.drawPath(wave, track)
        canvas.save()
        canvas.clipRect(0f, 0f, w * progress.coerceIn(0.02f, 1f), h)
        canvas.drawPath(wave, track.apply { color = look.accent; strokeWidth = 2.6f * SCALE })
        canvas.restore()
        return bitmap
    }

    /**
     * The expanded heads-up's ground: water standing at the foot of the card,
     * higher the nearer the habit is — the tide rising toward it.
     */
    fun risingTideCard(look: Look, progress: Float, phase: Float): Bitmap {
        val (bitmap, canvas) = card(360, 200, look)
        val w = bitmap.width.toFloat()
        val h = bitmap.height.toFloat()
        val level = 0.14f + 0.3f * progress.coerceIn(0f, 1f)
        val waterline = h * (1 - level)
        val layers = listOf(
            Triple(10 * SCALE, 0.10f, 1.1f),
            Triple(4 * SCALE, 0.14f, 1.7f),
            Triple(0f, 0.2f, 0.9f),
        )
        layers.forEachIndexed { index, (rise, a, waves) ->
            val line = surface(w, waterline - rise, (3 + index) * SCALE, waves, phase * (if (index % 2 == 0) 1f else -1f))
            val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                val light = if (look.light) 0.45f else 1f
                shader = LinearGradient(
                    0f, waterline - rise, 0f, h,
                    alpha(look.accent, a * light), alpha(look.accent, a * light * 0.4f),
                    Shader.TileMode.CLAMP,
                )
            }
            canvas.drawPath(body(line, w, h), fill)
            if (index == layers.lastIndex) {
                canvas.drawPath(line, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 1.6f * SCALE
                    color = alpha(look.accent, 0.8f)
                })
            }
        }
        return bitmap
    }

    // --- Beacon ----------------------------------------------------------------

    private fun beam(canvas: Canvas, look: Look, lampX: Float, lampY: Float, angle: Double, reach: Float, strength: Float) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = RadialGradient(
                lampX, lampY, reach,
                intArrayOf(alpha(look.accent, 0.34f * strength), alpha(look.accent, 0.1f * strength), alpha(look.accent, 0f)),
                floatArrayOf(0f, 0.45f, 1f),
                Shader.TileMode.CLAMP,
            )
        }
        for (spread in listOf(0.2, 0.12, 0.06)) {
            val path = Path().apply {
                moveTo(lampX, lampY)
                lineTo(lampX + (cos(angle - spread) * reach).toFloat(), lampY + (sin(angle - spread) * reach).toFloat())
                lineTo(lampX + (cos(angle + spread) * reach).toFloat(), lampY + (sin(angle + spread) * reach).toFloat())
                close()
            }
            canvas.drawPath(path, paint)
        }
        canvas.drawCircle(lampX, lampY, 3.2f * SCALE, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = look.flare })
    }

    /**
     * The Beacon's ground: a lamp low on the left, and its beam swinging down
     * from the sky toward the horizon as the to-do comes due.
     */
    fun beaconCard(look: Look, heightDp: Int, progress: Float): Bitmap {
        val (bitmap, canvas) = card(360, heightDp, look)
        val w = bitmap.width.toFloat()
        val h = bitmap.height.toFloat()
        val horizon = h * 0.82f
        canvas.drawRect(0f, horizon, w, h, Paint().apply { color = alpha(look.surface, 0.7f) })
        canvas.drawLine(0f, horizon, w, horizon, Paint().apply {
            color = alpha(look.ink, 0.1f)
            strokeWidth = SCALE
        })
        val angle = -1.1 + 1.05 * progress.coerceIn(0f, 1f)
        beam(canvas, look, w * 0.06f, horizon - 2 * SCALE, angle, w * 1.1f, 0.7f + 0.3f * progress)
        return bitmap
    }

    /** The lamp alone, lit, for a to-do's large icon. */
    fun beaconLamp(look: Look): Bitmap {
        val size = (48 * SCALE).toInt()
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val c = size / 2f
        canvas.drawCircle(c, c, c, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = RadialGradient(
                c, c, c,
                intArrayOf(alpha(look.accent, 0.5f), alpha(look.accent, 0.12f), alpha(look.accent, 0f)),
                floatArrayOf(0f, 0.5f, 1f),
                Shader.TileMode.CLAMP,
            )
        })
        val ray = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = alpha(look.accent, 0.8f)
            strokeWidth = 2 * SCALE
            strokeCap = Paint.Cap.ROUND
        }
        for (i in 0 until 8) {
            val a = i * PI / 4
            canvas.drawLine(
                c + (cos(a) * c * 0.45).toFloat(), c + (sin(a) * c * 0.45).toFloat(),
                c + (cos(a) * c * 0.72).toFloat(), c + (sin(a) * c * 0.72).toFloat(),
                ray,
            )
        }
        canvas.drawCircle(c, c, c * 0.28f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = look.flare })
        return bitmap
    }

    /** A to-do's steps as a row of segments, the done ones lit. */
    fun steps(look: Look, done: Int, total: Int): Bitmap? {
        if (total <= 0) return null
        val bitmap = Bitmap.createBitmap((300 * SCALE).toInt(), (8 * SCALE).toInt(), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val gap = 4 * SCALE
        val shown = minOf(total, 12)
        val width = (bitmap.width - gap * (shown - 1)) / shown
        val lit = if (total <= 12) done else (done * 12f / total).toInt()
        for (i in 0 until shown) {
            val left = i * (width + gap)
            canvas.drawRoundRect(
                RectF(left, 0f, left + width, bitmap.height.toFloat()),
                bitmap.height / 2f, bitmap.height / 2f,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (i < lit) look.accent else alpha(look.muted, 0.3f)
                },
            )
        }
        return bitmap
    }

    /** A habit's mark, or a plain disc of accent when there is none yet. */
    fun badgeOrDot(look: Look, glyph: Bitmap?): Bitmap {
        if (glyph != null) return glyph
        val size = (48 * SCALE).toInt()
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = alpha(look.accent, 0.2f)
        })
        canvas.drawCircle(size / 2f, size / 2f, max(size / 7f, 1f), Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = look.accent
        })
        return bitmap
    }
}
