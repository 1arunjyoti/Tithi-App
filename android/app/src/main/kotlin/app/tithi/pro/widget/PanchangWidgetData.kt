package app.tithi.pro.widget

import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * Parsing for the panchang widgets (hero + the three timing widgets).
 *
 * The Dart side pre-computes and localizes every visible string; this object
 * only parses the two JSON documents and answers the two questions the widget
 * can answer truthfully without the ephemeris:
 *  - is the stored day still today? (hero staleness)
 *  - which window contains LocalDateTime.now()? (live "now" badge)
 *
 * All parses are bounded and defensive: a malformed document degrades the
 * widget to its empty state instead of crashing the launcher broadcast.
 */
object PanchangWidgetData {

    const val KEY_HERO = "hero_widget_data"
    const val KEY_TIMINGS = "timings_widget_data"
    const val PREFS_NAME = WidgetCountdownData.PREFS_NAME

    /** Section ids sent by Dart. */
    const val SECTION_AUSPICIOUS = "auspicious"
    const val SECTION_INAUSPICIOUS = "inauspicious"

    data class HeroPayload(
        val date: String,
        val tag: String,
        val weekday: String,
        val secondaryKind: String,
        val secondary: String,
        val illumination: Double,
        val isShukla: Boolean,
        val location: String,
        val title: String,
        val phase: String,
        val detail: String,
        val festival: String,
        val chip: String,
        val chipText: String,
        val chipHighlight: String,
        val chipSuffix: String,
        val chipInlineIcon: Boolean,
        val sunLine: String,
        val refreshLabel: String,
    ) {
        val isStale: Boolean
            get() = date != LocalDate.now().toString()
    }

    data class TimingRow(
        val section: String,
        val name: String,
        val time: String,
        val note: String,
        val start: LocalDateTime?,
        val end: LocalDateTime?,
    ) {
        fun contains(now: LocalDateTime): Boolean {
            val from = start ?: return false
            val to = end ?: return false
            return !now.isBefore(from) && now.isBefore(to)
        }
    }

    data class DayTimings(
        val date: String,
        val dateLabel: String,
        val sunLine: String,
        val rows: List<TimingRow>,
    ) {
        fun rowsFor(section: String): List<TimingRow> =
            rows.filter { it.section == section }
    }

    data class TimingsPayload(
        val refreshLabel: String,
        val auspiciousTitle: String,
        val inauspiciousTitle: String,
        val combinedTitle: String,
        val days: List<DayTimings>,
    ) {
        fun today(): DayTimings? {
            val today = LocalDate.now().toString()
            return days.firstOrNull { it.date == today }
        }
    }

    /** JSON numbers can be NaN/Infinity; the painter must never see those. */
    private fun sanitizeIllumination(value: Double): Double =
        if (value.isNaN() || value.isInfinite()) 0.0
        else value.coerceIn(0.0, 1.0)

    fun parseHero(jsonString: String?): HeroPayload? {
        if (jsonString.isNullOrBlank()) return null
        val obj = try {
            JSONObject(jsonString)
        } catch (_: Exception) {
            return null
        }
        return try {
            HeroPayload(
                date = obj.optString("date", ""),
                tag = obj.optString("tag", ""),
                weekday = obj.optString("weekday", ""),
                secondaryKind = obj.optString("secondaryKind", "none"),
                secondary = obj.optString("secondary", ""),
                illumination = sanitizeIllumination(
                    obj.optDouble("illumination", 0.0),
                ),
                isShukla = obj.optBoolean("isShukla", true),
                location = obj.optString("location", ""),
                title = obj.optString("title", ""),
                phase = obj.optString("phase", ""),
                detail = obj.optString("detail", ""),
                festival = obj.optString("festival", ""),
                chip = obj.optString("chip", ""),
                chipText = obj.optString("chipText", ""),
                chipHighlight = obj.optString("chipHighlight", ""),
                chipSuffix = obj.optString("chipSuffix", ""),
                chipInlineIcon = obj.optBoolean("chipInlineIcon", false),
                sunLine = obj.optString("sunLine", ""),
                refreshLabel = obj.optString("refreshLabel", ""),
            )
        } catch (_: Exception) {
            null
        }
    }

    fun parseTimings(jsonString: String?): TimingsPayload? {
        if (jsonString.isNullOrBlank()) return null
        val obj = try {
            JSONObject(jsonString)
        } catch (_: Exception) {
            return null
        }
        val days = try {
            val array = obj.optJSONArray("days") ?: JSONArray()
            (0 until array.length()).mapNotNull { i ->
                try {
                    parseDay(array.getJSONObject(i))
                } catch (_: Exception) {
                    null
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
        return try {
            TimingsPayload(
                refreshLabel = obj.optString("refreshLabel", ""),
                auspiciousTitle = obj.optString("auspiciousTitle", ""),
                inauspiciousTitle = obj.optString("inauspiciousTitle", ""),
                combinedTitle = obj.optString("combinedTitle", ""),
                days = days,
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun parseDay(obj: JSONObject): DayTimings? {
        val date = obj.optString("date", "")
        if (date.isBlank()) return null
        val rows = try {
            val array = obj.optJSONArray("rows") ?: JSONArray()
            (0 until array.length()).mapNotNull { i ->
                try {
                    parseRow(array.getJSONObject(i))
                } catch (_: Exception) {
                    null
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
        return DayTimings(
            date = date,
            dateLabel = obj.optString("dateLabel", ""),
            sunLine = obj.optString("sunLine", ""),
            rows = rows,
        )
    }

    private fun parseRow(obj: JSONObject): TimingRow? {
        val name = obj.optString("name", "")
        if (name.isBlank()) return null
        return TimingRow(
            section = obj.optString("section", ""),
            name = name,
            time = obj.optString("time", ""),
            note = obj.optString("note", ""),
            start = parseInstant(obj.optString("start", "")),
            end = parseInstant(obj.optString("end", "")),
        )
    }

    private fun parseInstant(value: String): LocalDateTime? {
        if (value.isBlank()) return null
        return try {
            LocalDateTime.parse(value)
        } catch (_: Exception) {
            null
        }
    }

    /** Current row in [rows], if any window contains now. */
    fun currentRow(rows: List<TimingRow>, now: LocalDateTime = LocalDateTime.now()): TimingRow? =
        rows.firstOrNull { it.contains(now) }

    /**
     * Epoch millis of the next window edge strictly after [now], for the
     * one-shot live-refresh alarm, or null when the day has no future edges.
     */
    fun nextBoundaryMillis(
        day: DayTimings?,
        now: LocalDateTime = LocalDateTime.now(),
    ): Long? {
        if (day == null) return null
        var next: LocalDateTime? = null
        day.rows.forEach { row ->
            listOfNotNull(row.start, row.end).forEach { edge ->
                val candidate = next
                if (edge.isAfter(now) && (candidate == null || edge.isBefore(candidate))) {
                    next = edge
                }
            }
        }
        return next?.atZone(java.time.ZoneId.systemDefault())?.toInstant()?.toEpochMilli()
    }
}
