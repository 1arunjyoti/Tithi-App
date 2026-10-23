package app.tithi.pro.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/**
 * Shared refresh heartbeat for all Tithi home-screen widgets.
 *
 * Two alarms, both inexact (no exact-alarm permission, no user prompt):
 *  - a one-shot 00:01 RTC alarm, re-armed by this receiver after each fire,
 *    so every widget rolls over to the new day even when the app process is
 *    dead;
 *  - a one-shot RTC alarm at the next timing-window edge, so the "now" marker
 *    on the timing widgets moves as the day advances.
 *
 * Both intents target this receiver explicitly, and every entry point
 * re-arms them (idempotent), which absorbs OEM alarm clearing, reboots, app
 * updates and wall-clock jumps. When no Tithi widget is on the launcher the
 * alarms are cancelled instead of waking the device forever.
 *
 * Memory: stateless receiver, no static Context; all work is bounded
 * (<=20 countdown rows, <=9 timing rows per day).
 */
class WidgetRefreshReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_DAILY_REFRESH =
            "app.tithi.pro.widget.ACTION_PANCHANG_DAILY_REFRESH"
        const val ACTION_BOUNDARY_REFRESH =
            "app.tithi.pro.widget.ACTION_TIMING_BOUNDARY_REFRESH"

        private const val DAILY_REQUEST_CODE = 1710
        private const val BOUNDARY_REQUEST_CODE = 1711

        /**
         * Repaints every widget instance in-process. Crash-isolated per
         * provider and per host so one broken launcher entry cannot block the
         * rest of the refresh.
         */
        fun refreshAll(context: Context) {
            try {
                FestivalCountdownWidgetProvider.refreshAll(context)
            } catch (_: Exception) {
                // Best-effort.
            }
            try {
                HeroWidgetProvider.refreshAll(context)
            } catch (_: Exception) {
                // Best-effort.
            }
            try {
                TimingsWidgets.refreshAll(context)
            } catch (_: Exception) {
                // Best-effort.
            }
        }

        private data class InstalledWidgets(
            val anyPanchang: Boolean,
            val anyTiming: Boolean,
        )

        /** (Re)arms the daily + boundary alarms. Safe to call from any path. */
        fun ensureScheduled(context: Context) {
            val installed = installedWidgets(context)
            if (!installed.anyPanchang) {
                // Last instance removed: stop the heartbeat instead of
                // waking the device for a widget nobody has.
                cancelAll(context)
                return
            }
            armDaily(context)
            if (installed.anyTiming) {
                armNextBoundary(context)
            } else {
                // A hero-only launcher has no "now" marker to advance, so
                // don't wake it at every window edge.
                cancelBoundary(context)
            }
        }

        fun cancelAll(context: Context) {
            try {
                val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                    ?: return
                manager.cancel(dailyPendingIntent(context))
                manager.cancel(boundaryPendingIntent(context))
            } catch (_: Exception) {
                // Best-effort cleanup.
            }
        }

        private fun cancelBoundary(context: Context) {
            try {
                val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                    ?: return
                manager.cancel(boundaryPendingIntent(context))
            } catch (_: Exception) {
                // Best-effort cleanup.
            }
        }

        private fun installedWidgets(context: Context): InstalledWidgets {
            val manager = try {
                AppWidgetManager.getInstance(context)
            } catch (_: Exception) {
                return InstalledWidgets(anyPanchang = false, anyTiming = false)
            }
            fun has(provider: Class<*>): Boolean = try {
                manager.getAppWidgetIds(ComponentName(context, provider)).isNotEmpty()
            } catch (_: Exception) {
                false
            }

            val hero = has(HeroWidgetProvider::class.java)
            val timing = has(AuspiciousTimingsWidgetProvider::class.java) ||
                has(InauspiciousTimingsWidgetProvider::class.java) ||
                has(CombinedTimingsWidgetProvider::class.java)
            return InstalledWidgets(
                anyPanchang = hero || timing,
                anyTiming = timing,
            )
        }

        /** Next 00:01 local time — just past midnight so LocalDate has rolled. */
        private fun nextMidnightMillis(): Long {
            val now = Calendar.getInstance()
            val target = (now.clone() as Calendar).apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 1)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (!target.after(now)) target.add(Calendar.DAY_OF_YEAR, 1)
            return target.timeInMillis
        }

        private fun pendingFlags(): Int =
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0

        private fun dailyPendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, WidgetRefreshReceiver::class.java).apply {
                action = ACTION_DAILY_REFRESH
            }
            return PendingIntent.getBroadcast(
                context,
                DAILY_REQUEST_CODE,
                intent,
                pendingFlags(),
            )
        }

        private fun boundaryPendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, WidgetRefreshReceiver::class.java).apply {
                action = ACTION_BOUNDARY_REFRESH
            }
            return PendingIntent.getBroadcast(
                context,
                BOUNDARY_REQUEST_CODE,
                intent,
                pendingFlags(),
            )
        }

        private fun armDaily(context: Context) {
            try {
                val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                    ?: return
                // One-shot, not setInexactRepeating: every onUpdate re-arms
                // this to the same "next 00:01", so a repeating alarm would be
                // pushed forward forever and never fire. The receiver re-arms
                // it after each daily fire.
                val trigger = nextMidnightMillis()
                val operation = dailyPendingIntent(context)
                if (Build.VERSION.SDK_INT >= 23) {
                    manager.setAndAllowWhileIdle(AlarmManager.RTC, trigger, operation)
                } else {
                    manager.set(AlarmManager.RTC, trigger, operation)
                }
            } catch (_: Exception) {
                // Best-effort: updatePeriodMillis still triggers onUpdate.
            }
        }

        /**
         * One-shot at the next ISO start/end edge in today's timing payload.
         * RTC (not wakeup) so the highlight catches up on the next device
         * wake; the 30-minute updatePeriodMillis heartbeat is the backstop.
         */
        private fun armNextBoundary(context: Context) {
            try {
                val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                    ?: return
                val prefs = context.getSharedPreferences(
                    PanchangWidgetData.PREFS_NAME,
                    Context.MODE_PRIVATE,
                )
                val payload = PanchangWidgetData.parseTimings(
                    prefs.getString(PanchangWidgetData.KEY_TIMINGS, null),
                )
                val next = PanchangWidgetData.nextBoundaryMillis(payload?.today())
                if (next == null) {
                    // No future edge today: the daily alarm is the next wake.
                    manager.cancel(boundaryPendingIntent(context))
                    return
                }
                // Tiny offset so LocalDateTime.now() is already past the edge.
                val trigger = next + 1_500L
                val operation = boundaryPendingIntent(context)
                if (Build.VERSION.SDK_INT >= 23) {
                    manager.setAndAllowWhileIdle(AlarmManager.RTC, trigger, operation)
                } else {
                    manager.set(AlarmManager.RTC, trigger, operation)
                }
            } catch (_: Exception) {
                // Best-effort: the periodic update re-arms on the next pass.
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        when (action) {
            ACTION_DAILY_REFRESH,
            ACTION_BOUNDARY_REFRESH,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            -> {
                ensureScheduled(context)
                refreshAll(context)
            }
        }
    }
}
