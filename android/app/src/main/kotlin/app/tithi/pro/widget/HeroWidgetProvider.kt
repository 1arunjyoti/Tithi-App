package app.tithi.pro.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import app.tithi.pro.R
import es.antonborri.home_widget.HomeWidgetProvider
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Hero-card home screen widget: the in-app PakshaHeroCard compressed to a
 * glance. The shell mirrors the app card (gradient + glow, tag/location pills,
 * inline weekday + secondary title, 44dp moon-phase tile, next-tithi pill);
 * the masa/nakshatra + sunrise/sunset footer keeps the extra glanceable info
 * the app puts in the detail sheet.
 *
 * The payload is pre-formatted and localized by Dart; this provider only
 * binds strings, draws the moon phase, and decides whether the stored day is
 * still today. A stale card (app not opened since yesterday) shows the refresh
 * prompt instead of yesterday's panchang, matching the countdown widget's
 * truthful-empty rule.
 *
 * Stateless: one RemoteViews per widget id, no static Context/views. The moon
 * bitmap is tiny (28dp) and rebuilt per update; no cache to leak.
 */
class HeroWidgetProvider : HomeWidgetProvider() {

    companion object {
        /** Moon diameter inside the 44dp tile, matching the app hero. */
        private const val MOON_DP = 28

        fun refreshAll(context: Context) {
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
                manager.getAppWidgetIds(
                    ComponentName(context, HeroWidgetProvider::class.java),
                )
            } catch (_: Exception) {
                return
            }
            ids.forEach { id ->
                try {
                    manager.updateAppWidget(id, buildViews(context, prefs))
                } catch (_: Exception) {
                    // One bad host never blocks the rest.
                }
            }
        }

