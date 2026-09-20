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
 * Widget 4: compact (~4x2), lock-screen-styled TODAY summary. Always renders
 * its own translucent dark panel regardless of system light/dark mode (it
 * sits on the wallpaper, not app chrome) -- see colors.xml's lock_widget_*
 * tokens, which have no values-night counterpart on purpose.
 */
class LockScreenTodayWidgetProvider : HomeWidgetProvider() {
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
        val remaining =
            todaysAppointments.filter { (emphasisById[it.id] ?: Emphasis.NORMAL) != Emphasis.PAST }
        val todos = WidgetRepository.todosDueTodayOrOverdue(widgetData, todayIso)

        val openToday =
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("shepherdwidget://today"),
            )

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_lock_today)
            views.setOnClickPendingIntent(R.id.widget_root, openToday)

            views.setTextViewText(R.id.lock_left_count, "${remaining.size} left")

            views.removeAllViews(R.id.lock_rows_container)
            if (remaining.isEmpty()) {
                views.setViewVisibility(R.id.lock_empty_text, View.VISIBLE)
                views.setTextViewText(
                    R.id.lock_empty_text,
                    if (todaysAppointments.isEmpty()) "Nothing scheduled today" else "All done for today",
                )
            } else {
                views.setViewVisibility(R.id.lock_empty_text, View.GONE)
                val shown = remaining.take(2)
                for (occurrence in shown) {
                    val emphasis = emphasisById[occurrence.id] ?: Emphasis.NORMAL
                    val isNext = emphasis == Emphasis.CURRENT || emphasis == Emphasis.NEXT
                    val row = RemoteViews(context.packageName, R.layout.widget_lock_appt_row)

                    row.setTextViewText(
                        R.id.lock_row_time,
                        "${WidgetTime.format12hNoSuffix(occurrence.start)} – " +
                            WidgetTime.format12h(occurrence.end),
                    )

                    val barColor =
                        if (isNext) {
                            ContextCompat.getColor(context, R.color.lock_widget_next_bar)
                        } else {
                            ContextCompat.getColor(
                                context,
                                WidgetCategory.lockColorRes(occurrence.kind, occurrence.type),
                            )
                        }
                    row.setInt(R.id.lock_row_bar, "setColorFilter", barColor)

                    row.setTextViewTextSize(
                        R.id.lock_row_name,
                        android.util.TypedValue.COMPLEX_UNIT_SP,
                        if (isNext) 18f else 16f,
                    )
                    // Bold only the NEXT/NOW row via a styled span -- RemoteViews has
                    // no reflection setter for TextView.setTypeface(int).
                    val name: CharSequence =
                        if (isNext) {
                            android.text.SpannableString(occurrence.name).apply {
                                setSpan(
                                    android.text.style.StyleSpan(android.graphics.Typeface.BOLD),
                                    0,
                                    length,
                                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
                                )
                            }
                        } else {
                            occurrence.name
                        }
                    row.setTextViewText(R.id.lock_row_name, name)

                    row.setViewVisibility(R.id.lock_row_badge, if (isNext) View.VISIBLE else View.GONE)
                    if (isNext) {
                        row.setTextViewText(
                            R.id.lock_row_badge,
                            if (emphasis == Emphasis.CURRENT) "NOW" else "NEXT",
                        )
                    }

                    views.addView(R.id.lock_rows_container, row)
                }
            }

            views.setTextViewText(R.id.lock_footer_text, "${todos.size} to-dos today")

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
