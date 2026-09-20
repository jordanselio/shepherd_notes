package com.jordanselio.shepherd_notes

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget 2: small (2x2) current-or-next appointment. No live countdown --
 * widgets can't tick reliably -- just the duration, per the spec's
 * deliberate deviation from the mockup's "in 20 min".
 */
class NextUpWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val todayIso = WidgetDates.todayIso()
        val todaysAppointments = WidgetRepository.todaysAppointments(widgetData, todayIso)
        val nowMinutes = WidgetTime.nowMinutes()
        val emphasisById = WidgetEmphasis.compute(todaysAppointments, nowMinutes)
        val current = todaysAppointments.firstOrNull { emphasisById[it.id] == Emphasis.CURRENT }
        val next = current ?: todaysAppointments.firstOrNull { emphasisById[it.id] == Emphasis.NEXT }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_next_up)

            if (next == null) {
                views.setViewVisibility(R.id.next_up_time, android.view.View.GONE)
                views.setViewVisibility(R.id.next_up_name, android.view.View.GONE)
                views.setTextViewText(R.id.next_up_footer, "Nothing else today")
                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("shepherdwidget://today"),
                    ),
                )
            } else {
                views.setViewVisibility(R.id.next_up_time, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.next_up_name, android.view.View.VISIBLE)
                views.setTextViewText(R.id.next_up_time, WidgetTime.format12h(next.start))
                views.setTextViewText(R.id.next_up_name, next.name)
                views.setTextViewText(
                    R.id.next_up_footer,
                    WidgetTime.formatDuration(next.start, next.end),
                )
                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("shepherdwidget://appointment?id=${next.id}"),
                    ),
                )
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
