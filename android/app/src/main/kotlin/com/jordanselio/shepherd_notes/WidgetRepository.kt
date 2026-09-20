package com.jordanselio.shepherd_notes

import android.content.SharedPreferences

/** Reads and filters the snapshot WidgetService (Dart) writes via home_widget. */
object WidgetRepository {
    const val appointmentsKey = "widget_appointments"
    const val todosKey = "widget_todos"

    fun allAppointments(widgetData: SharedPreferences): List<AppointmentOccurrence> {
        return WidgetJson.parseAppointments(widgetData.getString(appointmentsKey, null))
    }

    fun allTodos(widgetData: SharedPreferences): List<TodoItem> {
        return WidgetJson.parseTodos(widgetData.getString(todosKey, null))
    }

    fun todaysAppointments(
        widgetData: SharedPreferences,
        todayIso: String = WidgetDates.todayIso(),
    ): List<AppointmentOccurrence> {
        return allAppointments(widgetData)
            .filter { it.date == todayIso }
            .sortedBy { WidgetTime.toMinutes(it.start) }
    }

    /** Open to-dos due today or earlier (overdue), soonest due date first. */
    fun todosDueTodayOrOverdue(
        widgetData: SharedPreferences,
        todayIso: String = WidgetDates.todayIso(),
    ): List<TodoItem> {
        return allTodos(widgetData)
            .filter { it.dueDate <= todayIso }
            .sortedBy { it.dueDate }
    }

    /** Whether [isoDate] has at least one appointment, for the week strip dot. */
    fun hasAppointmentsOn(widgetData: SharedPreferences, isoDate: String): Boolean {
        return allAppointments(widgetData).any { it.date == isoDate }
    }
}
