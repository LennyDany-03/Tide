package com.example.tide.reminders

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import kotlin.math.pow

/**
 * Rings a call: the chosen tone on the alarm stream, swelling from a murmur
 * to full over the first seconds, and a vibration that pulses on the orb's
 * bob — so the hand and the screen keep one rhythm.
 *
 * A foreground service rather than the notification's own sound, for three
 * reasons: a channel sound cannot swell, it plays once rather than until
 * answered, and nothing else keeps the process alive long enough to give up
 * cleanly. After [Timing.ringMinutes] with no answer it stops, and every
 * call still ringing is left behind as a missed-reminder notification.
 *
 * Its notification carries the full-screen intent that brings
 * [TideCallActivity] up over the lock screen.
 */
class TideCallService : Service() {
    companion object {
        private const val ACTION_RING = "com.example.tide.reminders.RING"
        private const val ACTION_ANSWERED = "com.example.tide.reminders.ANSWERED"

        /** Rings [items], together with anything already ringing. */
        fun ring(context: Context, items: List<ReminderItem>) {
            // Without notifications there is nothing the call could show,
            // and a phone ringing with nothing on it is worse than silence.
            if (!ReminderNotifications.canPost(context)) return
            ReminderBook.addRinging(context, items)
            val intent = Intent(context, TideCallService::class.java).setAction(ACTION_RING)
            try {
                ContextCompat.startForegroundService(context, intent)
            } catch (_: Exception) {
                // Not allowed to start from here. Each call arrives as an
                // ordinary reminder instead, with its sound.
                items.forEach {
                    ReminderBook.removeRinging(context, it.key)
                    ReminderNotifications.gentle(context, it, silent = false)
                }
            }
            TideCallActivity.refresh()
        }

        /** [key] was answered: it stops ringing, and the rest go on. */
        fun answered(context: Context, key: String) {
            ReminderBook.removeRinging(context, key) ?: return
            try {
                context.startService(
                    Intent(context, TideCallService::class.java).setAction(ACTION_ANSWERED),
                )
            } catch (_: IllegalStateException) {
                // Not running, and not startable from the background: there
                // is nothing ringing to stop.
            }
            TideCallActivity.refresh()
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var swellStarted = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val ringing = ReminderBook.ringing(this)
        if (ringing.isEmpty()) {
            stopEverything()
            return START_NOT_STICKY
        }
        val notification = ReminderNotifications.call(this, ringing)
        ServiceCompat.startForeground(
            this,
            ReminderNotifications.CALL_ID,
            notification,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE
            } else {
                0
            },
        )
        if (intent?.action == ACTION_RING) {
            ring(ringing)
        }
        return START_NOT_STICKY
    }

    private fun ring(ringing: List<ReminderItem>) {
        val timing = ReminderBook.timing(this)
        val newest = ringing.last()
        holdAwake(timing)
        playTone(newest, timing)
        if (ringing.any { it.vibrate }) vibrate(timing.pulseMillis) else stopVibrating()
        // A call that has just joined rings for the full time again.
        handler.removeCallbacks(ringOut)
        handler.postDelayed(ringOut, timing.ringMinutes * 60_000L)
    }

    private val ringOut = Runnable {
        for (item in ReminderBook.clearRinging(this)) {
            ReminderNotifications.missed(this, item)
        }
        TideCallActivity.finishCall()
        stopEverything()
    }

    // --- Sound ---------------------------------------------------------------

    private fun playTone(item: ReminderItem, timing: Timing) {
        stopTone()
        val resource = item.tone
        player = try {
            MediaPlayer().apply {
                setAudioAttributes(ReminderNotifications.alarmAudio)
                setDataSource(this@TideCallService, Uri.parse("android.resource://$packageName/$resource"))
                isLooping = true
                setVolume(START_VOLUME, START_VOLUME)
                prepare()
                start()
            }
        } catch (_: Exception) {
            null
        }
        swellStarted = System.currentTimeMillis()
        handler.removeCallbacks(swell)
        swellMillis = timing.swellSeconds * 1000L
        handler.post(swell)
    }

    private var swellMillis = 10_000L

    /** Eases the volume up rather than ramping it: most of the rise comes late. */
    private val swell = object : Runnable {
        override fun run() {
            val player = player ?: return
            val t = ((System.currentTimeMillis() - swellStarted).toFloat() / swellMillis).coerceIn(0f, 1f)
            val volume = START_VOLUME + (1 - START_VOLUME) * t.pow(1.6f)
            try {
                player.setVolume(volume, volume)
            } catch (_: IllegalStateException) {
                return
            }
            if (t < 1f) handler.postDelayed(this, SWELL_STEP_MS)
        }
    }

    private fun stopTone() {
        handler.removeCallbacks(swell)
        player?.let {
            try {
                it.stop()
            } catch (_: IllegalStateException) {
            }
            it.release()
        }
        player = null
    }

    // --- Vibration -----------------------------------------------------------

    /**
     * Two soft pulses per bob of the orb — one as it rises, a lighter one as
     * it settles — repeating until answered.
     */
    private fun vibrate(period: Long) {
        stopVibrating()
        val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Vibrator::class.java)
        }
        if (device == null || !device.hasVibrator()) return
        val pulse = 180L
        val gap = (period / 2 - pulse).coerceAtLeast(200L)
        val timings = longArrayOf(0, pulse, gap, pulse, gap)
        val amplitudes = intArrayOf(0, 150, 0, 70, 0)
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> device.vibrate(
                VibrationEffect.createWaveform(timings, amplitudes, 1),
                VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM),
            )
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> @Suppress("DEPRECATION")
            device.vibrate(
                VibrationEffect.createWaveform(timings, amplitudes, 1),
                ReminderNotifications.alarmAudio,
            )
            // Android 7: one strength for every pulse.
            else -> @Suppress("DEPRECATION") device.vibrate(timings, 1)
        }
        vibrator = device
    }

    private fun stopVibrating() {
        vibrator?.cancel()
        vibrator = null
    }

    // --- Staying up ----------------------------------------------------------

    private fun holdAwake(timing: Timing) {
        if (wakeLock?.isHeld == true) return
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "tide:call")
            .apply { acquire((timing.ringMinutes + 1) * 60_000L) }
    }

    /** Android 14 gives a short service about three minutes; this is it ending. */
    override fun onTimeout(startId: Int) {
        ringOut.run()
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        ringOut.run()
    }

    private fun stopEverything() {
        handler.removeCallbacksAndMessages(null)
        stopTone()
        stopVibrating()
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        stopTone()
        stopVibrating()
        wakeLock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }
}

private const val START_VOLUME = 0.06f
private const val SWELL_STEP_MS = 200L
