package app.tithi.pro.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetProvider
import app.tithi.pro.R
import app.tithi.pro.MainActivity
import org.json.JSONArray

/**
 * Home screen widget that shows festival countdowns.
 *
 * Reads data stored by Dart via HomeWidget.saveWidgetData (see
 * [WidgetCountdownData.KEY_DATA] / [WidgetCountdownData.KEY_THEME]).
 *
 * All countdowns are shown — never hidden. The rows live in a ListView backed
 * by [FestivalCountdownWidgetService], so when the widget is small the list
 * scrolls internally; when large it fills the space (weight=1, no blank gap).
 *
 * Memory: stateless — no static Context/views. One RemoteViews per widget id
 * plus a bounded (<=20) row cache in the factory, re-parsed only on data
 * notifications. [onDestroy] equivalent state is dropped with the factory.
 *
 * Theming: 'system' relies on values / values-night resources so Auto mode
 * follows the device theme. 'light'/'dark' force the fixed palette for
 * explicit app overrides (header here, rows in the factory).
 */
class FestivalCountdownWidgetProvider : HomeWidgetProvider() {

    companion object {
        /**
         * Synchronously rebuilds every widget instance in-process.
         * Used by the theme configure activity so a new choice repaints
         * immediately instead of depending on broadcast delivery timing.
         */
        fun refreshAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val prefs = context.getSharedPreferences(
                WidgetCountdownData.PREFS_NAME,
                Context.MODE_PRIVATE,
            )
            val ids = appWidgetManager.getAppWidgetIds(
                ComponentName(context, FestivalCountdownWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            val provider = FestivalCountdownWidgetProvider()
            ids.forEach { provider.updateSingleWidget(context, appWidgetManager, it, prefs) }
        }

        /**
         * Launcher-style PendingIntent: identical task behavior to tapping the
         * app icon, so widget taps never create a second Recents entry.
         */
        fun buildLauncherPendingIntent(context: Context): PendingIntent {
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
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        if (appWidgetIds.isEmpty()) return
        appWidgetIds.forEach { widgetId ->
            updateSingleWidget(context, appWidgetManager, widgetId, widgetData)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        // Resize: re-bind the same content. Nothing is hidden — the ListView
        // re-measures and scrolls if the new size fits fewer rows.
        val prefs = context.getSharedPreferences(
            WidgetCountdownData.PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        updateSingleWidget(context, appWidgetManager, appWidgetId, prefs)
    }

    private fun updateSingleWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_festival_countdown).apply {
            // Launcher-style intent so a widget tap reuses the existing app
            // task instead of opening a second window in Recents. It mirrors
            // the LAUNCHER tap (ACTION_MAIN + CATEGORY_LAUNCHER) with
            // SINGLE_TOP | CLEAR_TOP, so an already-running MainActivity is
            // brought forward via onNewIntent. Must NOT use a custom action
            // with android:taskAffinity="" — that combination forces the
            // system (FLAG_ACTIVITY_NEW_TASK from the widget host) to create
            // a separate task.
            val launchIntent = buildLauncherPendingIntent(context)
            setOnClickPendingIntent(R.id.widget_container, launchIntent)

            // Header count reflects the full stored list (parse is length-only).
            val total = storedCount(widgetData.getString(WidgetCountdownData.KEY_DATA, null))
            if (total == 0) {
                setTextViewText(R.id.widget_header_count, "")
            } else {
                setTextViewText(
                    R.id.widget_header_count,
                    "$total countdown${if (total == 1) "" else "s"}",
                )
            }

            val theme = widgetData.getString(WidgetCountdownData.KEY_THEME, "system")

            // Collection binding: distinct data URI per widget id AND theme, so
            // the framework rebinds (instead of reusing a cached factory) when
            // the theme choice changes — otherwise a switch back to Auto can
            // keep showing the previously forced palette until the next
            // configuration change.
            val serviceIntent = Intent(context, FestivalCountdownWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                data = Uri.parse("tithi://widget/$widgetId/$theme")
            }
            setRemoteAdapter(R.id.widget_list, serviceIntent)
            setEmptyView(R.id.widget_list, R.id.widget_empty)
            setPendingIntentTemplate(R.id.widget_list, launchIntent)

            // Explicit app theme overrides for the header;
            // 'system' keeps night-resource behavior.
            when (theme) {
                "light" -> applyHeaderTheme(this, context, isDark = false)
                "dark" -> applyHeaderTheme(this, context, isDark = true)
            }
        }
        // Push the chrome synchronously, then requery rows AFTER it lands.
        // The chrome update and the collection requery travel two different
        // async paths into the launcher; fired back-to-back they can race, and
        // the loser paints stale — surfacing as "only part of the widget
        // changed theme". A short delay guarantees the notify targets the
        // already-applied adapter binding, so header and rows always move as
        // one generation. (A theme switch additionally rebinds a fresh factory
        // via the theme-discriminated URI, whose onCreate loads current prefs
        // even if a notify were ever dropped.)
        appWidgetManager.updateAppWidget(widgetId, views)
        try {
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                try {
                    appWidgetManager.notifyAppWidgetViewDataChanged(
                        widgetId,
                        R.id.widget_list,
                    )
                } catch (_: Exception) {
                    // Best-effort: rows refresh on the next update regardless.
                }
            }, 300)
        } catch (_: Exception) {
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
        }
    }

    private fun storedCount(jsonString: String?): Int {
        if (jsonString.isNullOrBlank()) return 0
        return try {
            minOf(JSONArray(jsonString).length(), WidgetCountdownData.MAX_ITEMS)
        } catch (e: Exception) {
            0
        }
    }

    private fun applyHeaderTheme(views: RemoteViews, context: Context, isDark: Boolean) {
        fun c(light: Int, dark: Int): Int =
            ContextCompat.getColor(context, if (isDark) dark else light)

        views.setInt(
            R.id.widget_container,
            "setBackgroundResource",
            if (isDark) R.drawable.widget_background_dark
            else R.drawable.widget_background_light,
        )
        val primary = c(R.color.widget_primary_text_light, R.color.widget_primary_text_dark)
        val title = c(R.color.widget_title_text_light, R.color.widget_title_text_dark)
        val secondary = c(
            R.color.widget_secondary_text_light,
            R.color.widget_secondary_text_dark,
        )

        views.setTextColor(R.id.widget_brand, primary)
        views.setTextColor(R.id.widget_header_count, secondary)
        views.setTextColor(R.id.widget_title, title)
        views.setTextColor(R.id.widget_empty, secondary)
    }
}
