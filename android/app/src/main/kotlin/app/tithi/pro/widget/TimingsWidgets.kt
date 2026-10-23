package app.tithi.pro.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import app.tithi.pro.R
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Shared rendering for the three timing widgets. Each concrete provider owns
 * a mode + title, but they bind the same `timings_widget_data` document and
 * the same RemoteViewsService.
 *
 * The current window is marked at render time from the stored ISO instants;
 * [WidgetRefreshReceiver] re-renders at the next window edge so the marker
 * stays truthful without polling.
 */
object TimingsWidgets {

    fun refreshAll(context: Context) {
        refresh(context, AuspiciousTimingsWidgetProvider::class.java, TimingWidgetService.MODE_AUSPICIOUS, R.string.widget_auspicious_label)
        refresh(context, InauspiciousTimingsWidgetProvider::class.java, TimingWidgetService.MODE_INAUSPICIOUS, R.string.widget_inauspicious_label)
        refresh(context, CombinedTimingsWidgetProvider::class.java, TimingWidgetService.MODE_COMBINED, R.string.widget_combined_label)
    }

    private fun refresh(
        context: Context,
        providerClass: Class<*>,
        mode: String,
        titleRes: Int,
    ) {
        val manager = try {
            AppWidgetManager.getInstance(context)
        } catch (_: Exception) {
            return
        }
        val prefs = try {
            context.getSharedPreferences(
                PanchangWidgetData.PREFS_NAME,
                Context.MODE_PRIVATE,
            )
        } catch (_: Exception) {
            return
        }
        val ids = try {
            manager.getAppWidgetIds(ComponentName(context, providerClass))
        } catch (_: Exception) {
            return
        }
        ids.forEach { id ->
            try {
                manager.updateAppWidget(id, buildViews(context, prefs, id, mode, titleRes))
                manager.notifyAppWidgetViewDataChanged(id, R.id.widget_timings_list)
            } catch (_: Exception) {
                // One bad host never blocks the rest.
            }
        }
    }

    fun buildViews(
        context: Context,
        prefs: SharedPreferences,
        widgetId: Int,
        mode: String,
        titleRes: Int,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_timings)
        val theme = WidgetSupport.theme(context)
        val isDark = WidgetSupport.forcedDark(theme)
        val payload = PanchangWidgetData.parseTimings(
            try {
                prefs.getString(PanchangWidgetData.KEY_TIMINGS, null)
            } catch (_: Exception) {
                null
            },
        )
        val day = payload?.today()
        val stale = day == null
        val title = when {
            mode == TimingWidgetService.MODE_AUSPICIOUS ->
                payload?.auspiciousTitle?.takeIf { it.isNotBlank() }
                    ?: context.getString(R.string.widget_auspicious_label)
            mode == TimingWidgetService.MODE_INAUSPICIOUS ->
                payload?.inauspiciousTitle?.takeIf { it.isNotBlank() }
                    ?: context.getString(R.string.widget_inauspicious_label)
            else -> payload?.combinedTitle?.takeIf { it.isNotBlank() }
                ?: context.getString(R.string.widget_combined_label)
        }

        views.setOnClickPendingIntent(
            R.id.widget_timings_container,
            WidgetSupport.launcherIntent(context),
        )
        views.setTextViewText(R.id.widget_timings_title, title)
        views.setTextViewText(R.id.widget_timings_date, day?.dateLabel.orEmpty())
        views.setTextViewText(R.id.widget_timings_sun, day?.sunLine.orEmpty())
        views.setTextViewText(
            R.id.widget_timings_empty,
            if (stale) {
                payload?.refreshLabel?.takeIf { it.isNotBlank() }
                    ?: context.getString(R.string.widget_timings_no_data)
            } else {
                context.getString(R.string.widget_timings_no_data)
            },
        )

