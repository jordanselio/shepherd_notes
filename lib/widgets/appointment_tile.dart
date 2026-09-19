import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../theme/app_theme.dart';
import '../theme/category_color.dart';
import '../utils/time_format.dart';

class AppointmentTile extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const AppointmentTile({
    super.key,
    required this.appointment,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        appointment.type == AppointmentType.individual
            ? Icons.person
            : Icons.groups,
        color: scheme.onSurfaceVariant,
      ),
      title: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: appointmentCategoryColor(context, appointment),
              shape: BoxShape.circle,
            ),
          ),
          Flexible(
            child: Text(
              appointment.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${formatStoredTime(appointment.time)} – ${formatStoredTime(appointment.endTime)}',
        style: tabularNums(
          TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
