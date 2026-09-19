import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class _RootScreenState extends State<RootScreen> {
  int _selectedIndex = 0;

  static const _screens = [
    ScheduleScreen(),
    AppointmentsScreen(),
    NotesScreen(),
    PrayerRequestsScreen(),
    TodoScreen(),
  ];

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
        body: _screens[_selectedIndex],
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
