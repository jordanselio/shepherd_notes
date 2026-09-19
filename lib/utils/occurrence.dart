import '../models/appointment.dart';

const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String weekdayName(DateTime date) => weekdayNames[date.weekday - 1];

bool isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool appointmentOccursOn(Appointment appointment, DateTime date) {
  switch (appointment.recurrence) {
    case RecurrenceType.none:
      if (appointment.startDate == null) return false;
      return isSameDate(DateTime.parse(appointment.startDate!), date);
    case RecurrenceType.weekly:
    case RecurrenceType.custom:
      return appointment.dayOfWeek == weekdayName(date);
  }
}

/// Searches forward from [from] (inclusive) up to two weeks for the next date
/// this appointment occurs on.
DateTime? nextOccurrenceOnOrAfter(Appointment appointment, DateTime from) {
  for (var i = 0; i < 14; i++) {
    final candidate = DateTime(from.year, from.month, from.day + i);
    if (appointmentOccursOn(appointment, candidate)) return candidate;
  }
  return null;
}
