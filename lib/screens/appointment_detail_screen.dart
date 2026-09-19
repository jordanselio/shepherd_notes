import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../models/appointment.dart';
import '../models/prayer_request.dart';
import '../models/session.dart';
import '../theme/app_theme.dart';
import '../theme/category_color.dart';
import '../utils/time_format.dart';
import 'appointment_form_sheet.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final Appointment appointment;

  /// The specific occurrence date the user navigated from (e.g. tapping
  /// Daniel's September 4 slot in Schedule). When set, adding notes targets
  /// this date instead of today.
  final DateTime? focusDate;

  const AppointmentDetailScreen({
    super.key,
    required this.appointment,
    this.focusDate,
  });

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;
  late Appointment _appointment;
  late TabController _tabController;
  List<Session> _sessions = [];
  List<PrayerRequest> _prayerRequests = [];

  @override
  void initState() {
    super.initState();
    _appointment = widget.appointment;
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
    _loadSessions();
    _loadPrayerRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final sessions = await _db.getSessionsForAppointment(_appointment.id!);
    setState(() => _sessions = sessions);
  }

  Future<void> _loadPrayerRequests() async {
    final requests = await _db.getPrayerRequestsForAppointment(
      _appointment.id!,
    );
    setState(() => _prayerRequests = requests);
  }

  Future<void> _editAppointment() async {
    final result = await showAppointmentFormSheet(
      context,
      existing: _appointment,
    );
    if (result == null) return;
    await _db.updateAppointment(result);
    setState(() => _appointment = result);
  }

  Future<void> _deleteAppointment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${_appointment.name}"?'),
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
    await _db.deleteAppointment(_appointment.id!);
    if (mounted) Navigator.of(context).pop();
  }

  String _isoDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Adds notes for the session the user is focused on (or edits it, if one
  /// already exists for that date) -- rather than always assuming "today".
  Future<void> _addOrEditFocusedSessionNote() async {
    final targetDate = widget.focusDate ?? DateTime.now();
    final existing = await _db.getSessionForAppointmentOnDate(
      _appointment.id!,
      _isoDate(targetDate),
    );
    await _editSessionNoteDialog(existing: existing, date: targetDate);
  }

  Future<void> _editExistingSessionNote(Session note) =>
      _editSessionNoteDialog(existing: note, date: note.dateTime);

  Future<void> _editSessionNoteDialog({
    required Session? existing,
    required DateTime date,
  }) async {
    final controller = TextEditingController(text: existing?.notes ?? '');
    final dateLabel = DateFormat('MMMM d, yyyy').format(date);
    final content = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'New Session Note' : 'Edit Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 5,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'What happened today?',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (content == null || content.isEmpty) return;
    final now = DateTime.now();
    if (existing != null) {
      await _db.updateSession(
        Session(
          id: existing.id,
          appointmentId: existing.appointmentId,
          date: existing.date,
          time: existing.time,
          passageTopic: existing.passageTopic,
          notes: content,
          createdAt: existing.createdAt,
          updatedAt: now,
        ),
      );
    } else {
      await _db.insertSession(
        Session(
          appointmentId: _appointment.id!,
          date: _isoDate(date),
          // A session's start time is the appointment's actual scheduled
          // time, not the moment the note happens to be written.
          time: _appointment.time,
          notes: content,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    _loadSessions();
  }

  Future<void> _deleteSession(Session session) async {
    await _db.deleteSession(session.id!);
    _loadSessions();
  }

  Future<void> _addPrayerRequest() async {
    final controller = TextEditingController();
    final content = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Prayer Request'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'What can we pray for?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (content == null || content.isEmpty) return;
    await _db.insertPrayerRequest(
      PrayerRequest(
        appointmentId: _appointment.id!,
        content: content,
        isAnswered: false,
        createdAt: DateTime.now(),
      ),
    );
    _loadPrayerRequests();
  }

  Future<void> _toggleAnswered(PrayerRequest request, bool? value) async {
    if (value == true) {
      await _db.markPrayerRequestAnswered(request.id!);
    } else {
      await _db.markPrayerRequestUnanswered(request.id!);
    }
    _loadPrayerRequests();
  }

  Future<void> _deletePrayerRequest(PrayerRequest request) async {
    await _db.deletePrayerRequest(request.id!);
    _loadPrayerRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appointment.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _editAppointment();
              if (value == 'delete') _deleteAppointment();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Notes'),
            Tab(text: 'Prayer Requests'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildInfoHeader(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildNotesTab(), _buildPrayerRequestsTab()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _tabController.index == 0
            ? _addOrEditFocusedSessionNote
            : _addPrayerRequest,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInfoHeader(BuildContext context) {
    final schedule = _appointment.dayOfWeek != null
        ? '${_appointment.dayOfWeek}s'
        : _appointment.startDate;
    final range =
        '${formatStoredTime(_appointment.time)} – ${formatStoredTime(_appointment.endTime)}';
    final parts = [
      ?schedule,
      range,
      if (_appointment.location != null && _appointment.location!.isNotEmpty)
        _appointment.location!,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: appointmentCategoryColor(context, _appointment),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              parts.join(' · '),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    if (_sessions.isEmpty) {
      return const Center(child: Text('No notes yet.'));
    }
    final scheme = Theme.of(context).colorScheme;
    final dateFormatter = DateFormat('MMMM d, yyyy');
    return ListView.separated(
      itemCount: _sessions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return Dismissible(
          key: ValueKey(session.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: scheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Icon(Icons.delete, color: scheme.onError),
          ),
          onDismissed: (_) => _deleteSession(session),
          child: ListTile(
            onTap: () => _editExistingSessionNote(session),
            title: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: dateFormatter.format(session.dateTime),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: ' · ${formatStoredTime(session.time)}',
                    style: tabularNums(
                      TextStyle(
                        fontWeight: FontWeight.w400,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            subtitle: Text(session.notes ?? ''),
            isThreeLine: (session.notes?.length ?? 0) > 60,
          ),
        );
      },
    );
  }

  Widget _buildPrayerRequestsTab() {
    if (_prayerRequests.isEmpty) {
      return const Center(child: Text('No prayer requests yet.'));
    }
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      itemCount: _prayerRequests.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final request = _prayerRequests[index];
        return Dismissible(
          key: ValueKey(request.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: scheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Icon(Icons.delete, color: scheme.onError),
          ),
          onDismissed: (_) => _deletePrayerRequest(request),
          child: CheckboxListTile(
            value: request.isAnswered,
            activeColor: scheme.tertiary,
            onChanged: (value) => _toggleAnswered(request, value),
            title: Text(request.content),
            secondary: request.isAnswered
                ? Icon(Icons.check_circle, color: scheme.tertiary, size: 18)
                : null,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );
      },
    );
  }
}
