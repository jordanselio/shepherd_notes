import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../models/appointment.dart';

typedef NewPrayerRequestResult = ({String content, int? appointmentId});

/// Shows the "New Prayer Request" form. The Related Appointment field
/// defaults to None, so a prayer request never requires an appointment.
Future<NewPrayerRequestResult?> showNewPrayerRequestSheet(
  BuildContext context,
) {
  return showModalBottomSheet<NewPrayerRequestResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _NewPrayerRequestSheet(),
  );
}

class _NewPrayerRequestSheet extends StatefulWidget {
  const _NewPrayerRequestSheet();

  @override
  State<_NewPrayerRequestSheet> createState() =>
      _NewPrayerRequestSheetState();
}

class _NewPrayerRequestSheetState extends State<_NewPrayerRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  List<Appointment> _appointments = [];
  Appointment? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final appointments = await DatabaseHelper.instance.getAppointments();
    setState(() {
      _appointments = appointments;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New Prayer Request',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'What can we pray for?',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a prayer request'
                  : null,
            ),
            const SizedBox(height: 16),
            _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                : DropdownButtonFormField<Appointment?>(
                    initialValue: _selected,
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
                    onChanged: (value) => setState(() => _selected = value),
                  ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.of(context).pop((
                  content: _contentController.text.trim(),
                  appointmentId: _selected?.id,
                ));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
