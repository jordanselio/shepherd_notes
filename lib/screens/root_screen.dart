import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/widget_launch.dart';
import '../services/widget_service.dart';
import 'appointments_screen.dart';
import 'notes_screen.dart';
import 'prayer_requests_screen.dart';
import 'schedule_screen.dart';
import 'todo_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  // Non-null only for the one build right after a widget tap asked to open
  // Schedule with an action; ScheduleScreen consumes it in its initState
  // and it is not reused on later rebuilds.
  bool _autoOpenAddFlow = false;
  int? _focusAppointmentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetLaunch.instance.pending.addListener(_handleWidgetLaunch);
    _handleWidgetLaunch();
  }

  @override
  void dispose() {
    WidgetLaunch.instance.pending.removeListener(_handleWidgetLaunch);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetService.instance.refreshWidgets();
    }
  }

  void _handleWidgetLaunch() {
    final action = WidgetLaunch.instance.pending.value;
    if (action == null) return;
    WidgetLaunch.instance.consume();
    setState(() {
      switch (action) {
        case OpenToday():
          _selectedIndex = 0;
        case OpenNewAppointment():
          _selectedIndex = 0;
          _autoOpenAddFlow = true;
        case OpenAppointment(:final id):
          _selectedIndex = 0;
          _focusAppointmentId = id;
        case OpenTodoTab():
          _selectedIndex = 4;
      }
    });
  }

  /// Builds the five tab bodies. A method (not a cached list) because
  /// Schedule needs to pick up any one-shot widget-launch action baked in
  /// just before this runs; the flags are cleared right after so they don't
  /// replay on a later rebuild that isn't following a fresh widget tap.
  List<Widget> _buildScreens() {
    final scheduleScreen = ScheduleScreen(
      key: ValueKey('schedule-$_autoOpenAddFlow-$_focusAppointmentId'),
      autoOpenAddFlow: _autoOpenAddFlow,
      focusAppointmentId: _focusAppointmentId,
    );
    // These one-shot flags must not replay if the user simply switches back
    // to this tab later.
    _autoOpenAddFlow = false;
    _focusAppointmentId = null;
    return [
      scheduleScreen,
      const AppointmentsScreen(),
      const NotesScreen(),
      const PrayerRequestsScreen(),
      const TodoScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final overlayStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: theme.colorScheme.surface,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: theme.colorScheme.surface,
            systemNavigationBarIconBrightness: Brightness.dark,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        body: _buildScreens()[_selectedIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.calendar_today),
                label: 'Schedule',
              ),
              NavigationDestination(
                icon: const Tooltip(
                  message: 'Appointments',
                  child: Icon(Icons.people_alt),
                ),
                // Shown label is short so 5 tabs fit; the tooltip and the
                // Appointments screen's own title still say "Appointments".
                label: 'Appts',
              ),
              const NavigationDestination(
                icon: Icon(Icons.notes),
                label: 'Notes',
              ),
              const NavigationDestination(
                icon: Icon(Icons.volunteer_activism),
                label: 'Prayer',
              ),
              const NavigationDestination(
                icon: Icon(Icons.check_box_outlined),
                label: 'To-do',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
