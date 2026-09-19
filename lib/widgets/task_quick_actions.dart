import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../models/task.dart';
import '../screens/todo_form_sheet.dart';

/// Long-press quick actions (Edit / Delete) for a to-do, same pattern as
/// [showAppointmentQuickActions]. Calls [onChanged] after either action
/// completes so the caller can reload its list.
Future<void> showTaskQuickActions(
  BuildContext context,
  Task task, {
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
                task.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit To-do'),
            onTap: () => Navigator.of(context).pop('edit'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete To-do'),
            onTap: () => Navigator.of(context).pop('delete'),
          ),
        ],
      ),
    ),
  );

  if (action == null || !context.mounted) return;

  if (action == 'edit') {
    final result = await showTodoFormSheet(context, existing: task);
    if (result == null) return;
    await DatabaseHelper.instance.updateTask(
      task.copyWith(
        title: result.title,
        dueDate: result.dueDate,
        clearDueDate: result.dueDate == null,
        appointmentId: result.appointmentId,
        clearAppointmentId: result.appointmentId == null,
        updatedAt: DateTime.now(),
      ),
    );
    onChanged();
  } else if (action == 'delete') {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${task.title}"?'),
        content: const Text('This to-do will be removed.'),
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
    await DatabaseHelper.instance.deleteTask(task.id!);
    onChanged();
  }
}
