import 'package:flutter/material.dart';

import '../models/appointment.dart';
import 'app_theme.dart';

/// The category color for an appointment: sage for 1-on-1 Bible studies,
/// lavender for group studies, amber for general events.
Color appointmentCategoryColor(BuildContext context, Appointment appointment) {
  final colors = categoryColors(context);
  if (appointment.kind == AppointmentKind.event) return colors.amber;
  return appointment.type == AppointmentType.group
      ? colors.lavender
      : colors.sage;
}

/// The pale tinted background to match [appointmentCategoryColor].
Color appointmentCategoryTint(BuildContext context, Appointment appointment) {
  final colors = categoryColors(context);
  if (appointment.kind == AppointmentKind.event) return colors.amberTint;
  return appointment.type == AppointmentType.group
      ? colors.lavenderTint
      : colors.sageTint;
}

/// Same mapping, but from the raw kind/type strings a joined SQL query
/// returns (e.g. Notes' session-with-appointment-name query), so callers
/// don't need to fetch the full [Appointment] just to color a dot.
Color categoryColorForKindType(
  BuildContext context, {
  required String kind,
  required String type,
}) {
  final colors = categoryColors(context);
  if (kind == 'event') return colors.amber;
  return type == 'group' ? colors.lavender : colors.sage;
}
