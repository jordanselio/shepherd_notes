import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../theme/app_theme.dart';

const daysOfWeek = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Shows the "Add Bible Study / Add Event" chooser, then the form itself.
/// Returns the appointment to save, or null if the user backed out.
Future<Appointment?> showAddAppointmentFlow(BuildContext context) async {
  final kind = await showModalBottomSheet<AppointmentKind>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Add Bible Study'),
            onTap: () =>
                Navigator.of(context).pop(AppointmentKind.bibleStudy),
          ),
          ListTile(
            leading: Icon(
              Icons.event_outlined,
              color: categoryColors(context).amber,
            ),
            title: const Text('Add Event'),
            onTap: () => Navigator.of(context).pop(AppointmentKind.event),
          ),
        ],
      ),
    ),
  );
  if (kind == null || !context.mounted) return null;
  return showAppointmentFormSheet(context, initialKind: kind);
}

Future<Appointment?> showAppointmentFormSheet(
  BuildContext context, {
  Appointment? existing,
  AppointmentKind initialKind = AppointmentKind.bibleStudy,
}) {
  return showModalBottomSheet<Appointment>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AppointmentFormSheet(
      existing: existing,
      initialKind: initialKind,
    ),
  );
}

class _AppointmentFormSheet extends StatefulWidget {
  final Appointment? existing;
  final AppointmentKind initialKind;

  const _AppointmentFormSheet({this.existing, required this.initialKind});

  @override
  State<_AppointmentFormSheet> createState() => _AppointmentFormSheetState();
}

class _AppointmentFormSheetState extends State<_AppointmentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _groupSizeController;
  late AppointmentType _type;
  late AppointmentKind _kind;
  late RecurrenceType _recurrence;
  late String _dayOfWeek;
  late TimeOfDay _timeOfDay;
  late TimeOfDay _endTimeOfDay;
  late DateTime _specificDate;
  String? _timeError;

  /// Once the user manually picks an end time, we stop auto-adjusting it
  /// when the start time changes.
  bool _endManuallySet = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _locationController = TextEditingController(
      text: existing?.location ?? '',
    );
    _groupSizeController = TextEditingController(
      text: existing?.groupSize?.toString() ?? '',
    );
    _type = existing?.type ?? AppointmentType.individual;
    _kind = existing?.kind ?? widget.initialKind;
    _recurrence = existing?.recurrence ?? RecurrenceType.weekly;
    _dayOfWeek = existing?.dayOfWeek ?? daysOfWeek.first;
    _timeOfDay = existing != null
        ? _parseTime(existing.time)
        : const TimeOfDay(hour: 18, minute: 0);
    if (existing != null) {
      _endTimeOfDay = _parseTime(existing.endTime);
      _endManuallySet = true;
    } else {
      _endTimeOfDay = _addOneHour(_timeOfDay);
    }
    _specificDate = existing?.startDate != null
        ? DateTime.parse(existing!.startDate!)
        : DateTime.now();
  }

  TimeOfDay _addOneHour(TimeOfDay time) {
    final minutes = (time.hour * 60 + time.minute + 60) % (24 * 60);
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  int _minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTimeForStorage(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateForStorage(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final isEvent = _kind == AppointmentKind.event;
    final label = isEvent ? 'Event' : 'Bible Study';

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
                isEditing ? 'Edit $label' : 'New $label',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter a name'
                        : null,
              ),
              if (!isEvent) ...[
                const SizedBox(height: 16),
                SegmentedButton<AppointmentType>(
                  segments: const [
                    ButtonSegment(
                      value: AppointmentType.individual,
                      label: Text('1-on-1'),
                    ),
                    ButtonSegment(
                      value: AppointmentType.group,
                      label: Text('Group'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (selection) =>
                      setState(() => _type = selection.first),
                ),
                if (_type == AppointmentType.group) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _groupSizeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Group size (optional)',
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location (optional)',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RecurrenceType>(
                initialValue: _recurrence,
                decoration: const InputDecoration(labelText: 'Repeat'),
                items: const [
                  DropdownMenuItem(
                    value: RecurrenceType.none,
                    child: Text("Doesn't repeat"),
                  ),
                  DropdownMenuItem(
                    value: RecurrenceType.weekly,
                    child: Text('Weekly'),
                  ),
                  DropdownMenuItem(
                    value: RecurrenceType.custom,
                    child: Text('Custom'),
                  ),
                ],
                onChanged: (value) => setState(() => _recurrence = value!),
              ),
              const SizedBox(height: 16),
              if (_recurrence == RecurrenceType.none)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  trailing: Text(
                    '${_specificDate.month}/${_specificDate.day}/${_specificDate.year}',
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _specificDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _specificDate = picked);
                    }
                  },
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _dayOfWeek,
                  decoration: const InputDecoration(labelText: 'Day of week'),
                  items: daysOfWeek
                      .map(
                        (day) =>
                            DropdownMenuItem(value: day, child: Text(day)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _dayOfWeek = value!),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start Time'),
                      subtitle: Text(_timeOfDay.format(context)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _timeOfDay,
                        );
                        if (picked == null) return;
                        setState(() {
                          _timeOfDay = picked;
                          if (!_endManuallySet) {
                            _endTimeOfDay = _addOneHour(picked);
                          }
                          _timeError = null;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End Time'),
                      subtitle: Text(_endTimeOfDay.format(context)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _endTimeOfDay,
                        );
                        if (picked == null) return;
                        setState(() {
                          _endTimeOfDay = picked;
                          _endManuallySet = true;
                          _timeError = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_timeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _timeError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  if (_minutesOfDay(_endTimeOfDay) <=
                      _minutesOfDay(_timeOfDay)) {
                    setState(
                      () => _timeError = 'End time must be after start time',
                    );
                    return;
                  }
                  Navigator.of(context).pop(
                    Appointment(
                      id: widget.existing?.id,
                      name: _nameController.text.trim(),
                      type: _type,
                      kind: _kind,
                      recurrence: _recurrence,
                      dayOfWeek: _recurrence == RecurrenceType.none
                          ? null
                          : _dayOfWeek,
                      time: _formatTimeForStorage(_timeOfDay),
                      endTime: _formatTimeForStorage(_endTimeOfDay),
                      location: _locationController.text.trim().isEmpty
                          ? null
                          : _locationController.text.trim(),
                      startDate: _recurrence == RecurrenceType.none
                          ? _formatDateForStorage(_specificDate)
                          : null,
                      groupSize: _groupSizeController.text.trim().isEmpty
                          ? null
                          : int.tryParse(_groupSizeController.text.trim()),
                    ),
                  );
                },
                child: Text(isEditing ? 'Save Changes' : 'Add $label'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
