package com.example.tide.reminders

import android.app.KeyguardManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import com.example.tide.MainActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * The Tide Call and the Lighthouse, over the lock screen.
 *
 * **Its own Flutter engine, on its own entry point** (`tideCallMain` in
 * lib/main.dart). The screen shown over a locked phone must not be a way
 * into the rest of it, so this is not the app with a route pushed: it is a
 * second, small app that knows only what is ringing. There is no router
 * behind the call to go back to and no account in memory to read. "Open
 * Tide" asks the phone to unlock first, and only then starts the app.
 *
 * It shows over the lock screen and turns the screen on for as long as it is
 * up, and answers on `tide/call`: what is ringing, and what was answered.
 */
class TideCallActivity : FlutterActivity() {
    companion object {
        private var current: TideCallActivity? = null
        private val main = Handler(Looper.getMainLooper())

        /** The ringing calls changed — one joined, or one was answered from
         *  the notification. */
        fun refresh() = main.post { current?.channel?.invokeMethod("changed", null) }

        /** Rang out: the screen goes with the sound. */
        fun finishCall() = main.post { current?.finish() }
    }

    private var channel: MethodChannel? = null

    override fun getDartEntrypointFunctionName(): String = "tideCallMain"

    override fun onCreate(savedInstanceState: Bundle?) {
        showOverLockScreen()
        super.onCreate(savedInstanceState)
        current = this
    }

    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tide/call").also {
            it.setMethodCallHandler(::onCall)
        }
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "load" -> result.success(load())
            "resolve" -> {
                val item = call.argument<String>("key")?.let { ReminderBook.find(this, it) }
                val outcome = call.argument<String>("outcome")
                if (item != null && outcome != null) CallActions.resolve(this, item, outcome)
                result.success(null)
            }
            "step" -> {
                val item = call.argument<String>("key")?.let { ReminderBook.find(this, it) }
                val step = call.argument<String>("step")
                if (item != null && step != null) {
                    CallActions.step(this, item, step, call.argument<Boolean>("value") ?: true)
                }
                result.success(null)
            }
            "openApp" -> {
                openApp(call.argument<String>("key"))
                result.success(null)
            }
            "close" -> {
                finish()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * What is ringing, with the answers still waiting to be applied for the
     * same habits — the call works out today's streak from the device's copy
     * of the account plus these.
     */
    private fun load(): String {
        val ringing = ReminderBook.ringing(this)
        val subjects = ringing.map { it.subject }.toSet()
        val waiting = ReminderBook.peekAnswers(this)
        val pending = JSONArray()
        for (i in 0 until waiting.length()) {
            val answer = waiting.getJSONObject(i)
            if (answer.optString("subject") in subjects) pending.put(answer)
        }
        val calls = JSONArray()
        val snoozes = JSONObject()
        for (item in ringing) {
            calls.put(item.json)
            snoozes.put(item.key, item.snoozes)
        }
        val keyguard = getSystemService(KeyguardManager::class.java)
        return JSONObject()
            .put("calls", calls)
            .put("pending", pending)
            .put("snoozes", snoozes)
            .put("locked", keyguard.isKeyguardLocked)
            .toString()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        channel?.invokeMethod("changed", null)
    }

    /** Leaves the call for the app: unlocked first, then on what it was about. */
    private fun openApp(key: String?) {
        val item = key?.let { ReminderBook.find(this, it) }
        val open = Intent(this, MainActivity::class.java)
            .setAction("com.example.tide.OPEN_REMINDER")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (item != null) {
            open.putExtra(ReminderNotifications.EXTRA_TARGET, if (item.isHabit) "habit" else "task")
            open.putExtra(ReminderNotifications.EXTRA_ID, item.subject)
        }
        val keyguard = getSystemService(KeyguardManager::class.java)
        // Before Android 8 there is no asking: the app simply opens, and the
        // phone's own lock screen stands in front of it until it is unlocked
        // — the app itself never shows over the lock screen.
        if (keyguard.isKeyguardLocked && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            keyguard.requestDismissKeyguard(
                this,
                object : KeyguardManager.KeyguardDismissCallback() {
                    override fun onDismissSucceeded() {
                        startActivity(open)
                        finish()
                    }
                },
            )
        } else {
            startActivity(open)
            finish()
        }
    }

    override fun onDestroy() {
        if (current === this) current = null
        channel?.setMethodCallHandler(null)
        super.onDestroy()
    }
}
