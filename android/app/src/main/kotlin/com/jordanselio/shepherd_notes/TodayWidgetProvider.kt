package com.jordanselio.shepherd_notes

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget 1: large TODAY agenda (~4x3, resizable). Mini week strip, today's
 * appointments (current/next emphasized, past de-emphasized), and up to 2
 * open to-dos due today or overdue.
 */
class TodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val todayIso = WidgetDates.todayIso()
        val todaysAppointments = WidgetRepository.todaysAppointments(widgetData, todayIso)
        val todos = WidgetRepository.todosDueTodayOrOverdue(widgetData, todayIso)
        val nowMinutes = WidgetTime.nowMinutes()
        val emphasisById = WidgetEmphasis.compute(todaysAppointments, nowMinutes)
        val weekDates = WidgetDates.currentWeekIsoDates()

        val hasAppointments = todaysAppointments.isNotEmpty()
        val allPast =
            hasAppointments &&
                todaysAppointments.all { (emphasisById[it.id] ?: Emphasis.NORMAL) == Emphasis.PAST }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_today)

            views.setTextViewText(R.id.today_date, WidgetDates.formatHeaderDate(todayIso))
            val openToday =
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("shepherdwidget://today"),
                )
            views.setOnClickPendingIntent(R.id.today_header_tap, openToday)
            views.setOnClickPendingIntent(
                R.id.plus_button,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("shepherdwidget://newAppointment"),
                ),
            )

            buildWeekStrip(context, views, weekDates, todayIso, widgetData)
            buildAgenda(
                context,
                views,
                todaysAppointments,
                emphasisById,
                hasAppointments,
                allPast,
            )
            buildTodoSection(context, views, todos)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun buildWeekStrip(
        context: Context,
        views: RemoteViews,
        weekDates: List<String>,
        todayIso: String,
        widgetData: SharedPreferences,
    ) {
        views.removeAllViews(R.id.week_strip_container)
        for (date in weekDates) {
            val cell = RemoteViews(context.packageName, R.layout.widget_week_cell)
            cell.setTextViewText(R.id.week_cell_letter, WidgetDates.weekdayLetter(date))
            cell.setTextViewText(R.id.week_cell_number, WidgetDates.dayOfMonth(date).toString())

            val isToday = date == todayIso
            cell.setViewVisibility(R.id.week_cell_today_bg, if (isToday) View.VISIBLE else View.GONE)
            cell.setTextColor(
                R.id.week_cell_letter,
                ContextCompat.getColor(
                    context,
                    if (isToday) R.color.widget_blue_text else R.color.widget_text_secondary,
                ),
            )
            cell.setTextColor(
                R.id.week_cell_number,
                ContextCompat.getColor(
                    context,
                    if (isToday) R.color.widget_on_blue_fill else R.color.widget_text,
                ),
            )

            val hasAppointment = WidgetRepository.hasAppointmentsOn(widgetData, date)
            cell.setViewVisibility(
                R.id.week_cell_dot,
                if (hasAppointment && !isToday) View.VISIBLE else View.INVISIBLE,
            )
            views.addView(R.id.week_strip_container, cell)
        }
    }

    private fun buildAgenda(
        context: Context,
        views: RemoteViews,
        todaysAppointments: List<AppointmentOccurrence>,
        emphasisById: Map<Int, Emphasis>,
        hasAppointments: Boolean,
        allPast: Boolean,
    ) {
        views.removeAllViews(R.id.agenda_container)

        if (!hasAppointments) {
            views.setViewVisibility(R.id.empty_state_text, View.VISIBLE)
            views.setTextViewText(R.id.empty_state_text, "Nothing scheduled today")
            return
        }
        if (allPast) {
            views.setViewVisibility(R.id.empty_state_text, View.VISIBLE)
            views.setTextViewText(R.id.empty_state_text, "All done for today")
            return
        }
        views.setViewVisibility(R.id.empty_state_text, View.GONE)

        val maxRows = 4
        for (occurrence in todaysAppointments.take(maxRows)) {
            val row = RemoteViews(context.packageName, R.layout.widget_agenda_row)
            val emphasis = emphasisById[occurrence.id] ?: Emphasis.NORMAL
            val emphasized = emphasis == Emphasis.CURRENT || emphasis == Emphasis.NEXT
            val isPast = emphasis == Emphasis.PAST

            row.setTextViewText(R.id.agenda_time, WidgetTime.format12h(occurrence.start))
            row.setTextColor(
                R.id.agenda_time,
                ContextCompat.getColor(
                    context,
                    if (emphasized) R.color.widget_blue_text else R.color.widget_text_secondary,
                ),
            )

            row.setTextViewText(R.id.agenda_name, occurrence.name)
            row.setTextColor(
                R.id.agenda_name,
                ContextCompat.getColor(
                    context,
                    if (isPast) R.color.widget_text_secondary else R.color.widget_text,
                ),
            )

            val dotColorRes =
                if (emphasized) R.color.widget_blue_fill
                else WidgetCategory.colorRes(occurrence.kind, occurrence.type)
            row.setInt(R.id.agenda_dot, "setColorFilter", ContextCompat.getColor(context, dotColorRes))

            if (emphasized) {
                row.setViewVisibility(R.id.agenda_badge, View.VISIBLE)
                row.setTextViewText(R.id.agenda_badge, if (emphasis == Emphasis.CURRENT) "NOW" else "NEXT")
            } else {
                row.setViewVisibility(R.id.agenda_badge, View.GONE)
            }

            row.setTextViewText(
                R.id.agenda_duration,
                WidgetTime.formatDuration(occurrence.start, occurrence.end),
            )

            row.setOnClickPendingIntent(
                R.id.agenda_row_root,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("shepherdwidget://appointment?id=${occurrence.id}"),
                ),
            )
            views.addView(R.id.agenda_container, row)
        }
    }

    private fun buildTodoSection(
        context: Context,
        views: RemoteViews,
        todos: List<TodoItem>,
    ) {
        val hasTodos = todos.isNotEmpty()
        views.setViewVisibility(R.id.todo_divider, if (hasTodos) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.todo_header_label, if (hasTodos) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.todo_header_label, "TO-DO · ${todos.size} TODAY")

        views.removeAllViews(R.id.todo_container)
        val openTodoTab =
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("shepherdwidget://todoTab"),
            )
        val maxRows = 2
        val shown = todos.take(maxRows)
        for (todo in shown) {
            val row = RemoteViews(context.packageName, R.layout.widget_todo_row)
            row.setTextViewText(R.id.todo_row_title, todo.title)
            row.setOnClickPendingIntent(R.id.todo_row_root, openTodoTab)
            views.addView(R.id.todo_container, row)
        }

        val overflow = todos.size - shown.size
        if (overflow > 0) {
            views.setViewVisibility(R.id.todo_more_text, View.VISIBLE)
            views.setTextViewText(R.id.todo_more_text, "+$overflow more")
        } else {
            views.setViewVisibility(R.id.todo_more_text, View.GONE)
        }
    }
}
