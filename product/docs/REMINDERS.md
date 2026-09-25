# Reminders

How Tide reminds people of habits and to-dos: what each part is, what the
phone has to allow, and how to test it — including on a locked phone.

## What there is

| | Habit | To-do |
|---|---|---|
| **Heads-up**, minutes before (None / 5 / 10 / 15) | **Rising Tide** — a custom notification: the habit's mark, a live countdown, water rising along the card as the minutes run, the streak. *I'm on it · Done already · Skip today* | **Beacon** — the same bones, a different picture: a lamp and a beam swinging down to the horizon, the to-do's steps as lit segments. *I'm on it · Done already · Tomorrow* |
| **At the time, full screen** | **Tide Call** — over the lock screen. Swipe up to ride the wave in (done), swipe the orb left to snooze, hold the orb to spend a freeze (skip today). Several habits at once ring as one call with stacked orbs and *Done all*. | **Lighthouse** — stars over a night sea and a lighthouse on a headland whose beam sweeps the sky and crosses the to-do's card. Slide the lit knob to the dock (done); steps can be ticked on the card, and it will not dock with steps open. *Snooze · Tomorrow* |
| **At the time, gentle** | A notification with *Done · Snooze · Skip today* | A notification with *Done · Snooze · Tomorrow* |
| **Unanswered** | After 2 minutes the call stops and leaves *"The tide went out on Gym — still time today."* | *"The beam passed Post the parcel — it is still on your list."* |

Every gesture has a button beside it and a screen-reader action. Snoozes stop
at three; the fourth "later" becomes a missed reminder. Quiet hours deliver
silently and drop heads-ups. Do Not Disturb is respected unless a habit (or
the to-do defaults) allows ringing through it.

Settings → Reminders holds the global switch, quiet hours, the defaults for
new habits and for every to-do, the permission list with a Fix button for each.

## Where the code is

* `lib/services/reminders/` — the planner (pure, like `StreakCalculator`), the
  store that re-plans on every habit and to-do change and applies answers
  given elsewhere, the platform seam, and the call controller.
* `lib/screens/tide_call/` — the Tide Call and the Lighthouse. The same widgets
  run over Android's lock screen (their own engine, `tideCallMain`) and inside
  the app (iOS taps, previews).
* `android/app/src/main/kotlin/com/example/tide/reminders/` — scheduling,
  notifications, the ringing service and the lock-screen activity.
* `tool/reminder_tones_test.dart` — synthesises the four tones into
  `res/raw`. Rerun after changing one.

A per-habit reminder's options live in `habits.reminder_options` (jsonb). **Run
`supabase/habits_setup.sql` again on an existing project**: until the column
exists the server refuses habit writes, and they wait in the app's outbox.

## Android

### Manifest

| Permission | Why |
|---|---|
| `POST_NOTIFICATIONS` | Anything at all (13+). Asked on the onboarding page, or when a reminder is first saved. |
| `USE_EXACT_ALARM` | Reminders on the minute, granted at install on 13+. **Google Play only allows it for alarm-clock and calendar apps** — for a Play build, remove it and keep `SCHEDULE_EXACT_ALARM` without `maxSdkVersion`; the app already asks for that and falls back to inexact alarms when refused. |
| `SCHEDULE_EXACT_ALARM` (≤ 32) | The same before Android 13. |
| `USE_FULL_SCREEN_INTENT` | The call over the lock screen. Android 14+ can refuse it; the call then arrives as a heads-up notification that opens it. |
| `FOREGROUND_SERVICE` | `TideCallService` (type `shortService`), which rings until answered. |
| `WAKE_LOCK`, `VIBRATE` | Ringing with the screen off, and the pulse. |
| `RECEIVE_BOOT_COMPLETED` | Re-arming after a reboot. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | The optional last onboarding card. Play restricts this one too. |

`ReminderReceiver` also hears `MY_PACKAGE_REPLACED`, `TIMEZONE_CHANGED` (habit
reminders keep their wall-clock time), `TIME_SET` and the exact-alarm
permission changing. After a **force stop** Android delivers nothing until
the app is opened, which hands the plan over again.

### How it holds together

The app hands native code the whole plan for a group (habits, to-dos) after
every change — already worded, with the palette's colours as numbers and each
habit's mark as a PNG. Native code keeps it in `SharedPreferences`, holds two
alarms (the next call via `setAlarmClock`, the next of everything else via
`setExactAndAllowWhileIdle`) and delivers everything due together when one
fires. Answers given on the lock screen or from a notification button are
queued and applied by the app's stores the next time it runs — at once if it
is running.

## iOS

Reminders go through `flutter_local_notifications`. A call is a
**time-sensitive** notification with Done, Snooze and Skip; tapping it opens
the Tide Call or the Lighthouse inside the app.

To finish on iOS, in Xcode:

1. **Time Sensitive Notifications** capability (entitlement
   `com.apple.developer.usernotifications.time-sensitive`). Without it the call
   arrives as an ordinary notification.
2. **Custom tones**: add `tone_*.caf` (convert the WAVs with
   `afconvert -f caff -d LEI16 tone_low_tide.wav tone_low_tide.caf`) to the
   Runner target, then set `sound:` in `darwin_reminder_platform.dart`.
3. Not built yet, each needing a new target: a **Notification Content
   Extension** for the Rising Tide card, a **Live Activity** for the
   countdown in the Dynamic Island, and **AlarmKit** (iOS 26) for a true
   system alarm with Tide's own presentation.

## Testing on a locked phone

1. Settings → Reminders → *What this phone allows*: everything ticked
   (notifications, exact alarms, full-screen alerts).
2. Give a habit a reminder a few minutes ahead, with a heads-up, then press
   the power button.
3. The Rising Tide heads-up lights the lock screen with its countdown. At the
   reminder's time the screen turns on and the Tide Call comes up over the
   lock screen, ringing on the **alarm** volume (turn it up), swelling over ten
   seconds, vibrating twice per orb bob.
4. Swipe up and let go past the line: the water surges, the streak counts up,
   the call closes and the phone is still locked. **Open Tide** asks for the
   unlock first. The habit is logged for today, as it would be from the app.
5. Leave one ringing for two minutes to see it give up into the missed
   notification. To see the snooze limit, snooze a call three times — the
   fourth is refused and it goes out as missed.
6. With the phone unlocked and in use, the call arrives as a heads-up instead
   of taking the screen; tapping it opens the full call.
7. A to-do with a reminder does the same with the Beacon and the Lighthouse.

With `adb`:

```sh
adb shell dumpsys alarm | grep -A3 com.example.tide    # the two armed alarms
adb shell cmd appops set com.example.tide USE_FULL_SCREEN_INTENT deny   # try the heads-up fallback
```

To check time zones, change the zone in the phone's date and time settings
after setting a habit reminder: `dumpsys alarm` should show the next call at
the same wall-clock time in the new zone.
