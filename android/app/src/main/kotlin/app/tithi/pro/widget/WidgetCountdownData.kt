package app.tithi.pro.widget

import org.json.JSONArray
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/**
 * Shared parsing for the festival countdown widget, used by both the
 * [FestivalCountdownWidgetProvider] (header count) and the
 * [FestivalCountdownWidgetService] factory (list rows).
 *
 * Single-sourced so the midnight-recompute rule can't diverge between the two.
 * Bounded to [MAX_ITEMS]; payloads beyond that are truncated (memory cap).
 */
object WidgetCountdownData {

    const val KEY_DATA = "festival_widget_data"
    const val KEY_THEME = "widget_theme_override"
    const val PREFS_NAME = "HomeWidgetPreferences"
    const val MAX_ITEMS = 20

    private val ISO_FORMATTER: DateTimeFormatter =
        DateTimeFormatter.ofPattern("yyyy-MM-dd")

    data class WidgetItem(
        val title: String,
        val name: String,
        val daysRemaining: Int,
        val dateLabel: String,
        val statusLabel: String,
    )

    fun parseItems(jsonString: String?): List<WidgetItem> {
        if (jsonString.isNullOrBlank()) return emptyList()
        val array = try {
            JSONArray(jsonString)
        } catch (e: Exception) {
            return emptyList()
        }
        // Per-item isolation: one malformed object must not blank the whole
        // widget (the Dart side isolates per-ID for the same reason).
        return (0 until minOf(array.length(), MAX_ITEMS)).mapNotNull { i ->
            try {
                parseOne(array.getJSONObject(i))
            } catch (e: Exception) {
                null
            }
        }
    }

    private fun parseOne(obj: org.json.JSONObject): WidgetItem? {
        val dateIso = obj.optString("date", "")
        // Recompute from dateIso so the widget stays accurate after
        // midnight without requiring the app to run. A missing/unparseable
        // date has no truthful count — drop the row instead of freezing a
        // stale fallback number forever.
        val computedDays = recomputeDaysRemaining(dateIso)
            ?: return null
        // Drop passed festivals natively: the next occurrence (often next
        // year) can only be computed by the Dart/Jyotish engine, so until
        // the app syncs again the row would otherwise sit on "Passed"
        // forever. Hiding keeps the widget truthful; the empty view covers
        // the all-passed case.
        if (computedDays < 0) return null
        val storedDays = obj.optInt("daysRemaining", 0)
        val storedStatus = obj.optString("statusLabel", "")
        val statusLabel = when {
            // Fresh sync (same day count): keep the app-language label
            // the Dart side sent (see HomeWidgetService lang/status).
            computedDays == storedDays && storedStatus.isNotBlank() -> storedStatus
            computedDays == 0 -> todayLabel()
            computedDays == 1 -> tomorrowLabel()
            computedDays > 1 -> daysToGoLabel(computedDays)
            else -> storedStatus
        }
        return WidgetItem(
            title = obj.optString("title", obj.optString("name", "")),
            name = obj.optString("name", ""),
            daysRemaining = computedDays,
            dateLabel = obj.optString("dateLabel", ""),
            statusLabel = statusLabel,
        )
    }

    /**
     * Days from today to [dateIso], or null when the date is missing or
     * unparseable (the caller drops the row — a dateless row has no
     * truthful count, and keeping a stale fallback would freeze a wrong
     * number on the widget forever).
     */
    fun recomputeDaysRemaining(dateIso: String): Int? {
        if (dateIso.isBlank()) return null
        return try {
            val target = LocalDate.parse(dateIso, ISO_FORMATTER)
            val days = ChronoUnit.DAYS.between(LocalDate.now(), target)
            // Long→Int overflow guard (far-future dates): clamp instead of
            // wrapping to a negative that would wrongly drop the row.
            days.coerceIn(Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong()).toInt()
        } catch (e: Exception) {
            null
        }
    }

    /** Active (not yet passed) item count — keeps the header in sync with
     * the filtered list rows when the widget refreshes without the app. */
    fun activeCount(jsonString: String?): Int = parseItems(jsonString).size

    /** Device-language labels for post-midnight recomputes (app supports en/hi/bn/sa). */
    private fun deviceLanguage(): String =
        try {
            java.util.Locale.getDefault().language
        } catch (e: Exception) {
            "en"
        }

    fun todayLabel(): String = when (deviceLanguage()) {
        "hi" -> "आज"
        "bn" -> "আজ"
        "sa" -> "अद्य"
        else -> "Today"
    }

    fun tomorrowLabel(): String = when (deviceLanguage()) {
        "hi" -> "कल"
        "bn" -> "আগামীকাল"
        "sa" -> "श्वः"
        else -> "Tomorrow"
    }

    fun daysToGoLabel(days: Int): String = when (deviceLanguage()) {
        "hi" -> "$days दिन बाकी"
        "bn" -> "$days দিন বাকি"
        "sa" -> "$days दिनानि शेषाणि"
        else -> "$days days to go"
    }

    fun dayUnitLabel(days: Int): String {
        val singular = when (deviceLanguage()) {
            "hi", "bn" -> "दिन"
            "sa" -> "दिनम्"
            else -> "day"
        }
        val plural = when (deviceLanguage()) {
            "hi", "bn" -> "दिन"
            "sa" -> "दिनानि"
            else -> "days"
        }
        return if (days == 1) singular else plural
    }

    /** "Tue, Oct 21 • 12 days to go" style subtitle for a row. */
    fun dateText(item: WidgetItem): String =
        if (item.dateLabel.isNotBlank() && item.statusLabel.isNotBlank()) {
            "${item.dateLabel} • ${item.statusLabel}"
        } else if (item.dateLabel.isNotBlank()) {
            item.dateLabel
        } else {
            item.statusLabel
        }
}