        private fun buildViews(context: Context, prefs: SharedPreferences): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_hero)
            val theme = WidgetSupport.theme(context)
            val isDark = WidgetSupport.forcedDark(theme)
            val payload = PanchangWidgetData.parseHero(
                try {
                    prefs.getString(PanchangWidgetData.KEY_HERO, null)
                } catch (_: Exception) {
                    null
                },
            )

            views.setOnClickPendingIntent(
                R.id.widget_hero_container,
                WidgetSupport.launcherIntent(context),
            )
            applyShell(views, context, isDark)

            if (payload == null || payload.isStale) {
                views.setViewVisibility(R.id.widget_hero_content, View.GONE)
                views.setViewVisibility(R.id.widget_hero_stale, View.VISIBLE)
                views.setTextViewText(
                    R.id.widget_hero_stale_title,
                    payload?.refreshLabel?.takeIf { it.isNotBlank() }
                        ?: context.getString(R.string.widget_open_to_refresh),
                )
                applyTextColors(views, context, isDark)
                return views
            }

            views.setViewVisibility(R.id.widget_hero_content, View.VISIBLE)
            views.setViewVisibility(R.id.widget_hero_stale, View.GONE)

            bindHeader(views, payload)
            views.setTextViewText(
                R.id.widget_hero_title,
                titleText(context, payload, isDark),
            )

            views.setTextViewText(R.id.widget_hero_moon_title, payload.title)
            views.setTextViewText(R.id.widget_hero_phase, payload.phase)
            views.setImageViewBitmap(
                R.id.widget_hero_moon,
                moonBitmap(context, payload.illumination, payload.isShukla),
            )

            bindFestival(views, payload)
            bindChip(views, context, payload, isDark)
            bindFooter(views, payload)

            applyTextColors(views, context, isDark)
            return views
        }

        private fun bindHeader(views: RemoteViews, payload: PanchangWidgetData.HeroPayload) {
            val tag = payload.tag.trim()
            if (tag.isEmpty()) {
                views.setViewVisibility(R.id.widget_hero_tag_row, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_hero_tag_row, View.VISIBLE)
                // The app hero's eyebrow is uppercase in every language.
                views.setTextViewText(R.id.widget_hero_tag, tag.uppercase())
            }

            val location = payload.location.trim()
            if (location.isEmpty()) {
                views.setViewVisibility(R.id.widget_hero_location_pill, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_hero_location_pill, View.VISIBLE)
                views.setTextViewText(R.id.widget_hero_location, location)
            }
        }

        private fun bindFestival(
            views: RemoteViews,
            payload: PanchangWidgetData.HeroPayload,
        ) {
            val festival = payload.festival.trim()
            if (festival.isEmpty()) {
                views.setViewVisibility(R.id.widget_hero_festival, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_hero_festival, View.VISIBLE)
                views.setTextViewText(R.id.widget_hero_festival, festival)
            }
        }

        private fun bindChip(
            views: RemoteViews,
            context: Context,
            payload: PanchangWidgetData.HeroPayload,
            isDark: Boolean?,
        ) {
            val chip = chipText(context, payload, isDark)
            if (chip == null) {
                views.setViewVisibility(R.id.widget_hero_chip_pill, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_hero_chip_pill, View.VISIBLE)
                views.setTextViewText(R.id.widget_hero_chip, chip)
            }
        }

        private fun bindFooter(
            views: RemoteViews,
            payload: PanchangWidgetData.HeroPayload,
        ) {
            val footer = listOf(payload.detail.trim(), payload.sunLine.trim())
                .filter { it.isNotEmpty() }
                .joinToString(" · ")
            if (footer.isEmpty()) {
                views.setViewVisibility(R.id.widget_hero_footer, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_hero_footer, View.VISIBLE)
                views.setTextViewText(R.id.widget_hero_footer, footer)
            }
        }

        /**
         * Weekday in the base ink, secondary calendar inline. Hindu and Bengali
         * secondaries get the app hero's accent + italic treatment; Gregorian
         * stays in the base style.
         */
        private fun titleText(
            context: Context,
            payload: PanchangWidgetData.HeroPayload,
            isDark: Boolean?,
        ): CharSequence {
            val dark = isDark ?: WidgetSupport.systemDark(context)
            val accent = color(
                context,
                dark,
                R.color.widget_hero_accent_light,
                R.color.widget_hero_accent_dark,
            )
            val builder = SpannableStringBuilder().append(payload.weekday)
            val secondary = payload.secondary.trim()
            if (secondary.isEmpty()) return builder

            builder.append(", ")
            val start = builder.length
            builder.append(secondary)
            val end = builder.length
            if (payload.secondaryKind == "hindu" || payload.secondaryKind == "bengali") {
                builder.setSpan(
                    ForegroundColorSpan(accent),
                    start,
                    end,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                )
                builder.setSpan(
                    StyleSpan(Typeface.BOLD_ITALIC),
                    start,
                    end,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                )
            }
            return builder
        }

        /**
         * Transition chip with the tithi name accented. Falls back to the
         * pre-formatted single string for payloads written by older builds.
         */
        private fun chipText(
            context: Context,
            payload: PanchangWidgetData.HeroPayload,
            isDark: Boolean?,
        ): CharSequence? {
            val label = payload.chipText.trim()
            if (label.isEmpty()) {
                return payload.chip.trim().ifEmpty { null }
            }

            val dark = isDark ?: WidgetSupport.systemDark(context)
            val accent = color(
                context,
                dark,
                R.color.widget_hero_accent_light,
                R.color.widget_hero_accent_dark,
            )
            val builder = SpannableStringBuilder().append(label)
            val highlight = payload.chipHighlight.trim()
            if (highlight.isNotEmpty()) {
                builder.append(if (payload.chipInlineIcon) " → " else " ")
                val start = builder.length
                builder.append(highlight)
                val end = builder.length
                builder.setSpan(
                    ForegroundColorSpan(accent),
                    start,
                    end,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                )
                builder.setSpan(
                    StyleSpan(Typeface.BOLD),
                    start,
                    end,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                )
            }
            if (payload.chipSuffix.isNotEmpty()) {
                builder.append(payload.chipSuffix)
            }
            return builder
        }

        /**
         * Port of the app's MoonPhasePainter: a shadow disc, the right (waxing)
         * or left (waning) lit half, then an elliptical terminator that eats
         * into the crescent or adds the gibbous bulge.
         */
        private fun moonBitmap(
            context: Context,
            illumination: Double,
            isShukla: Boolean,
        ): Bitmap {
            val size = (MOON_DP * context.resources.displayMetrics.density)
                .roundToInt()
                .coerceAtLeast(1)
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val center = size / 2f
            val radius = size / 2f
            val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = ContextCompat.getColor(
                    context,
                    R.color.widget_hero_moon_shadow,
                )
            }
            val litPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = ContextCompat.getColor(context, R.color.widget_hero_moon_lit)
            }

            canvas.drawCircle(center, center, radius, shadowPaint)
            val phase = illumination.coerceIn(0.0, 1.0)
            if (phase <= 0.01) return bitmap
            if (phase >= 0.99) {
                canvas.drawCircle(center, center, radius, litPaint)
                return bitmap
            }

            canvas.save()
            // Model the lit side as the right half; waning rotates it left.
            if (!isShukla) canvas.rotate(180f, center, center)

            val disc = RectF(0f, 0f, size.toFloat(), size.toFloat())
            canvas.drawArc(disc, -90f, 180f, false, litPaint)

            val terminator = ((1 - 2 * phase) * radius).toFloat()
            val ellipse = RectF(
                center - abs(terminator),
                center - radius,
                center + abs(terminator),
                center + radius,
            )
            if (phase < 0.5) {
                // Crescent: erase the inner part of the lit half.
                canvas.drawArc(ellipse, -90f, 180f, false, shadowPaint)
            } else {
                // Gibbous: add the left bulge to the lit half.
                canvas.drawArc(ellipse, 90f, 180f, false, litPaint)
            }
            canvas.restore()
            return bitmap
        }

        private fun applyShell(
            views: RemoteViews,
            context: Context,
            isDark: Boolean?,
        ) {
            WidgetSupport.applyBackground(
                views,
                context,
                R.id.widget_hero_container,
                isDark,
                R.drawable.widget_hero_background_light,
                R.drawable.widget_hero_background_dark,
            )
            if (isDark == null) return

            val chip = if (isDark) {
                R.drawable.widget_hero_chip_background_dark
            } else {
                R.drawable.widget_hero_chip_background_light
            }
            views.setInt(R.id.widget_hero_location_pill, "setBackgroundResource", chip)
            views.setInt(R.id.widget_hero_chip_pill, "setBackgroundResource", chip)
            views.setInt(
                R.id.widget_hero_moon_tile,
                "setBackgroundResource",
                if (isDark) {
                    R.drawable.widget_hero_tile_background_dark
                } else {
                    R.drawable.widget_hero_tile_background_light
                },
            )
            views.setInt(
                R.id.widget_hero_festival,
                "setBackgroundResource",
                if (isDark) {
                    R.drawable.widget_hero_festival_background_dark
                } else {
                    R.drawable.widget_hero_festival_background_light
                },
            )
        }

        private fun applyTextColors(
            views: RemoteViews,
            context: Context,
            isDark: Boolean?,
        ) {
            // System mode leaves the night-qualified XML colors alone.
            if (isDark == null) return

            val text = color(
                context,
                isDark,
                R.color.widget_hero_text_light,
                R.color.widget_hero_text_dark,
            )
            val muted = color(
                context,
                isDark,
                R.color.widget_hero_muted_light,
                R.color.widget_hero_muted_dark,
            )
            val accent = color(
                context,
                isDark,
                R.color.widget_hero_accent_light,
                R.color.widget_hero_accent_dark,
            )

            views.setTextColor(R.id.widget_hero_tag_dot, accent)
            views.setTextColor(R.id.widget_hero_tag, muted)
            views.setTextColor(R.id.widget_hero_location, text)
            views.setTextColor(R.id.widget_hero_title, text)
            views.setTextColor(R.id.widget_hero_moon_title, text)
            views.setTextColor(R.id.widget_hero_phase, muted)
            views.setTextColor(R.id.widget_hero_chip, text)
            views.setTextColor(R.id.widget_hero_festival, accent)
            views.setTextColor(R.id.widget_hero_footer, muted)
            views.setTextColor(R.id.widget_hero_stale_title, text)

            views.setImageViewResource(
                R.id.widget_hero_location_icon,
                if (isDark) {
                    R.drawable.ic_widget_location_dark
                } else {
                    R.drawable.ic_widget_location_light
                },
            )
            views.setImageViewResource(
                R.id.widget_hero_chevron,
                if (isDark) {
                    R.drawable.ic_widget_chevron_dark
                } else {
                    R.drawable.ic_widget_chevron_light
                },
            )
        }

        private fun color(
            context: Context,
            isDark: Boolean,
            lightRes: Int,
            darkRes: Int,
        ): Int = ContextCompat.getColor(context, if (isDark) darkRes else lightRes)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        WidgetRefreshReceiver.ensureScheduled(context)
        appWidgetIds.forEach { id ->
            try {
                appWidgetManager.updateAppWidget(id, buildViews(context, widgetData))
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
