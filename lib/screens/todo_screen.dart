import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import '../theme/category_color.dart';
import '../widgets/task_quick_actions.dart';
import 'todo_form_sheet.dart';

enum _Section { overdue, today, thisWeek, later, noDate }

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final _db = DatabaseHelper.instance;
  List<Task> _tasks = [];
  List<String?> _appointmentNames = [];
  List<String?> _appointmentKinds = [];
  List<String?> _appointmentTypes = [];
  bool _loading = true;
  bool _doneExpanded = false;
  Timer? _snackBarTimer;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _snackBarTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final rows = await _db.getAllTasksWithAppointmentInfo();
    setState(() {
      _tasks = rows.map(Task.fromMap).toList();
      _appointmentNames = rows
          .map((row) => row['appointmentName'] as String?)
          .toList();
      _appointmentKinds = rows
          .map((row) => row['appointmentKind'] as String?)
          .toList();
      _appointmentTypes = rows
          .map((row) => row['appointmentType'] as String?)
          .toList();
      _loading = false;
    });
  }

  Future<void> _addTask() async {
    final result = await showTodoFormSheet(context);
    if (result == null) return;
    final now = DateTime.now();
    await _db.insertTask(
      Task(
        title: result.title,
        dueDate: result.dueDate,
        appointmentId: result.appointmentId,
        createdAt: now,
        updatedAt: now,
      ),
    );
    _loadTasks();
  }

  Future<void> _openTask(Task task) async {
    final result = await showTodoFormSheet(context, existing: task);
    if (result == null) return;
    await _db.updateTask(
      task.copyWith(
        title: result.title,
        dueDate: result.dueDate,
        clearDueDate: result.dueDate == null,
        appointmentId: result.appointmentId,
        clearAppointmentId: result.appointmentId == null,
        updatedAt: DateTime.now(),
      ),
    );
    _loadTasks();
  }

  Future<void> _toggleTask(Task task) async {
    final wasDone = task.isDone;
    await _db.setTaskCompleted(task.id!, !wasDone);
    _loadTasks();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    _snackBarTimer?.cancel();
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(wasDone ? 'Marked as open' : 'Marked as done'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            _snackBarTimer?.cancel();
            await _db.setTaskCompleted(task.id!, wasDone);
            _loadTasks();
          },
        ),
      ),
    );
    // Flutter's built-in SnackBar auto-dismiss timer can get stuck (never
    // fires) if the app is backgrounded/screen-locked while it's showing.
    // This plain Timer is a backstop that force-removes it regardless.
    _snackBarTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
      }
    });
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  _Section _sectionFor(Task task, DateTime today, DateTime endOfWeek) {
    if (task.dueDate == null) return _Section.noDate;
    final due = DateTime.parse(task.dueDate!);
    if (due.isBefore(today)) return _Section.overdue;
    if (_isSameDate(due, today)) return _Section.today;
    if (!due.isAfter(endOfWeek)) return _Section.thisWeek;
    return _Section.later;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = monday.add(const Duration(days: 6));

    final indices = List.generate(_tasks.length, (i) => i);
    final openIndices = indices.where((i) => !_tasks[i].isDone).toList();
    final doneIndices = indices.where((i) => _tasks[i].isDone).toList()
      ..sort(
        (a, b) => _tasks[b].completedAt!.compareTo(_tasks[a].completedAt!),
      );

    final sections = <_Section, List<int>>{
      for (final section in _Section.values) section: [],
    };
    for (final i in openIndices) {
      sections[_sectionFor(_tasks[i], today, endOfWeek)]!.add(i);
    }
    for (final list in sections.values) {
      list.sort((a, b) {
        final dueA = _tasks[a].dueDate;
        final dueB = _tasks[b].dueDate;
        if (dueA != null && dueB != null) {
          final cmp = dueA.compareTo(dueB);
          if (cmp != 0) return cmp;
        }
        return _tasks[a].createdAt.compareTo(_tasks[b].createdAt);
      });
    }

    final openCount = openIndices.length;
    const sectionOrder = [
      _Section.overdue,
      _Section.today,
      _Section.thisWeek,
      _Section.later,
      _Section.noDate,
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'To-do',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.24,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          '$openCount open',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: scheme.outline),
                  Expanded(
                    child: _tasks.isEmpty
                        ? _buildEmptyState(context)
                        : ListView(
                            children: [
                              for (final section in sectionOrder)
                                if (sections[section]!.isNotEmpty) ...[
                                  _buildSectionBand(
                                    context,
                                    section,
                                    sections[section]!.length,
                                  ),
                                  for (final i in sections[section]!)
                                    _buildTaskRow(context, i, section),
                                ],
                              _buildDoneHeader(context, doneIndices.length),
                              if (_doneExpanded)
                                for (final i in doneIndices)
                                  _buildDoneRow(context, i),
                              const SizedBox(height: 96),
                            ],
                          ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Nothing to do yet. Tap + to add one.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  String _sectionLabel(_Section section) {
    switch (section) {
      case _Section.overdue:
        return 'OVERDUE';
      case _Section.today:
        return 'TODAY';
      case _Section.thisWeek:
        return 'THIS WEEK';
      case _Section.later:
        return 'LATER';
      case _Section.noDate:
        return 'NO DATE';
    }
  }

  Widget _buildSectionBand(
    BuildContext context,
    _Section section,
    int count,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = surfaceTokens(context);
    final color = section == _Section.overdue
        ? tokens.overdueText
        : scheme.onSurfaceVariant;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: tokens.dayBand,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _sectionLabel(section),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.72,
              color: color,
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(BuildContext context, int index, _Section section) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = surfaceTokens(context);
    final task = _tasks[index];
    final appointmentName = _appointmentNames[index];

    Widget dueLabel;
    switch (section) {
      case _Section.overdue:
        final due = DateTime.parse(task.dueDate!);
        dueLabel = Text(
          'Overdue · ${DateFormat('EEE').format(due)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: tokens.overdueText,
          ),
        );
        break;
      case _Section.today:
        dueLabel = Text(
          'Today',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.secondary,
          ),
        );
        break;
      case _Section.thisWeek:
        final due = DateTime.parse(task.dueDate!);
        dueLabel = Text(
          DateFormat('EEE').format(due),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        );
        break;
      case _Section.later:
        final due = DateTime.parse(task.dueDate!);
        dueLabel = Text(
          DateFormat('MMM d').format(due),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        );
        break;
      case _Section.noDate:
        dueLabel = const SizedBox.shrink();
        break;
    }

    return InkWell(
      onTap: () => _openTask(task),
      onLongPress: () =>
          showTaskQuickActions(context, task, onChanged: _loadTasks),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.only(left: 12, right: 20),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outline)),
        ),
        child: Row(
          children: [
            _buildCheckbox(context, task, false),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (appointmentName != null) ...[
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: categoryColorForKindType(
                                context,
                                kind: _appointmentKinds[index] ?? 'bibleStudy',
                                type: _appointmentTypes[index] ?? 'individual',
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              appointmentName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ] else
                          Text(
                            'General',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            dueLabel,
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context, Task task, bool done) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = surfaceTokens(context);
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _toggleTask(task),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? scheme.tertiary : Colors.transparent,
                border: done
                    ? null
                    : Border.all(color: tokens.checkboxRing, width: 2),
              ),
              child: done
                  ? Icon(Icons.check, size: 15, color: scheme.onTertiary)
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoneHeader(BuildContext context, int doneCount) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => setState(() => _doneExpanded = !_doneExpanded),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outline)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: scheme.tertiary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Done · $doneCount',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: _doneExpanded ? 0.25 : 0,
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoneRow(BuildContext context, int index) {
    final scheme = Theme.of(context).colorScheme;
    final task = _tasks[index];
    final appointmentName = _appointmentNames[index];
    return InkWell(
      onTap: () => _openTask(task),
      onLongPress: () =>
          showTaskQuickActions(context, task, onChanged: _loadTasks),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.only(left: 12, right: 20),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outline)),
        ),
        child: Row(
          children: [
            _buildCheckbox(context, task, true),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appointmentName ?? 'General',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Done ${DateFormat('MMM d').format(task.completedAt!)}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
