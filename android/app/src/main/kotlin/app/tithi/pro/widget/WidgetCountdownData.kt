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
        return try {
            val array = JSONArray(jsonString)
            (0 until minOf(array.length(), MAX_ITEMS)).mapNotNull { i ->
                val obj = array.getJSONObject(i)
                val dateIso = obj.optString("date", "")
                val storedDays = obj.optInt("daysRemaining", 0)
                // Recompute from dateIso so the widget stays accurate after
                // midnight without requiring the app to run.
                val computedDays = recomputeDaysRemaining(dateIso, storedDays)
                val storedStatus = obj.optString("statusLabel", "")
                val statusLabel = when {
                    computedDays == 0 -> "Today"
                    computedDays == 1 -> "Tomorrow"
                    computedDays > 1 -> "$computedDays days to go"
                    computedDays < 0 -> storedStatus.ifBlank { "Passed" }
                    else -> storedStatus
                }
                WidgetItem(
                    title = obj.optString("title", obj.optString("name", "")),
                    name = obj.optString("name", ""),
                    daysRemaining = computedDays,
                    dateLabel = obj.optString("dateLabel", ""),
                    statusLabel = statusLabel,
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun recomputeDaysRemaining(dateIso: String, fallback: Int): Int {
        if (dateIso.isBlank()) return fallback
        return try {
            val target = LocalDate.parse(dateIso, ISO_FORMATTER)
            ChronoUnit.DAYS.between(LocalDate.now(), target).toInt()
        } catch (e: Exception) {
            fallback
        }
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
