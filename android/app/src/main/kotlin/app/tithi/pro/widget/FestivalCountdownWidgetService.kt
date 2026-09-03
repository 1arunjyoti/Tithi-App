package app.tithi.pro.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import androidx.core.content.ContextCompat
import app.tithi.pro.R

/**
 * Collection backing for the festival countdown widget ListView.
 *
 * Every pinned countdown gets a row; the ListView scrolls internally when the
 * widget is too small, so cards are never hidden and no blank gap appears —
 * leftover space belongs to the list itself.
 *
 * Memory: the factory caches at most [WidgetCountdownData.MAX_ITEMS] small
 * data objects, re-parsed only in [onCreate]/[onDataSetChanged] (i.e. on
 * notifyAppWidgetViewDataChanged). [onDestroy] drops the reference.
 * No static Context or views are held.
 */
class FestivalCountdownWidgetService : RemoteViewsService() {

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        CountdownFactory(applicationContext)

    class CountdownFactory(
        private val context: Context,
    ) : RemoteViewsFactory {

        private var items: List<WidgetCountdownData.WidgetItem> = emptyList()
        private var forceDark: Boolean? = null // null = system (night resources)

        override fun onCreate() = load()

        override fun onDataSetChanged() = load()

        private fun load() {
            val prefs = context.getSharedPreferences(
                WidgetCountdownData.PREFS_NAME,
                Context.MODE_PRIVATE,
            )
            items = WidgetCountdownData.parseItems(
                prefs.getString(WidgetCountdownData.KEY_DATA, null),
            )
            forceDark = when (prefs.getString(WidgetCountdownData.KEY_THEME, "system")) {
                "dark" -> true
                "light" -> false
                else -> null
            }
        }

        override fun onDestroy() {
            items = emptyList()
        }

        override fun getCount(): Int = items.size

        override fun getViewAt(position: Int): RemoteViews {
            val item = items.getOrNull(position)
            val views = RemoteViews(context.packageName, R.layout.widget_festival_item)
            if (item != null) {
                views.setTextViewText(
                    R.id.widget_days,
                    item.daysRemaining.coerceAtLeast(0).toString(),
                )
                views.setTextViewText(
                    R.id.widget_days_label,
                    if (item.daysRemaining == 1) "day" else "days",
                )
                views.setTextViewText(
                    R.id.widget_name,
                    if (item.name.isNotBlank()) item.name else item.title,
                )
                views.setTextViewText(R.id.widget_date, WidgetCountdownData.dateText(item))

                // Tap a row opens the app (template PendingIntent set in provider).
                val fillIn = Intent().apply {
                    data = Uri.parse("tithi://festival/$position")
                }
                views.setOnClickFillInIntent(R.id.widget_row, fillIn)
            }

            // Theme applies to EVERY row view, including the out-of-range
            // fallback above — otherwise a recycled blank row can keep the
            // previous palette while the rest of the widget has switched.
            // System (null) uses night resources as-is.
            when (forceDark) {
                true -> applyRowTheme(views, isDark = true)
                false -> applyRowTheme(views, isDark = false)
                null -> Unit
            }
            return views
        }

        private fun applyRowTheme(views: RemoteViews, isDark: Boolean) {
            fun c(light: Int, dark: Int): Int =
                ContextCompat.getColor(context, if (isDark) dark else light)
            views.setInt(
                R.id.widget_row,
                "setBackgroundResource",
                if (isDark) R.drawable.widget_item_background_dark
                else R.drawable.widget_item_background_light,
            )
            views.setInt(
                R.id.widget_badge,
                "setBackgroundResource",
                if (isDark) R.drawable.widget_badge_background_dark
                else R.drawable.widget_badge_background_light,
            )
            val primary = c(
                R.color.widget_primary_text_light,
                R.color.widget_primary_text_dark,
            )
            val title = c(
                R.color.widget_title_text_light,
                R.color.widget_title_text_dark,
            )
            val secondary = c(
                R.color.widget_secondary_text_light,
                R.color.widget_secondary_text_dark,
            )
            views.setTextColor(R.id.widget_days, primary)
            views.setTextColor(R.id.widget_days_label, primary)
            views.setTextColor(R.id.widget_name, title)
            views.setTextColor(R.id.widget_date, secondary)
        }

        override fun getLoadingView(): RemoteViews? = null

        override fun getViewTypeCount(): Int = 1

        override fun getItemId(position: Int): Long = position.toLong()

        override fun hasStableIds(): Boolean = true
    }
}
