import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'data/database_helper.dart';
import 'screens/root_screen.dart';
import 'services/widget_launch.dart';
import 'services/widget_service.dart';
import 'theme/app_theme.dart';

/// Entry point the native widgets invoke to run Dart code in the background
/// (no UI, app not necessarily foregrounded), used only for completing a
/// to-do from the To-do widget's checkbox. Must stay a top-level function
/// annotated `vm:entry-point` so the background isolate can find it.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  if (uri.host.toLowerCase() == 'completetodo') {
    final id = int.tryParse(uri.queryParameters['id'] ?? '');
    if (id == null) return;
    // setTaskCompleted refreshes the widgets itself once done.
    await DatabaseHelper.instance.setTaskCompleted(id, true);
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  WidgetLaunch.instance.init();
  // Populate the widgets immediately (e.g. right after install, before the
  // user has touched any appointment or task) so they never sit blank.
  WidgetService.instance.refreshWidgets();
  runApp(const ShepherdNotesApp());
}

class ShepherdNotesApp extends StatelessWidget {
  const ShepherdNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shepherd Notes',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const RootScreen(),
    );
  }
}
