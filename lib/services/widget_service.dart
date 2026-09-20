import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../data/database_helper.dart';
import '../models/task.dart';
import '../utils/occurrence.dart';

/// Keeps the Android home-screen widgets in sync with the database.
///
/// Native widget code never resolves recurrence itself: this service
/// resolves every appointment occurrence in [_windowDays] using the exact
/// same rules as [occurrence.dart] (the Week view's source of truth) and
/// hands the native side a pre-resolved, already-dated list. Native code
/// only ever filters that list by the current date/time when it renders, so
/// it stays correct between syncs (including across a day rollover) without
/// needing a copy of the occurrence rules.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const appointmentsKey = 'widget_appointments';
  static const todosKey = 'widget_todos';

  /// Class names of every native AppWidgetProvider, resolved against the
  /// app's package id by home_widget.
  static const providerNames = [
    'TodayWidgetProvider',
    'NextUpWidgetProvider',
    'TodoWidgetProvider',
    'LockScreenTodayWidgetProvider',
  ];

  static const _windowDays = 30;

  /// Rebuilds the widget data snapshot, pushes it to every widget, and
  /// (re)arms the native wake-up schedule for today's remaining appointment
  /// boundaries and the next midnight rollover. Never throws -- widgets are
  /// a supplementary surface and a sync hiccup must not break the app.
  Future<void> refreshWidgets() async {
    try {
      final db = DatabaseHelper.instance;
      final appointments = await db.getAppointments();
      final taskRows = await db.getAllTasksWithAppointmentInfo();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final occurrences = <Map<String, Object?>>[];
      for (var i = 0; i < _windowDays; i++) {
        final date = today.add(Duration(days: i));
        for (final appointment in appointments) {
          if (!appointmentOccursOn(appointment, date)) continue;
          occurrences.add({
            'id': appointment.id,
            'name': appointment.name,
            'date': _isoDate(date),
            'start': appointment.time,
            'end': appointment.endTime,
            'kind': appointment.kind.name,
            'type': appointment.type.name,
          });
        }
      }

      final todos = <Map<String, Object?>>[];
      for (final row in taskRows) {
        final task = Task.fromMap(row);
        if (task.isDone || task.dueDate == null) continue;
        todos.add({
          'id': task.id,
          'title': task.title,
          'dueDate': task.dueDate,
          'appointmentName': row['appointmentName'] as String?,
        });
      }

      await Future.wait([
        HomeWidget.saveWidgetData<String>(
          appointmentsKey,
          jsonEncode(occurrences),
        ),
        HomeWidget.saveWidgetData<String>(todosKey, jsonEncode(todos)),
      ]);

      await Future.wait([
        for (final name in providerNames)
          HomeWidget.updateWidget(androidName: name),
      ]);

      await _scheduleWakeTimes(occurrences, today, now);
    } catch (error, stack) {
      debugPrint('WidgetService.refreshWidgets failed: $error\n$stack');
    }
  }

  /// Arms a wake-up at the next local midnight and at every still-upcoming
  /// start/end boundary of today's appointments, so NEXT/NOW and the "N
  /// left" counts move on time without a live countdown or 30-minute poll.
  Future<void> _scheduleWakeTimes(
    List<Map<String, Object?>> occurrences,
    DateTime today,
    DateTime now,
  ) async {
    final todayIso = _isoDate(today);
    final nextMidnight = today.add(const Duration(days: 1));

    final wakeTimes = <DateTime>{nextMidnight};
    for (final occurrence in occurrences) {
      if (occurrence['date'] != todayIso) continue;
      final start = _timeOn(today, occurrence['start'] as String);
      final end = _timeOn(today, occurrence['end'] as String);
      if (start.isAfter(now)) wakeTimes.add(start);
      if (end.isAfter(now)) wakeTimes.add(end);
    }

    final sorted = wakeTimes.toList()..sort();
    for (final name in providerNames) {
      await HomeWidget.scheduleWidgetUpdates(sorted, androidName: name);
    }
  }

  DateTime _timeOn(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  String _isoDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
