package com.example.tide

import android.annotation.SuppressLint
import android.content.Context
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Draws every widget in the palette the app is showing.
 *
 * The launcher inflates widgets from resources, so a palette cannot be
 * applied by reading tokens the way Flutter does. Instead each palette other
 * than Midnight has generated copies of every widget layout and drawable,
 * named `<original>_<palette id>` (see tool/widget_palettes_test.dart), and
 * this swaps an original resource for its copy. The Dart side writes the
 * palette id under [KEY_PALETTE] whenever it changes.
 *
 * Anything unknown — no id yet, an id from a newer build, a resource with no
 * copy — falls back to the Midnight original, so a widget always draws.
 */
object WidgetTheme {
    const val KEY_PALETTE = "tide_palette"

    /** "" for Midnight (the originals), else "_<palette id>". */
    fun suffix(context: Context): String {
        val id = HomeWidgetPlugin.getData(context).getString(KEY_PALETTE, null)
        if (id.isNullOrEmpty()) return ""
        // A palette this build has no widget colours for draws as Midnight.
        return if (lookup(context, "tide_${id}_bone", "color") != 0) "_$id" else ""
    }

    fun layout(context: Context, original: Int): Int = variant(context, original, "layout")

    fun drawable(context: Context, original: Int): Int = variant(context, original, "drawable")

    /** A resolved colour int for a `R.color.tide_*` role. */
    fun color(context: Context, original: Int): Int {
        val suffix = suffix(context)
        if (suffix.isEmpty()) return context.getColor(original)
        val role = context.resources.getResourceEntryName(original).removePrefix("tide_")
        val themed = lookup(context, "tide${suffix}_$role", "color")
        return context.getColor(if (themed != 0) themed else original)
    }

    private fun variant(context: Context, original: Int, type: String): Int {
        val suffix = suffix(context)
        if (suffix.isEmpty()) return original
        val name = context.resources.getResourceEntryName(original)
        val themed = lookup(context, "$name$suffix", type)
        return if (themed != 0) themed else original
    }

    // By name on purpose: the variants are generated, so there is no R field
    // to write a table against without generating Kotlin too.
    @SuppressLint("DiscouragedApi")
    private fun lookup(context: Context, name: String, type: String): Int =
        context.resources.getIdentifier(name, type, context.packageName)
}
