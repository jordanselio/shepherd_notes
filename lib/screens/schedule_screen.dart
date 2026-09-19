import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../models/appointment.dart';
import '../theme/app_theme.dart';
import '../theme/category_color.dart';
import '../utils/occurrence.dart';
import '../widgets/appointment_quick_actions.dart';
import '../widgets/segmented_toggle.dart';
import 'appointment_detail_screen.dart';
import 'appointment_form_sheet.dart';

enum _ViewMode { day, week }

/// Where an occurrence sits relative to "now", used to decide how much
/// visual weight it gets. Only ever computed for today -- other days are
/// always [normal].
enum _Emphasis { normal, past, current, next }

typedef _Occurrence =
    ({Appointment appointment, DateTime start, DateTime end});

sealed class _TimelineItem {}

class _EventItem extends _TimelineItem {
  final Appointment appointment;
  final DateTime start;
  final DateTime end;
  final _Emphasis emphasis;
  _EventItem(this.appointment, this.start, this.end, this.emphasis);
}

class _GapItem extends _TimelineItem {
  final Duration duration;
  _GapItem(this.duration);
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _db = DatabaseHelper.instance;
  List<Appointment> _appointments = [];
  bool _loading = true;
  late DateTime _selectedDate;
  _ViewMode _viewMode = _ViewMode.day;

  /// One GlobalKey per visible week-view day (keyed by ISO date), so
  /// tapping a week-strip cell can scroll the agenda list to that section.
  final Map<String, GlobalKey> _dayKeys = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadAppointments();
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

