import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../models/appointment.dart';
import '../models/task.dart';

typedef TodoFormResult =
    ({String title, String? dueDate, int? appointmentId});

/// Shows the New/Edit To-do form. Due date defaults to none; Related
/// Appointment defaults to None, same pattern as New Prayer Request.
Future<TodoFormResult?> showTodoFormSheet(
  BuildContext context, {
  Task? existing,
}) {
  return showModalBottomSheet<TodoFormResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _TodoFormSheet(existing: existing),
  );
}

class _TodoFormSheet extends StatefulWidget {
  final Task? existing;

  const _TodoFormSheet({this.existing});

  @override
  State<_TodoFormSheet> createState() => _TodoFormSheetState();
}

class _TodoFormSheetState extends State<_TodoFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  DateTime? _dueDate;
  List<Appointment> _appointments = [];
  Appointment? _selectedAppointment;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _dueDate = existing?.dueDate != null
        ? DateTime.parse(existing!.dueDate!)
        : null;
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final appointments = await DatabaseHelper.instance.getAppointments();
    Appointment? selected;
    final existingId = widget.existing?.appointmentId;
    if (existingId != null) {
      for (final appointment in appointments) {
        if (appointment.id == existingId) selected = appointment;
      }
    }
    setState(() {
      _appointments = appointments;
      _selectedAppointment = selected;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _isoDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _dueDate = DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final isToday = _dueDate != null && _isSameDate(_dueDate!, today);
    final isTomorrow = _dueDate != null && _isSameDate(_dueDate!, tomorrow);
    final isCustom = _dueDate != null && !isToday && !isTomorrow;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Edit To-do' : 'New To-do',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a title'
                    : null,
              ),
              const SizedBox(height: 16),
              const Text('Due date'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Today'),
                    selected: isToday,
                    onSelected: (_) => setState(() => _dueDate = today),
                  ),
                  ChoiceChip(
                    label: const Text('Tomorrow'),
                    selected: isTomorrow,
                    onSelected: (_) => setState(() => _dueDate = tomorrow),
                  ),
                  ChoiceChip(
                    label: Text(
                      isCustom
                          ? DateFormat('MMM d').format(_dueDate!)
                          : 'Pick date',
                    ),
                    selected: isCustom,
                    onSelected: (_) => _pickDate(),
                  ),
                  ChoiceChip(
                    label: const Text('No date'),
                    selected: _dueDate == null,
                    onSelected: (_) => setState(() => _dueDate = null),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    )
                  : DropdownButtonFormField<Appointment?>(
                      initialValue: _selectedAppointment,
                      decoration: const InputDecoration(
                        labelText: 'Related Appointment',
                      ),
                      items: [
                        const DropdownMenuItem<Appointment?>(
                          value: null,
                          child: Text('None'),
                        ),
                        for (final appointment in _appointments)
                          DropdownMenuItem<Appointment?>(
                            value: appointment,
                            child: Text(appointment.name),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedAppointment = value),
                    ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.of(context).pop((
                          title: _titleController.text.trim(),
                          dueDate: _dueDate != null
                              ? _isoDate(_dueDate!)
                              : null,
                          appointmentId: _selectedAppointment?.id,
                        ));
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
