import 'package:flutter/material.dart';

import 'screens/root_screen.dart';
import 'theme/app_theme.dart';

void main() {
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
