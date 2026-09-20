package com.jordanselio.shepherd_notes

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** Where an occurrence sits relative to "now" -- mirrors _Emphasis in schedule_screen.dart. */
enum class Emphasis { NORMAL, PAST, CURRENT, NEXT }

object WidgetDates {
    private fun isoFormat() = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    fun todayIso(): String = isoFormat().format(Date())

    fun parseIso(isoDate: String): Calendar {
        val parts = isoDate.split("-")
        val cal = Calendar.getInstance()
        cal.clear()
        cal.set(parts[0].toInt(), parts[1].toInt() - 1, parts[2].toInt())
        return cal
    }

    fun isoOf(cal: Calendar): String = isoFormat().format(cal.time)

    /** Monday..Sunday ISO dates for the week containing today. */
    fun currentWeekIsoDates(): List<String> {
        val cal = Calendar.getInstance()
        // Calendar.DAY_OF_WEEK: 1=Sunday..7=Saturday. Roll back to Monday.
        val weekday = cal.get(Calendar.DAY_OF_WEEK)
        val daysSinceMonday = (weekday + 5) % 7
        cal.add(Calendar.DAY_OF_YEAR, -daysSinceMonday)
        return (0 until 7).map { i ->
            val c = cal.clone() as Calendar
            c.add(Calendar.DAY_OF_YEAR, i)
            isoOf(c)
        }
    }

    /** Single-letter weekday label ("M", "T", ...), matching the app's own week strip. */
    fun weekdayLetter(isoDate: String): String {
        val fmt = SimpleDateFormat("EEE", Locale.US)
        val label = fmt.format(parseIso(isoDate).time)
        return label.substring(0, 1).uppercase(Locale.US)
    }

    fun dayOfMonth(isoDate: String): Int = parseIso(isoDate).get(Calendar.DAY_OF_MONTH)

    /** "Tue, Sep 15" */
    fun formatHeaderDate(isoDate: String): String {
        val fmt = SimpleDateFormat("EEE, MMM d", Locale.US)
        return fmt.format(parseIso(isoDate).time)
    }

    /** "Sep 15" for a to-do's due date, used nowhere visually today but kept for parity/debug. */
    fun formatShortDate(isoDate: String): String {
        val fmt = SimpleDateFormat("MMM d", Locale.US)
        return fmt.format(parseIso(isoDate).time)
    }
}

object WidgetTime {
    fun toMinutes(hhmm: String): Int {
        val parts = hhmm.split(":")
        return parts[0].toInt() * 60 + parts[1].toInt()
    }

    fun nowMinutes(): Int {
        val cal = Calendar.getInstance()
        return cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
    }

    /** "12:30" -> "12:30 PM" */
    fun format12h(hhmm: String): String {
        val minutes = toMinutes(hhmm)
        val hour24 = minutes / 60
        val minute = minutes % 60
        val amPm = if (hour24 >= 12) "PM" else "AM"
        var hour12 = hour24 % 12
        if (hour12 == 0) hour12 = 12
        return String.format(Locale.US, "%d:%02d %s", hour12, minute, amPm)
    }

    /** "12:30" -> "12:30" (no am/pm), for the lock widget's "start – end AM/PM" pairing. */
    fun format12hNoSuffix(hhmm: String): String {
        val minutes = toMinutes(hhmm)
        val hour24 = minutes / 60
        val minute = minutes % 60
        var hour12 = hour24 % 12
        if (hour12 == 0) hour12 = 12
        return String.format(Locale.US, "%d:%02d", hour12, minute)
    }

    /** "1h", "45m", "1h 30m" */
    fun formatDuration(startHHmm: String, endHHmm: String): String {
        val start = toMinutes(startHHmm)
        var end = toMinutes(endHHmm)
        if (end < start) end += 24 * 60
        val total = end - start
        val hours = total / 60
        val minutes = total % 60
        return when {
            hours > 0 && minutes > 0 -> "${hours}h ${minutes}m"
            hours > 0 -> "${hours}h"
            else -> "${minutes}m"
        }
    }
}

object WidgetEmphasis {
    /** Computes NOW/NEXT/PAST for today's occurrences, mirroring
     * _computeEmphasis in schedule_screen.dart. */
    fun compute(
        todayOccurrences: List<AppointmentOccurrence>,
        nowMinutes: Int,
    ): Map<Int, Emphasis> {
        val result = mutableMapOf<Int, Emphasis>()
        val current =
            todayOccurrences.firstOrNull {
                WidgetTime.toMinutes(it.start) <= nowMinutes && nowMinutes < WidgetTime.toMinutes(it.end)
            }
        val next =
            if (current == null) {
                todayOccurrences
                    .filter { WidgetTime.toMinutes(it.start) > nowMinutes }
                    .minByOrNull { WidgetTime.toMinutes(it.start) }
            } else {
                null
            }
        for (occurrence in todayOccurrences) {
            result[occurrence.id] =
                when {
                    current != null && occurrence.id == current.id -> Emphasis.CURRENT
                    next != null && occurrence.id == next.id -> Emphasis.NEXT
                    WidgetTime.toMinutes(occurrence.end) <= nowMinutes -> Emphasis.PAST
                    else -> Emphasis.NORMAL
                }
        }
        return result
    }
}

object WidgetCategory {
    fun colorRes(kind: String, type: String): Int {
        if (kind == "event") return R.color.widget_category_amber
        return if (type == "group") R.color.widget_category_lavender else R.color.widget_category_sage
    }

    fun lockColorRes(kind: String, type: String): Int {
        if (kind == "event") return R.color.lock_widget_category_amber
        return if (type == "group") R.color.lock_widget_category_lavender else R.color.lock_widget_category_sage
    }
}
