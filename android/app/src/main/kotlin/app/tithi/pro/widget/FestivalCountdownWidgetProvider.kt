package app.tithi.pro.widget

import android.app.AlarmManager
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
import java.util.Calendar

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
         * Daily self-refresh alarm: fires just after midnight so the
         * date-recomputed countdowns roll over even when the app process
         * is dead (killed from memory / never opened). Battery-friendly:
         * RTC (no wakeup) + inexact — if the device sleeps through
         * midnight the refresh lands on wake, and DATE_CHANGED covers
         * the gap. Re-armed on every update + boot + package-replace so
         * OEMs that clear alarms can't leave the widget stale.
         */
        const val ACTION_DAILY_REFRESH =
            "app.tithi.pro.widget.ACTION_DAILY_REFRESH"
        private const val ALARM_REQUEST_CODE = 1703

        /**
         * Synchronously rebuilds every widget instance in-process.
         * Used by the theme configure activity so a new choice repaints
         * immediately instead of depending on broadcast delivery timing.
         *
         * Crash-isolated per widget: a dead launcher host or a bad
         * RemoteViews on one instance (or credential-locked storage in
         * direct-boot) must not abort the remaining instances or crash
         * the broadcast that invoked this.
         */
        fun refreshAll(context: Context) {
            val appWidgetManager = try {
                AppWidgetManager.getInstance(context)
            } catch (_: Exception) {
                return
            }
            val prefs = try {
                context.getSharedPreferences(
                    WidgetCountdownData.PREFS_NAME,
                    Context.MODE_PRIVATE,
                )
            } catch (_: Exception) {
                // Direct-boot before unlock: credential storage is locked.
                return
            }
            val ids = try {
                appWidgetManager.getAppWidgetIds(
                    ComponentName(context, FestivalCountdownWidgetProvider::class.java),
                )
            } catch (_: Exception) {
                return
            }
            if (ids.isEmpty()) return
            val provider = FestivalCountdownWidgetProvider()
            ids.forEach {
                try {
                    provider.updateSingleWidget(context, appWidgetManager, it, prefs)
                } catch (_: Exception) {
                    // One bad instance never blocks the rest.
                }
            }
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

        private fun dailyRefreshPendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, FestivalCountdownWidgetProvider::class.java).apply {
                action = ACTION_DAILY_REFRESH
            }
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= 23) {
                flags = flags or PendingIntent.FLAG_IMMUTABLE
            }
            return PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                flags,
            )
        }

        /** Next 00:01 local time — just past midnight so LocalDate has rolled. */
        private fun nextMidnightMillis(): Long {
            val cal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 1)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            return cal.timeInMillis
        }

        /**
         * (Re)arms the daily inexact RTC alarm. Idempotent — safe to call
         * from every update/receive path. RTC (not WAKEUP) needs no
         * exact-alarm permission and costs no wakeups; inexact lets the
         * system batch it with other midnight work.
         */
        fun ensureDailyAlarm(context: Context) {
            try {
                val am =
                    context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                        ?: return
                am.setInexactRepeating(
                    AlarmManager.RTC,
                    nextMidnightMillis(),
                    AlarmManager.INTERVAL_DAY,
                    dailyRefreshPendingIntent(context),
                )
            } catch (_: Exception) {
                // Best-effort: updatePeriodMillis still triggers onUpdate.
            }
        }

        fun cancelDailyAlarm(context: Context) {
            try {
                val am =
                    context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                        ?: return
                am.cancel(dailyRefreshPendingIntent(context))
            } catch (_: Exception) {
                // Best-effort cleanup.
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        // System never sends a null intent, but the base
        // AppWidgetProvider dereferences it — guard instead of NPE-crash
        // the broadcast.
        val action = intent?.action ?: return
        // Let the home_widget base + AppWidgetProvider handle the standard
        // widget broadcasts first (it caches SharedPreferences for onUpdate).
        super.onReceive(context, intent)
        // Self-refresh paths that must work while the app process is dead:
        // the daily alarm, reboot / app-update (alarms are cleared), and
        // wall-clock jumps (date/time/timezone) that invalidate day counts.
        when (action) {
            ACTION_DAILY_REFRESH,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            -> {
                ensureDailyAlarm(context)
                refreshAll(context)
            }
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        ensureDailyAlarm(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelDailyAlarm(context)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        // updatePeriodMillis delivery is the heartbeat: re-arm the daily
        // alarm here too so a cleared alarm (reboot, OEM task-killer,
        // app update) is restored even if those broadcasts were missed.
        ensureDailyAlarm(context)
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
        val prefs = try {
            context.getSharedPreferences(
                WidgetCountdownData.PREFS_NAME,
                Context.MODE_PRIVATE,
            )
        } catch (_: Exception) {
            // Credential-locked storage: keep the current frame.
            return
        }
        updateSingleWidget(context, appWidgetManager, appWidgetId, prefs)
    }

    private fun updateSingleWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences,
    ) {
        val views = try {
            buildWidgetViews(context, widgetId, widgetData)
        } catch (_: Exception) {
            // Corrupt prefs / missing resources: leave the current frame
            // in place rather than crashing the broadcast.
            return
        }
        pushWidgetViews(appWidgetManager, widgetId, views)
    }

    private fun buildWidgetViews(
        context: Context,
        widgetId: Int,
        widgetData: SharedPreferences,
    ): RemoteViews {
        return RemoteViews(context.packageName, R.layout.widget_festival_countdown).apply {
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

            // Header count reflects the active (not yet passed) list so it
            // matches the filtered rows after a midnight refresh without
            // the app running. Bounded parse (<=20 small objects).
            val total = WidgetCountdownData.activeCount(
                widgetData.getString(WidgetCountdownData.KEY_DATA, null),
            )
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
    }

    private fun pushWidgetViews(
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        views: RemoteViews,
    ) {
        // Push the chrome synchronously, then requery rows AFTER it lands.
        // The chrome update and the collection requery travel two different
        // async paths into the launcher; fired back-to-back they can race, and
        // the loser paints stale — surfacing as "only part of the widget
        // changed theme". A short delay guarantees the notify targets the
        // already-applied adapter binding, so header and rows always move as
        // one generation. (A theme switch additionally rebinds a fresh factory
        // via the theme-discriminated URI, whose onCreate loads current prefs
        // even if a notify were ever dropped.)
        //
        // The immediate notify is load-bearing for dead-process refreshes
        // (daily alarm / boot / date-change with the app killed): the process
        // hosting this broadcast can die before a delayed post runs, leaving
        // the header fresh but the rows stale — the reported "stuck"
        // countdown. The delayed re-notify is kept as second-wave insurance
        // for the chrome/rows race while the process is alive.
        // Every IPC below is guarded: a dead launcher host must degrade to
        // "rows refresh on the next update", never crash the broadcast.
        try {
            appWidgetManager.updateAppWidget(widgetId, views)
        } catch (_: Exception) {
            return
        }
        try {
            appWidgetManager.notifyAppWidgetViewDataChanged(
                widgetId,
                R.id.widget_list,
            )
        } catch (_: Exception) {
            // Best-effort: rows refresh on the next update regardless.
        }
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
            // Handler unavailable (no looper): immediate notify above stands.
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