  Future<void> _openAppointment(
    Appointment appointment, {
    DateTime? focusDate,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AppointmentDetailScreen(
          appointment: appointment,
          focusDate: focusDate,
        ),
      ),
    );
    _loadAppointments();
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = DateTime(date.year, date.month, date.day));
  }

  void _shiftWeek(int deltaDays) {
    _selectDate(_selectedDate.add(Duration(days: deltaDays)));
  }

  void _goToToday() {
    final now = DateTime.now();
    _selectDate(DateTime(now.year, now.month, now.day));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) _selectDate(picked);
  }

  DateTime _mondayOf(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  String _isoDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _occurrenceStart(Appointment appointment, DateTime date) {
    final parts = appointment.time.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  DateTime _occurrenceEnd(Appointment appointment, DateTime date) {
    final parts = appointment.endTime.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  List<_Occurrence> _occurrencesOn(DateTime date) {
    return _appointments
        .where((a) => appointmentOccursOn(a, date))
        .map(
          (a) => (
            appointment: a,
            start: _occurrenceStart(a, date),
            end: _occurrenceEnd(a, date),
          ),
        )
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Computes NOW/NEXT/PAST for a day's occurrences. Only meaningful when
  /// that day is today -- callers must not use this for other days.
  Map<int, _Emphasis> _computeEmphasis(
    List<_Occurrence> todaysOccurrences,
    DateTime now,
  ) {
    final result = <int, _Emphasis>{};
    final anyCurrent = todaysOccurrences.any(
      (o) => !now.isBefore(o.start) && now.isBefore(o.end),
    );
    _Occurrence? nextOccurrence;
    if (!anyCurrent) {
      final upcoming =
          todaysOccurrences.where((o) => o.start.isAfter(now)).toList()
            ..sort((a, b) => a.start.compareTo(b.start));
      if (upcoming.isNotEmpty) nextOccurrence = upcoming.first;
    }
    for (final o in todaysOccurrences) {
      final id = o.appointment.id!;
      if (!now.isBefore(o.start) && now.isBefore(o.end)) {
        result[id] = _Emphasis.current;
      } else if (nextOccurrence != null &&
          nextOccurrence.appointment.id == id &&
          nextOccurrence.start == o.start) {
        result[id] = _Emphasis.next;
      } else if (!o.end.isAfter(now)) {
        result[id] = _Emphasis.past;
      } else {
        result[id] = _Emphasis.normal;
      }
    }
    return result;
  }

  void _scrollToDay(DateTime day) {
    _selectDate(day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _dayKeys[_isoDate(day)]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildHeaderRow(context),
                  Expanded(
                    child: _viewMode == _ViewMode.day
                        ? _buildDayView(context)
                        : _buildWeekView(context),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAppointment,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Shared header (title + Day/Week toggle)
  // ---------------------------------------------------------------------

  Widget _buildHeaderRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Schedule',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.24,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SegmentedToggle<_ViewMode>(
            values: const [_ViewMode.day, _ViewMode.week],
            labels: const ['Day', 'Week'],
            selected: _viewMode,
            onChanged: (mode) => setState(() => _viewMode = mode),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Day view
  // ---------------------------------------------------------------------

  Widget _buildDayView(BuildContext context) {
    final now = DateTime.now();
    final isToday = isSameDate(_selectedDate, now);
    final occurrences = _occurrencesOn(_selectedDate);
    final emphasisMap = isToday
        ? _computeEmphasis(occurrences, now)
        : const <int, _Emphasis>{};

    final items = _buildTimelineItems(occurrences, emphasisMap);

    return Column(
      children: [
        _buildMonthHeader(context),
        _buildWeekStrip(context),
        const Divider(height: 1),
        Expanded(child: _buildTimeline(context, items)),
      ],
    );
  }

  List<_TimelineItem> _buildTimelineItems(
    List<_Occurrence> occurrences,
    Map<int, _Emphasis> emphasisMap,
  ) {
    final items = <_TimelineItem>[];
    for (var i = 0; i < occurrences.length; i++) {
      final current = occurrences[i];
      final emphasis =
          emphasisMap[current.appointment.id!] ?? _Emphasis.normal;
      items.add(
        _EventItem(current.appointment, current.start, current.end, emphasis),
      );
      if (i < occurrences.length - 1) {
        final gap = occurrences[i + 1].start.difference(current.end);
        if (gap.inMinutes >= 30) {
          items.add(_GapItem(gap));
        }
      }
    }
    return items;
  }

  Widget _buildMonthHeader(BuildContext context) {
    final isToday = isSameDate(_selectedDate, DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _pickDate,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedDate),
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          if (!isToday)
            TextButton(onPressed: _goToToday, child: const Text('Today')),
        ],
      ),
    );
  }

  Widget _buildWeekStrip(BuildContext context) {
    final monday = _mondayOf(_selectedDate);
    final week = List.generate(7, (i) => monday.add(Duration(days: i)));
    final today = DateTime.now();
    final accent = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -200) {
          _shiftWeek(7);
        } else if (velocity > 200) {
          _shiftWeek(-7);
        }
      },
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shiftWeek(-7),
          ),
          for (final day in week)
            Expanded(
              child: _DateChip(
                date: day,
                isSelected: isSameDate(day, _selectedDate),
                isToday: isSameDate(day, today),
                accent: accent,
                onTap: () => _selectDate(day),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _shiftWeek(7),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, List<_TimelineItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nothing scheduled for this day.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isLast = index == items.length - 1;
        return switch (item) {
          _EventItem() => _buildEventRow(context, item, isLast),
          _GapItem() => _buildGapRow(context, item, isLast),
        };
      },
    );
  }

  Widget _buildEventRow(BuildContext context, _EventItem item, bool isLast) {
    final scheme = Theme.of(context).colorScheme;
    final appointment = item.appointment;
    final timeFormat = DateFormat('h:mm a');
    final isRecurring = appointment.recurrence != RecurrenceType.none;
    final emphasized =
        item.emphasis == _Emphasis.current || item.emphasis == _Emphasis.next;
    final isPast = item.emphasis == _Emphasis.past;

    final markerColor = emphasized
        ? scheme.primary
        : appointmentCategoryColor(context, appointment);
    final markerSize = emphasized ? 14.0 : 10.0;

    final nameStyle = emphasized
        ? const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)
            .copyWith(color: scheme.onSurface)
        : TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isPast ? scheme.onSurfaceVariant : scheme.onSurface,
          );
    final timeStyle = tabularNums(
      TextStyle(
        fontSize: emphasized ? 14 : 13,
        fontWeight: emphasized ? FontWeight.w500 : FontWeight.w400,
        color: emphasized ? scheme.secondary : scheme.onSurfaceVariant,
      ),
    );
    final locationStyle = TextStyle(
      fontSize: emphasized ? 14 : 13,
      fontWeight: FontWeight.w400,
      color: scheme.onSurfaceVariant,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(timeFormat.format(item.start), style: timeStyle),
          ),
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: markerSize,
                  height: markerSize,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: scheme.outline),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: InkWell(
                onTap: () => _openAppointment(
                  appointment,
                  focusDate: _selectedDate,
                ),
                onLongPress: () => showAppointmentQuickActions(
                  context,
                  appointment,
                  onChanged: _loadAppointments,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.emphasis == _Emphasis.current ||
                        item.emphasis == _Emphasis.next)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          item.emphasis == _Emphasis.current ? 'Now' : 'Next',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: scheme.secondary,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            appointment.name,
                            style: nameStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRecurring) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.repeat,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${timeFormat.format(item.start)} – ${timeFormat.format(item.end)}',
                      style: timeStyle,
                    ),
                    if (appointment.location != null &&
                        appointment.location!.isNotEmpty)
                      Text(appointment.location!, style: locationStyle),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGapRow(BuildContext context, _GapItem item, bool isLast) {
    final dividerColor = Theme.of(context).colorScheme.outline;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 64),
          SizedBox(
            width: 20,
            child: Column(
              children: [
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: dividerColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _formatGap(item.duration),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatGap(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m free';
    if (hours > 0) return '${hours}h free';
    return '${minutes}m free';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  // ---------------------------------------------------------------------
  // Week view
  // ---------------------------------------------------------------------

  Widget _buildWeekView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monday = _mondayOf(_selectedDate);
    final week = List.generate(7, (i) => monday.add(Duration(days: i)));
    final today = DateTime.now();
    final containsToday = week.any((d) => isSameDate(d, today));
    final rangeLabel =
        '${DateFormat('MMM d').format(monday)}–${DateFormat('d').format(week.last)}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(
            children: [
              IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                iconSize: 20,
                color: scheme.onSurfaceVariant,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shiftWeek(-7),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      rangeLabel,
                      style: tabularNums(
                        const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (containsToday) ...[
                      const SizedBox(width: 8),
                      Text(
                        'This week',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: scheme.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                iconSize: 20,
                color: scheme.onSurfaceVariant,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shiftWeek(7),
              ),
            ],
          ),
        ),
        _buildWeekStripNew(context, week),
        Expanded(
          child: ListView(
            children: [
              for (final day in week) _buildWeekDaySection(context, day),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekStripNew(BuildContext context, List<DateTime> week) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final day in week)
            _WeekStripCell(
              date: day,
              isToday: isSameDate(day, today),
              hasAppointments: _occurrencesOn(day).isNotEmpty,
              onTap: () => _scrollToDay(day),
            ),
        ],
      ),
    );
  }

  Widget _buildWeekDaySection(BuildContext context, DateTime day) {
    final now = DateTime.now();
    final isToday = isSameDate(day, now);
    final occurrences = _occurrencesOn(day);
    final emphasisMap = isToday
        ? _computeEmphasis(occurrences, now)
        : const <int, _Emphasis>{};
    final scheme = Theme.of(context).colorScheme;
    final tokens = surfaceTokens(context);
    final key = _dayKeys.putIfAbsent(_isoDate(day), () => GlobalKey());
    final dayLabel = DateFormat('EEE d').format(day).toUpperCase();
    final labelColor = isToday ? scheme.secondary : scheme.onSurfaceVariant;

    if (occurrences.isEmpty) {
      return Container(
        key: key,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outline)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                dayLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.72,
                  color: labelColor,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'No appointments',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          color: tokens.dayBand,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dayLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.72,
                  color: labelColor,
                ),
              ),
              Text(
                '${occurrences.length}',
                style: tabularNums(
                  TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final occurrence in occurrences)
          _buildWeekEventRow(
            context,
            occurrence,
            day,
            emphasisMap[occurrence.appointment.id!] ?? _Emphasis.normal,
          ),
      ],
    );
  }

  Widget _buildWeekEventRow(
    BuildContext context,
    _Occurrence occurrence,
    DateTime day,
    _Emphasis emphasis,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final appointment = occurrence.appointment;
    final timeFormat = DateFormat('h:mm a');
    final emphasized =
        emphasis == _Emphasis.current || emphasis == _Emphasis.next;
    final isPast = emphasis == _Emphasis.past;

    final dotColor = emphasized
        ? scheme.primary
        : appointmentCategoryColor(context, appointment);
    final dotSize = emphasized ? 10.0 : 8.0;
    final nameColor = isPast ? scheme.onSurfaceVariant : scheme.onSurface;
    final timeColor = emphasized ? scheme.secondary : scheme.onSurface;

    return InkWell(
      onTap: () => _openAppointment(appointment, focusDate: day),
      onLongPress: () => showAppointmentQuickActions(
        context,
        appointment,
        onChanged: _loadAppointments,
      ),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outline)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                timeFormat.format(occurrence.start),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: tabularNums(
                  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: timeColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (emphasized) ...[
                    Text(
                      emphasis == _Emphasis.current ? 'Now' : 'Next',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      appointment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: emphasized
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: nameColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(occurrence.end.difference(occurrence.start)),
              style: tabularNums(
                TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekStripCell extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool hasAppointments;
  final VoidCallback onTap;

  const _WeekStripCell({
    required this.date,
    required this.isToday,
    required this.hasAppointments,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('E').format(date).substring(0, 1),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                color: isToday ? scheme.secondary : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isToday ? scheme.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${date.day}',
                style: tabularNums(
                  TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isToday ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasAppointments ? scheme.primary : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final Color accent;
  final VoidCallback onTap;

  const _DateChip({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onAccent = Theme.of(context).colorScheme.onPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              DateFormat('E').format(date).substring(0, 1),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? accent : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${date.day}',
                style: tabularNums(
                  TextStyle(
                    fontWeight: isSelected || isToday
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: isSelected
                        ? onAccent
                        : isToday
                            ? accent
                            : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
