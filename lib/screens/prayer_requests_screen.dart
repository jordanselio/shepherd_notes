import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../models/prayer_request.dart';
import '../theme/app_theme.dart';
import '../widgets/segmented_toggle.dart';
import 'appointment_detail_screen.dart';
import 'prayer_request_form_sheet.dart';

enum _PrayerFilter { active, answered }

class PrayerRequestsScreen extends StatefulWidget {
  const PrayerRequestsScreen({super.key});

  @override
  State<PrayerRequestsScreen> createState() => _PrayerRequestsScreenState();
}

class _PrayerRequestsScreenState extends State<PrayerRequestsScreen> {
  final _db = DatabaseHelper.instance;
  List<PrayerRequest> _requests = [];
  List<String?> _appointmentNames = [];
  bool _loading = true;
  _PrayerFilter _filter = _PrayerFilter.active;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final rows = await _db.getAllPrayerRequestsWithAppointmentName();
    setState(() {
      _requests = rows.map(PrayerRequest.fromMap).toList();
      _appointmentNames = rows
          .map((row) => row['appointmentName'] as String?)
          .toList();
      _loading = false;
    });
  }

  Future<void> _addPrayerRequest() async {
    final result = await showNewPrayerRequestSheet(context);
    if (result == null) return;
    await _db.insertPrayerRequest(
      PrayerRequest(
        appointmentId: result.appointmentId,
        content: result.content,
        isAnswered: false,
        createdAt: DateTime.now(),
      ),
    );
    _loadRequests();
  }

  Future<void> _toggleAnswered(PrayerRequest request, bool? value) async {
    if (value == true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mark this prayer as answered?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Mark Answered'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!mounted) return;

      final noteController = TextEditingController();
      final note = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add a note about how it was answered'),
          content: TextField(
            controller: noteController,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Optional'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(noteController.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      await _db.markPrayerRequestAnswered(
        request.id!,
        answeredNote: (note == null || note.isEmpty) ? null : note,
      );
    } else {
      await _db.markPrayerRequestUnanswered(request.id!);
    }
    _loadRequests();
  }

  Future<void> _deleteRequest(PrayerRequest request) async {
    await _db.deletePrayerRequest(request.id!);
    _loadRequests();
  }

  Future<void> _openAppointment(int appointmentId) async {
    final appointment = await _db.getAppointmentById(appointmentId);
    if (appointment == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AppointmentDetailScreen(appointment: appointment),
      ),
    );
    _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    final indices = <int>[
      for (var i = 0; i < _requests.length; i++)
        if ((_filter == _PrayerFilter.answered) == _requests[i].isAnswered) i,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Requests')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SegmentedToggle<_PrayerFilter>(
                      values: const [
                        _PrayerFilter.active,
                        _PrayerFilter.answered,
                      ],
                      labels: const ['Active', 'Answered'],
                      selected: _filter,
                      onChanged: (filter) => setState(() => _filter = filter),
                    ),
                  ),
                ),
                Expanded(
                  child: indices.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _filter == _PrayerFilter.active
                                  ? 'No active prayer requests. Tap + to add one.'
                                  : 'No answered prayers yet.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: indices.length,
                          separatorBuilder: (context, i) => Divider(
                            height: 1,
                            thickness: 0.5,
                            indent: 16,
                            endIndent: 16,
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.4),
                          ),
                          itemBuilder: (context, i) {
                            final index = indices[i];
                            return _buildRow(context, index);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPrayerRequest,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index) {
    final scheme = Theme.of(context).colorScheme;
    final request = _requests[index];
    final appointmentName = _appointmentNames[index];
    final dateFormat = DateFormat('MMM d');

    return Dismissible(
      key: ValueKey(request.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete, color: scheme.onError),
      ),
      onDismissed: (_) => _deleteRequest(request),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Checkbox(
          value: request.isAnswered,
          activeColor: scheme.tertiary,
          side: BorderSide(
            color: request.isAnswered
                ? scheme.tertiary
                : categoryColors(context).teal,
            width: 1.5,
          ),
          onChanged: (value) => _toggleAnswered(request, value),
        ),
        onTap: request.appointmentId != null
            ? () => _openAppointment(request.appointmentId!)
            : null,
        title: Text(
          request.content,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (appointmentName != null)
              Text(
                appointmentName,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              )
            else
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      color: categoryColors(context).teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    'GENERAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      // Small text stays neutral even for a category label
                      // -- the dot above already carries the teal identity,
                      // and teal text at this size fails 4.5:1 contrast.
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            Row(
              children: [
                if (request.isAnswered)
                  Icon(Icons.check_circle, size: 13, color: scheme.tertiary),
                if (request.isAnswered) const SizedBox(width: 4),
                Text(
                  request.isAnswered
                      ? 'Answered ${dateFormat.format(request.answeredAt ?? request.createdAt)}'
                      : 'Added ${dateFormat.format(request.createdAt)}',
                  // The checkmark above already carries the green
                  // "answered" identity; green text this small fails
                  // 4.5:1, so the text itself stays neutral.
                  style: tabularNums(
                    TextStyle(
                      fontSize: 12,
                      fontWeight: request.isAnswered
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (request.isAnswered &&
                request.answeredNote != null &&
                request.answeredNote!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  request.answeredNote!,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
