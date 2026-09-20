package com.jordanselio.shepherd_notes

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget 3: small (2x2) to-do list. The checkbox on each of the (up to 2)
 * rows completes that task in the background via home_widget's
 * interactivity callback -- no app launch needed -- then the Dart side
 * refreshes every widget once the write lands.
 */
class TodoWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val todos = WidgetRepository.todosDueTodayOrOverdue(widgetData)
        val openTodoTab =
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("shepherdwidget://todoTab"),
            )

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_todo)

            views.setTextViewText(R.id.todo_count, todos.size.toString())
            views.setTextViewText(R.id.todo_count_label, "today")
            views.setOnClickPendingIntent(R.id.todo_header, openTodoTab)
            views.setOnClickPendingIntent(R.id.widget_root, openTodoTab)

            views.removeAllViews(R.id.todo_rows_container)
            for (todo in todos.take(2)) {
                val row = RemoteViews(context.packageName, R.layout.widget_todo_row)
                row.setTextViewText(R.id.todo_row_title, todo.title)
                row.setOnClickPendingIntent(
                    R.id.todo_row_checkbox,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("shepherdwidget://completeTodo?id=${todo.id}"),
                    ),
                )
                row.setOnClickPendingIntent(R.id.todo_row_content, openTodoTab)
                views.addView(R.id.todo_rows_container, row)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
