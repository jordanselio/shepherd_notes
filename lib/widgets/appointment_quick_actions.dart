import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../models/appointment.dart';
import '../screens/appointment_form_sheet.dart';

/// Long-press quick actions (Edit / Delete) for an appointment, usable from
/// Schedule (day and week) and the Appointments list. Calls [onChanged]
/// after either action completes so the caller can reload its list.
Future<void> showAppointmentQuickActions(
  BuildContext context,
  Appointment appointment, {
  required VoidCallback onChanged,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                appointment.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit Appointment'),
            onTap: () => Navigator.of(context).pop('edit'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete Appointment'),
            onTap: () => Navigator.of(context).pop('delete'),
          ),
        ],
      ),
    ),
  );

  if (action == null || !context.mounted) return;

  if (action == 'edit') {
    final result = await showAppointmentFormSheet(context, existing: appointment);
    if (result == null) return;
    try {
      await DatabaseHelper.instance.updateAppointment(result);
    } catch (e) {
      debugPrint('Failed to save appointment: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save changes. Please try again.')),
        );
      }
      return;
    }
    onChanged();
  } else if (action == 'delete') {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${appointment.name}"?'),
        content: const Text(
          'This appointment and its schedule will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseHelper.instance.deleteAppointment(appointment.id!);
    onChanged();
  }
}
