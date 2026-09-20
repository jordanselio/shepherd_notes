package com.jordanselio.shepherd_notes

import org.json.JSONArray

/**
 * A single day's occurrence of an appointment, already resolved by the
 * Flutter side (WidgetService, using the same rules as lib/utils/occurrence.dart).
 * Native code never re-derives recurrence -- it only filters this list by
 * date and time.
 */
data class AppointmentOccurrence(
    val id: Int,
    val name: String,
    val date: String, // yyyy-MM-dd
    val start: String, // HH:mm, 24h
    val end: String, // HH:mm, 24h
    val kind: String, // "bibleStudy" | "event"
    val type: String, // "individual" | "group"
)

/** An open task with a due date, as pushed by WidgetService. */
data class TodoItem(
    val id: Int,
    val title: String,
    val dueDate: String, // yyyy-MM-dd
    val appointmentName: String?,
)

/** Parses the JSON strings WidgetService stores via home_widget. */
object WidgetJson {
    fun parseAppointments(json: String?): List<AppointmentOccurrence> {
        if (json.isNullOrEmpty()) return emptyList()
        return try {
            val array = JSONArray(json)
            (0 until array.length()).mapNotNull { i ->
                val obj = array.optJSONObject(i) ?: return@mapNotNull null
                val date = obj.optString("date", "")
                val id = obj.optInt("id", -1)
                if (id < 0 || date.isEmpty()) return@mapNotNull null
                AppointmentOccurrence(
                    id = id,
                    name = obj.optString("name", ""),
                    date = date,
                    start = obj.optString("start", "00:00"),
                    end = obj.optString("end", "00:00"),
                    kind = obj.optString("kind", "bibleStudy"),
                    type = obj.optString("type", "individual"),
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun parseTodos(json: String?): List<TodoItem> {
        if (json.isNullOrEmpty()) return emptyList()
        return try {
            val array = JSONArray(json)
            (0 until array.length()).mapNotNull { i ->
                val obj = array.optJSONObject(i) ?: return@mapNotNull null
                val id = obj.optInt("id", -1)
                val dueDate = obj.optString("dueDate", "")
                if (id < 0 || dueDate.isEmpty()) return@mapNotNull null
                TodoItem(
                    id = id,
                    title = obj.optString("title", ""),
                    dueDate = dueDate,
                    appointmentName =
                        if (obj.isNull("appointmentName")) null
                        else obj.optString("appointmentName").ifEmpty { null },
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }
}
