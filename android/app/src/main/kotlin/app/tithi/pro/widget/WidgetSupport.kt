package app.tithi.pro.widget

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import app.tithi.pro.MainActivity
import app.tithi.pro.R

/**
 * Cross-widget plumbing shared by the hero and timing widgets: the launcher
 * tap intent, the theme override contract, and palette helpers.
 *
 * Theme: the key is owned by the widget configure activity and shared by
 * every Tithi widget. "system" leaves the night-qualified resources in charge;
 * "light"/"dark" force the fixed palettes.
 */
object WidgetSupport {

    const val THEME_KEY = WidgetCountdownData.KEY_THEME
    const val THEME_SYSTEM = "system"

    fun theme(context: Context): String {
        return try {
            context.getSharedPreferences(
                PanchangWidgetData.PREFS_NAME,
                Context.MODE_PRIVATE,
            ).getString(THEME_KEY, THEME_SYSTEM) ?: THEME_SYSTEM
        } catch (_: Exception) {
            THEME_SYSTEM
        }
    }

    /** null = follow the device (night resources). */
    fun forcedDark(theme: String): Boolean? = when (theme) {
        "dark" -> true
        "light" -> false
        else -> null
    }

    /** Launcher-style intent: tapping a widget reuses the running app task. */
    fun launcherIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getActivity(context, 0, intent, flags)
    }

    /** Forced-theme container background; no-op for system (resources win). */
    fun applyBackground(
        views: RemoteViews,
        context: Context,
        rootId: Int,
        isDark: Boolean?,
        lightRes: Int = R.drawable.widget_background_light,
        darkRes: Int = R.drawable.widget_background_dark,
    ) {
        if (isDark == null) return
        views.setInt(
            rootId,
            "setBackgroundResource",
            if (isDark) darkRes else lightRes,
        )
    }

    /** Forced-theme text color; no-op for system. */
    fun setTextColor(
        views: RemoteViews,
        context: Context,
        viewId: Int,
        lightRes: Int,
        darkRes: Int,
        isDark: Boolean?,
    ) {
        if (isDark == null) return
        views.setTextColor(
            viewId,
            ContextCompat.getColor(context, if (isDark) darkRes else lightRes),
        )
    }

    /** Explicit palette color (used for accent/dot even in system mode). */
    fun accentColor(context: Context, isDark: Boolean?): Int {
        val dark = isDark ?: isSystemDark(context)
        return ContextCompat.getColor(
            context,
            if (dark) R.color.widget_accent_dark else R.color.widget_accent_light,
        )
    }

    fun systemDark(context: Context): Boolean = isSystemDark(context)

    private fun isSystemDark(context: Context): Boolean {
        return try {
            (context.resources.configuration.uiMode and
                android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
                android.content.res.Configuration.UI_MODE_NIGHT_YES
        } catch (_: Exception) {
            false
        }
    }
}
