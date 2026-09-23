package com.example.tide

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

/**
 * Switches the launcher icon to the one drawn in the active palette.
 *
 * An app cannot repaint its own icon, so AndroidManifest.xml declares one
 * `.Launcher*` activity-alias per palette, each with its own icon, and
 * exactly one is enabled. [request] only records the wanted palette; [apply]
 * does the switch, and MainActivity calls it from onStop. Changing which
 * launcher component is enabled while the app is on screen makes some
 * launchers close it, so the switch waits until nobody is looking at it.
 */
object LauncherIcon {
    private const val PREFS = "tide_launcher_icon"
    private const val KEY_WANTED = "wanted"

    /** Palette id → alias class, in manifest order. Midnight is the default. */
    private val aliases = linkedMapOf(
        "midnight" to "LauncherMidnight",
        "deep_water" to "LauncherDeepWater",
        "ink" to "LauncherInk",
        "blossom" to "LauncherBlossom",
        "paper" to "LauncherPaper",
    )

    fun request(context: Context, paletteId: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_WANTED, paletteId)
            .apply()
    }

    fun apply(context: Context) {
        val wanted = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_WANTED, null) ?: return
        // A palette from a newer build with no alias here keeps the default.
        val target = aliases[wanted] ?: aliases.getValue("midnight")
        val pm = context.packageManager

        fun component(alias: String) = ComponentName(context.packageName, "${context.packageName}.$alias")

        fun enabled(alias: String): Boolean =
            when (pm.getComponentEnabledSetting(component(alias))) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> false
                // Untouched: whatever the manifest says, which is Midnight on.
                else -> alias == "LauncherMidnight"
            }

        fun set(alias: String, on: Boolean) {
            if (enabled(alias) == on) return
            pm.setComponentEnabledSetting(
                component(alias),
                if (on) {
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                } else {
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                },
                PackageManager.DONT_KILL_APP,
            )
        }

        // The new entry first, so there is never a moment with no launcher
        // entry at all.
        set(target, true)
        for (alias in aliases.values) {
            if (alias != target) set(alias, false)
        }
    }
}
