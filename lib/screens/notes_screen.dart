import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../models/session.dart';
import '../theme/app_theme.dart';
import '../theme/category_color.dart';
import '../utils/time_format.dart';
import 'appointment_detail_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _db = DatabaseHelper.instance;
  List<Session> _sessions = [];
  List<String> _appointmentNames = [];
  List<String> _appointmentKinds = [];
  List<String> _appointmentTypes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final rows = await _db.getAllSessionsWithAppointmentName();
    setState(() {
      _sessions = rows.map(Session.fromMap).toList();
      _appointmentNames = rows
          .map((row) => row['appointmentName'] as String)
          .toList();
      _appointmentKinds = rows
          .map((row) => row['appointmentKind'] as String)
          .toList();
      _appointmentTypes = rows
          .map((row) => row['appointmentType'] as String)
          .toList();
      _loading = false;
    });
  }

  Future<void> _openSession(Session session) async {
    final appointment = await _db.getAppointmentById(session.appointmentId);
    if (appointment == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AppointmentDetailScreen(
          appointment: appointment,
          focusDate: session.dateTime,
        ),
      ),
    );
    _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No notes yet. Open an appointment to add one.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _buildGroupedList(context),
    );
  }

  Widget _buildGroupedList(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headerFormat = DateFormat('MMMM d');
    final headerFormatWithYear = DateFormat('MMMM d, yyyy');
    final currentYear = DateTime.now().year;

    final rows = <Widget>[];
    String? lastDate;
    for (var i = 0; i < _sessions.length; i++) {
      final session = _sessions[i];
      if (session.date != lastDate) {
        final format = session.dateTime.year == currentYear
            ? headerFormat
            : headerFormatWithYear;
        rows.add(
          Padding(
            padding: EdgeInsets.fromLTRB(16, i == 0 ? 16 : 20, 16, 4),
            child: Text(
              format.format(session.dateTime).toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        );
        lastDate = session.date;
      } else {
        rows.add(
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: scheme.outline.withValues(alpha: 0.6),
          ),
        );
      }
      rows.add(
        InkWell(
          onTap: () => _openSession(session),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: categoryColorForKindType(
                          context,
                          kind: _appointmentKinds[i],
                          type: _appointmentTypes[i],
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        _appointmentNames[i],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  formatStoredTime(session.time),
                  style: tabularNums(
                    TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (session.notes != null && session.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      session.notes!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return ListView(padding: const EdgeInsets.only(bottom: 16), children: rows);
  }
}
