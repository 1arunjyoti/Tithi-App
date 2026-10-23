package app.tithi.pro.widget

import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import androidx.core.content.ContextCompat
import app.tithi.pro.R

/**
 * Collection backing for the three timing widgets.
 *
 * One service serves all modes: the provider passes [EXTRA_MODE] and the
 * factory filters/sections the single `timings_widget_data` payload. Rows are
 * ordered exactly as the tithi detail sheet lists them.
 *
 * Memory: bounded (<=9 rows) cached data objects, re-parsed only in
 * [onCreate]/[onDataSetChanged]. No static Context or views.
 */
class TimingWidgetService : RemoteViewsService() {

    companion object {
        const val EXTRA_MODE = "timing_mode"
        const val MODE_AUSPICIOUS = "auspicious"
        const val MODE_INAUSPICIOUS = "inauspicious"
        const val MODE_COMBINED = "combined"
    }

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = TimingFactory(
        applicationContext,
        intent.getStringExtra(EXTRA_MODE) ?: MODE_COMBINED,
    )

    class TimingFactory(
        private val context: Context,
        private val mode: String,
    ) : RemoteViewsFactory {

        private data class Entry(val header: String = "", val row: PanchangWidgetData.TimingRow? = null)

        private var entries: List<Entry> = emptyList()
        private var forceDark: Boolean? = null
        private var currentStart: java.time.LocalDateTime? = null
        private var currentEnd: java.time.LocalDateTime? = null

        override fun onCreate() = load()

        override fun onDataSetChanged() = load()

        private fun load() {
            // Runs on the host's binder thread: locked/corrupt prefs must
            // degrade to last-good rows, never crash the factory.
            try {
                val prefs = context.getSharedPreferences(
                    PanchangWidgetData.PREFS_NAME,
                    Context.MODE_PRIVATE,
                )
                val payload = PanchangWidgetData.parseTimings(
                    prefs.getString(PanchangWidgetData.KEY_TIMINGS, null),
                )
                forceDark = WidgetSupport.forcedDark(WidgetSupport.theme(context))
                val day = payload?.today()
                if (day == null) {
                    // Stale (or never synced): provider shows the empty view.
                    // Drop the previous day's marker too, so a later reload
                    // can never match a row against yesterday's window.
                    entries = emptyList()
                    currentStart = null
                    currentEnd = null
                    return
                }
                val current = PanchangWidgetData.currentRow(day.rows)
                currentStart = current?.start
                currentEnd = current?.end

                val auspicious = day.rowsFor(PanchangWidgetData.SECTION_AUSPICIOUS)
                val inauspicious = day.rowsFor(PanchangWidgetData.SECTION_INAUSPICIOUS)
                entries = when (mode) {
                    MODE_AUSPICIOUS -> auspicious.map { Entry(row = it) }
                    MODE_INAUSPICIOUS -> inauspicious.map { Entry(row = it) }
                    else -> buildList {
                        if (auspicious.isNotEmpty()) {
                            add(Entry(header = payload.auspiciousTitle))
                            addAll(auspicious.map { Entry(row = it) })
                        }
                        if (inauspicious.isNotEmpty()) {
                            add(Entry(header = payload.inauspiciousTitle))
                            addAll(inauspicious.map { Entry(row = it) })
                        }
                    }
                }
            } catch (_: Exception) {
                // Keep the previous entries.
            }
        }

        override fun onDestroy() {
            entries = emptyList()
            currentStart = null
            currentEnd = null
            forceDark = null
        }

        override fun getCount(): Int = entries.size

        override fun getViewAt(position: Int): RemoteViews {
            val entry = entries.getOrNull(position)
            if (entry?.row == null) {
                val views = RemoteViews(context.packageName, R.layout.widget_timing_section)
                views.setTextViewText(
                    R.id.widget_timing_section_header,
                    entry?.header ?: "",
                )
                applySectionTheme(views)
                return views
            }

            val row = entry.row
            val views = RemoteViews(context.packageName, R.layout.widget_timing_row)
            views.setTextViewText(R.id.widget_timing_name, row.name)
            views.setTextViewText(R.id.widget_timing_time, row.time)
            if (row.note.isBlank()) {
                views.setViewVisibility(R.id.widget_timing_note, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_timing_note, View.VISIBLE)
                views.setTextViewText(R.id.widget_timing_note, row.note)
            }

            val isNow = currentStart != null &&
                row.start == currentStart &&
                row.end == currentEnd
            views.setViewVisibility(
                R.id.widget_timing_now,
                if (isNow) View.VISIBLE else View.INVISIBLE,
            )

            // Tap a row opens the app via the provider's template
            // PendingIntent (launcher-style, reuses the existing task).
            views.setOnClickFillInIntent(R.id.widget_timing_row, Intent())

            applyRowTheme(views, isNow)
            return views
        }

        private fun applyRowTheme(views: RemoteViews, isNow: Boolean) {
            val isDark = forceDark
            views.setInt(
                R.id.widget_timing_row,
                "setBackgroundResource",
                when (isDark) {
                    true -> R.drawable.widget_item_background_dark
                    false -> R.drawable.widget_item_background_light
                    null -> R.drawable.widget_item_background
                },
            )
            val accent = WidgetSupport.accentColor(context, isDark)
            views.setTextColor(R.id.widget_timing_now, accent)
            if (isDark == null) {
                // System palette comes from the layout; only the accent (a
                // forced fixed color) was set above.
                if (isNow) {
                    views.setTextColor(
                        R.id.widget_timing_time,
                        ContextCompat.getColor(context, R.color.widget_primary_text),
                    )
                }
                return
            }
            val title = color(
                if (isDark) R.color.widget_title_text_dark else R.color.widget_title_text_light,
            )
            val secondary = color(
                if (isDark) R.color.widget_secondary_text_dark
                else R.color.widget_secondary_text_light,
            )
            views.setTextColor(R.id.widget_timing_name, title)
            views.setTextColor(R.id.widget_timing_time, if (isNow) accent else title)
            views.setTextColor(R.id.widget_timing_note, secondary)
        }

        private fun applySectionTheme(views: RemoteViews) {
            val isDark = forceDark ?: return
            views.setTextColor(
                R.id.widget_timing_section_header,
                color(
                    if (isDark) R.color.widget_primary_text_dark
                    else R.color.widget_primary_text_light,
                ),
            )
        }

        private fun color(resId: Int): Int = ContextCompat.getColor(context, resId)

        override fun getLoadingView(): RemoteViews? = null

        override fun getViewTypeCount(): Int = 2

        override fun getItemId(position: Int): Long = position.toLong()

        // Day rollover and the "now" marker shift rows; stable ids would
        // animate the wrong cards.
        override fun hasStableIds(): Boolean = false
    }
}
