import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:shepherd_notes/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App launches to Schedule tab with bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShepherdNotesApp());
    await tester.pump();

    expect(find.text('Schedule'), findsWidgets);
    expect(find.text('Appts'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Prayer'), findsOneWidget);
    expect(find.text('To-do'), findsOneWidget);
  });
}
