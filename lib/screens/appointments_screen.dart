import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../models/appointment.dart';
import '../theme/app_theme.dart';
import '../utils/occurrence.dart';
import '../widgets/appointment_quick_actions.dart';
import '../widgets/appointment_tile.dart';
import 'appointment_detail_screen.dart';
import 'appointment_form_sheet.dart';

enum _CategoryFilter { all, individual, group, event }

const _filterLabels = {
  _CategoryFilter.all: 'All',
  _CategoryFilter.individual: '1-on-1',
  _CategoryFilter.group: 'Groups',
  _CategoryFilter.event: 'Events',
};

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _db = DatabaseHelper.instance;
  final _searchController = TextEditingController();
  List<Appointment> _appointments = [];
  bool _loading = true;
  _CategoryFilter _filter = _CategoryFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    final appointments = await _db.getAppointments();
    setState(() {
      _appointments = appointments;
      _loading = false;
    });
  }

  Future<void> _addAppointment() async {
    final result = await showAddAppointmentFlow(context);
    if (result == null) return;
    await _db.insertAppointment(result);
    _loadAppointments();
  }

  Future<void> _openAppointment(Appointment appointment) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AppointmentDetailScreen(appointment: appointment),
      ),
    );
    _loadAppointments();
  }

  /// The weekday an appointment belongs under: its recurring day, or (for a
  /// one-off) the weekday its specific date falls on.
  String? _weekdayFor(Appointment appointment) {
    if (appointment.dayOfWeek != null) return appointment.dayOfWeek;
    if (appointment.startDate != null) {
      return weekdayName(DateTime.parse(appointment.startDate!));
    }
    return null;
  }

  bool _matchesFilter(Appointment a) {
    switch (_filter) {
      case _CategoryFilter.all:
        return true;
      case _CategoryFilter.individual:
        return a.kind == AppointmentKind.bibleStudy &&
            a.type == AppointmentType.individual;
      case _CategoryFilter.group:
        return a.kind == AppointmentKind.bibleStudy &&
            a.type == AppointmentType.group;
      case _CategoryFilter.event:
        return a.kind == AppointmentKind.event;
    }
  }

  bool _matchesQuery(Appointment a) {
    if (_query.isEmpty) return true;
    return a.name.toLowerCase().contains(_query);
  }

  Color _filterTint(BuildContext context, _CategoryFilter filter) {
    final scheme = Theme.of(context).colorScheme;
    final colors = categoryColors(context);
    switch (filter) {
      case _CategoryFilter.all:
        return scheme.secondary.withValues(alpha: 0.12);
      case _CategoryFilter.individual:
        return colors.sageTint;
      case _CategoryFilter.group:
        return colors.lavenderTint;
      case _CategoryFilter.event:
        return colors.amberTint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _appointments
        .where((a) => _matchesFilter(a) && _matchesQuery(a))
        .toList();

    final byDay = <String, List<Appointment>>{};
    for (final appointment in visible) {
      final day = _weekdayFor(appointment);
      if (day == null) continue;
      byDay.putIfAbsent(day, () => []).add(appointment);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.time.compareTo(b.time));
    }
    final daysWithAppointments = weekdayNames
        .where((day) => byDay[day]?.isNotEmpty ?? false)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search appointments...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final entry in _filterLabels.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: _filter == entry.key,
                        onSelected: (_) => setState(() => _filter = entry.key),
                        selectedColor: _filterTint(context, entry.key),
                        // Text stays neutral even when selected -- the
                        // category color already shows via the tinted
                        // background. Small text in sage/amber/rose fails
                        // contrast, so the category itself never colors it.
                        labelStyle: _filter == entry.key
                            ? TextStyle(
                                color: entry.key == _CategoryFilter.all
                                    ? Theme.of(context).colorScheme.secondary
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              )
                            : null,
                        side: BorderSide(
                          color: _filter == entry.key
                              ? Colors.transparent
                              : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : daysWithAppointments.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _appointments.isEmpty
                                ? 'No appointments yet. Tap + to add your weekly schedule.'
                                : 'No appointments match.',
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
                    : ListView(
                        children: [
                          for (final day in daysWithAppointments) ...[
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                day == daysWithAppointments.first ? 12 : 24,
                                16,
                                4,
                              ),
                              child: Text(
                                day.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            for (var i = 0; i < byDay[day]!.length; i++) ...[
                              AppointmentTile(
                                appointment: byDay[day]![i],
                                onTap: () =>
                                    _openAppointment(byDay[day]![i]),
                                onLongPress: () => showAppointmentQuickActions(
                                  context,
                                  byDay[day]![i],
                                  onChanged: _loadAppointments,
                                ),
                              ),
                              if (i < byDay[day]!.length - 1)
                                Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  indent: 16,
                                  endIndent: 16,
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.4),
                                ),
                            ],
                          ],
                        ],
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAppointment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