        val rows = when (mode) {
            TimingWidgetService.MODE_AUSPICIOUS ->
                day?.rowsFor(PanchangWidgetData.SECTION_AUSPICIOUS).orEmpty()
            TimingWidgetService.MODE_INAUSPICIOUS ->
                day?.rowsFor(PanchangWidgetData.SECTION_INAUSPICIOUS).orEmpty()
            else -> day?.rows.orEmpty()
        }
        val current = PanchangWidgetData.currentRow(rows)
        if (current == null) {
            views.setViewVisibility(R.id.widget_timings_now, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_timings_now, View.VISIBLE)
            views.setTextViewText(R.id.widget_timings_now, "● ${current.name}")
        }

        // Distinct URI per widget/mode/theme so a reconfigure or mode change
        // rebinds a fresh factory instead of reusing a cached one.
        val serviceIntent = Intent(context, TimingWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            putExtra(TimingWidgetService.EXTRA_MODE, mode)
            data = Uri.parse("tithi://timings-widget/$widgetId/$mode/$theme")
        }
        views.setRemoteAdapter(R.id.widget_timings_list, serviceIntent)
        views.setEmptyView(R.id.widget_timings_list, R.id.widget_timings_empty)
        views.setPendingIntentTemplate(
            R.id.widget_timings_list,
            WidgetSupport.launcherIntent(context),
        )

        applyTheme(views, context, isDark)
        return views
    }

    private fun applyTheme(views: RemoteViews, context: Context, isDark: Boolean?) {
        WidgetSupport.applyBackground(
            views,
            context,
            R.id.widget_timings_container,
            isDark,
        )
        if (isDark == null) return
        fun color(light: Int, dark: Int): Int =
            ContextCompat.getColor(context, if (isDark) dark else light)

        views.setTextColor(
            R.id.widget_timings_brand,
            color(R.color.widget_primary_text_light, R.color.widget_primary_text_dark),
        )
        views.setTextColor(
            R.id.widget_timings_date,
            color(R.color.widget_secondary_text_light, R.color.widget_secondary_text_dark),
        )
        views.setTextColor(
            R.id.widget_timings_title,
            color(R.color.widget_title_text_light, R.color.widget_title_text_dark),
        )
        views.setTextColor(
            R.id.widget_timings_now,
            color(R.color.widget_primary_text_light, R.color.widget_primary_text_dark),
        )
        views.setTextColor(
            R.id.widget_timings_sun,
            color(R.color.widget_secondary_text_light, R.color.widget_secondary_text_dark),
        )
        views.setTextColor(
            R.id.widget_timings_empty,
            color(R.color.widget_secondary_text_light, R.color.widget_secondary_text_dark),
        )
    }
}

/** Base provider: ids in, one fully-bound RemoteViews out. */
abstract class BaseTimingsWidgetProvider(
    protected val mode: String,
    protected val titleRes: Int,
) : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        WidgetRefreshReceiver.ensureScheduled(context)
        if (appWidgetIds.isEmpty()) return
        appWidgetIds.forEach { id ->
            try {
                appWidgetManager.updateAppWidget(
                    id,
                    TimingsWidgets.buildViews(context, widgetData, id, mode, titleRes),
                )
                appWidgetManager.notifyAppWidgetViewDataChanged(
                    id,
                    R.id.widget_timings_list,
                )
            } catch (_: Exception) {
                // Leave the current frame in place.
            }
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetRefreshReceiver.ensureScheduled(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        // Cancels when this was the last Tithi widget on the launcher.
        WidgetRefreshReceiver.ensureScheduled(context)
    }
}

class AuspiciousTimingsWidgetProvider :
    BaseTimingsWidgetProvider(
        TimingWidgetService.MODE_AUSPICIOUS,
        R.string.widget_auspicious_label,
    )

class InauspiciousTimingsWidgetProvider :
    BaseTimingsWidgetProvider(
        TimingWidgetService.MODE_INAUSPICIOUS,
        R.string.widget_inauspicious_label,
    )

class CombinedTimingsWidgetProvider :
    BaseTimingsWidgetProvider(
        TimingWidgetService.MODE_COMBINED,
        R.string.widget_combined_label,
    )
