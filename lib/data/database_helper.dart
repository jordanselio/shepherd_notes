import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/appointment.dart';
import '../models/follow_up_item.dart';
import '../models/prayer_request.dart';
import '../models/session.dart';
import '../models/task.dart';
import '../services/widget_service.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'shepherd_notes.db');
    return openDatabase(
      path,
      version: 5,
      onCreate: _createFreshSchema,
      onUpgrade: _upgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createFreshSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE appointments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'bibleStudy',
        recurrence TEXT NOT NULL DEFAULT 'weekly',
        dayOfWeek TEXT,
        time TEXT NOT NULL,
        endTime TEXT NOT NULL,
        location TEXT,
        startDate TEXT,
        groupSize INTEGER,
        isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _createSessionsAndFollowUps(db);
    await db.execute('''
      CREATE TABLE prayer_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        appointmentId INTEGER,
        sessionId INTEGER,
        content TEXT NOT NULL,
        isAnswered INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        answeredAt TEXT,
        answeredNote TEXT,
        FOREIGN KEY (appointmentId) REFERENCES appointments (id) ON DELETE CASCADE,
        FOREIGN KEY (sessionId) REFERENCES sessions (id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        dueDate TEXT,
        appointmentId INTEGER,
        completedAt TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (appointmentId) REFERENCES appointments (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createSessionsAndFollowUps(Database db) async {
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        appointmentId INTEGER NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        passageTopic TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (appointmentId) REFERENCES appointments (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE follow_up_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER NOT NULL,
        content TEXT NOT NULL,
        isDone INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (sessionId) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE appointments ADD COLUMN kind TEXT NOT NULL DEFAULT 'bibleStudy'",
      );
      await db.execute(
        "ALTER TABLE appointments ADD COLUMN recurrence TEXT NOT NULL DEFAULT 'weekly'",
      );
      await db.execute('ALTER TABLE appointments ADD COLUMN location TEXT');
      await db.execute('ALTER TABLE appointments ADD COLUMN startDate TEXT');
      await db.execute(
        'ALTER TABLE appointments ADD COLUMN groupSize INTEGER',
      );

      await _createSessionsAndFollowUps(db);

      // Migrate old flat session_notes rows into the new sessions table.
      final oldNotes = await db.query('session_notes');
      for (final row in oldNotes) {
        final timestamp = row['timestamp'] as String;
        final date = timestamp.substring(0, 10);
        final time = DateTime.parse(timestamp);
        final hhmm =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        await db.insert('sessions', {
          'appointmentId': row['appointmentId'],
          'date': date,
          'time': hhmm,
          'passageTopic': null,
          'notes': row['content'],
          'createdAt': timestamp,
          'updatedAt': timestamp,
        });
      }
      await db.execute('DROP TABLE session_notes');

      // Recreate prayer_requests with a nullable appointmentId and answered metadata.
      await db.execute('''
        CREATE TABLE prayer_requests_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          appointmentId INTEGER,
          sessionId INTEGER,
          content TEXT NOT NULL,
          isAnswered INTEGER NOT NULL DEFAULT 0,
          createdAt TEXT NOT NULL,
          answeredAt TEXT,
          answeredNote TEXT,
          FOREIGN KEY (appointmentId) REFERENCES appointments (id) ON DELETE CASCADE,
          FOREIGN KEY (sessionId) REFERENCES sessions (id) ON DELETE SET NULL
        )
      ''');
      await db.execute('''
        INSERT INTO prayer_requests_new (id, appointmentId, content, isAnswered, createdAt)
        SELECT id, appointmentId, content, isAnswered, createdAt FROM prayer_requests
      ''');
      await db.execute('DROP TABLE prayer_requests');
      await db.execute(
        'ALTER TABLE prayer_requests_new RENAME TO prayer_requests',
      );
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE appointments ADD COLUMN endTime TEXT');
      await db.execute(
        'ALTER TABLE appointments ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0',
      );
      // Backfill endTime for existing appointments as start + 1 hour,
      // matching the assumed duration the app used before this change.
      final appointments = await db.query('appointments');
      for (final row in appointments) {
        final parts = (row['time'] as String).split(':');
        final startMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        final endMinutes = (startMinutes + 60) % (24 * 60);
        final endHour = endMinutes ~/ 60;
        final endMinute = endMinutes % 60;
        final endTime =
            '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
        await db.update(
          'appointments',
          {'endTime': endTime},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          dueDate TEXT,
          appointmentId INTEGER,
          completedAt TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          FOREIGN KEY (appointmentId) REFERENCES appointments (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 5) {
      // The original (pre-recurrence-feature) schema declared dayOfWeek
      // NOT NULL, back when every appointment was a weekly recurring
      // Bible study. ALTER TABLE can't drop a NOT NULL constraint, so
      // when one-time events (recurrence == none, dayOfWeek == null)
      // were added, every attempt to save one threw an unhandled
      // SQLITE_CONSTRAINT_NOTNULL and was silently lost. Rebuild the
      // table with dayOfWeek nullable, preserving all existing rows.
      await db.execute('''
        CREATE TABLE appointments_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          kind TEXT NOT NULL DEFAULT 'bibleStudy',
          recurrence TEXT NOT NULL DEFAULT 'weekly',
          dayOfWeek TEXT,
          time TEXT NOT NULL,
          endTime TEXT,
          location TEXT,
          startDate TEXT,
          groupSize INTEGER,
          isDeleted INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        INSERT INTO appointments_new (
          id, name, type, kind, recurrence, dayOfWeek, time, endTime,
          location, startDate, groupSize, isDeleted
        )
        SELECT
          id, name, type, kind, recurrence, dayOfWeek, time, endTime,
          location, startDate, groupSize, isDeleted
        FROM appointments
      ''');
      await db.execute('DROP TABLE appointments');
      await db.execute(
        'ALTER TABLE appointments_new RENAME TO appointments',
      );
    }
  }

  /// Fire-and-forget refresh of the home-screen widgets after a write to
  /// appointments or tasks. Never awaited by callers: the widgets are a
  /// supplementary surface and must never slow down or fail a DB write.
  void _syncWidgets() {
    unawaited(WidgetService.instance.refreshWidgets());
  }

  // Appointments

  Future<int> insertAppointment(Appointment appointment) async {
    final db = await database;
    final id = await db.insert('appointments', appointment.toMap()..remove('id'));
    _syncWidgets();
    return id;
  }

  Future<List<Appointment>> getAppointments() async {
    final db = await database;
    final rows = await db.query(
      'appointments',
      where: 'isDeleted = 0',
      orderBy: 'dayOfWeek, time',
    );
    return rows.map(Appointment.fromMap).toList();
  }

  Future<Appointment?> getAppointmentById(int id) async {
    final db = await database;
    final rows = await db.query(
      'appointments',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return Appointment.fromMap(rows.first);
  }

  Future<void> updateAppointment(Appointment appointment) async {
    final db = await database;
    await db.update(
      'appointments',
      appointment.toMap(),
      where: 'id = ?',
      whereArgs: [appointment.id],
    );
    _syncWidgets();
  }

  /// Soft-deletes the appointment: it disappears from Schedule and the
  /// Appointments list, but its historical sessions, notes, and prayer
  /// requests are preserved and remain reachable from Notes/Prayer.
  Future<void> deleteAppointment(int id) async {
    final db = await database;
    await db.update(
      'appointments',
      {'isDeleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    _syncWidgets();
  }

  // Sessions

  Future<int> insertSession(Session session) async {
    final db = await database;
    return db.insert('sessions', session.toMap()..remove('id'));
  }

  Future<void> updateSession(Session session) async {
    final db = await database;
    await db.update(
      'sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<List<Session>> getSessionsForAppointment(int appointmentId) async {
    final db = await database;
    final rows = await db.query(
      'sessions',
      where: 'appointmentId = ?',
      whereArgs: [appointmentId],
      orderBy: 'date DESC, time DESC',
    );
    return rows.map(Session.fromMap).toList();
  }

  Future<Session?> getLatestSessionForAppointment(int appointmentId) async {
    final sessions = await getSessionsForAppointment(appointmentId);
    return sessions.isEmpty ? null : sessions.first;
  }

  Future<Session?> getSessionById(int id) async {
    final db = await database;
    final rows = await db.query('sessions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Session.fromMap(rows.first);
  }

  /// Finds the session already recorded for this appointment on this exact
  /// date, if any -- so adding notes for a date that already has a session
  /// edits it instead of creating a duplicate.
  Future<Session?> getSessionForAppointmentOnDate(
    int appointmentId,
    String date,
  ) async {
    final db = await database;
    final rows = await db.query(
      'sessions',
      where: 'appointmentId = ? AND date = ?',
      whereArgs: [appointmentId, date],
    );
    if (rows.isEmpty) return null;
    return Session.fromMap(rows.first);
  }

  Future<List<Map<String, Object?>>> getAllSessionsWithAppointmentName() async {
    final db = await database;
    return db.rawQuery('''
      SELECT sessions.*, appointments.name AS appointmentName, appointments.kind AS appointmentKind, appointments.type AS appointmentType
      FROM sessions
      JOIN appointments ON sessions.appointmentId = appointments.id
      ORDER BY date DESC, time DESC
    ''');
  }

  Future<void> deleteSession(int id) async {
    final db = await database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  // Follow-up items

  Future<int> insertFollowUpItem(FollowUpItem item) async {
    final db = await database;
    return db.insert('follow_up_items', item.toMap()..remove('id'));
  }

  Future<List<FollowUpItem>> getFollowUpItemsForSession(int sessionId) async {
    final db = await database;
    final rows = await db.query(
      'follow_up_items',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
    return rows.map(FollowUpItem.fromMap).toList();
  }

  Future<List<FollowUpItem>> getIncompleteFollowUpsForAppointment(
    int appointmentId,
  ) async {
    final latest = await getLatestSessionForAppointment(appointmentId);
    if (latest == null) return [];
    final all = await getFollowUpItemsForSession(latest.id!);
    return all.where((item) => !item.isDone).toList();
  }

  Future<void> setFollowUpItemDone(int id, bool isDone) async {
    final db = await database;
    await db.update(
      'follow_up_items',
      {'isDone': isDone ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteFollowUpItem(int id) async {
    final db = await database;
    await db.delete('follow_up_items', where: 'id = ?', whereArgs: [id]);
  }

  // Prayer requests

  Future<int> insertPrayerRequest(PrayerRequest request) async {
    final db = await database;
    return db.insert('prayer_requests', request.toMap()..remove('id'));
  }

  Future<List<Map<String, Object?>>> getAllPrayerRequestsWithAppointmentName() async {
    final db = await database;
    return db.rawQuery('''
      SELECT prayer_requests.*, appointments.name AS appointmentName
      FROM prayer_requests
      LEFT JOIN appointments ON prayer_requests.appointmentId = appointments.id
      ORDER BY isAnswered ASC, createdAt DESC
    ''');
  }

  Future<List<PrayerRequest>> getPrayerRequestsForAppointment(
    int appointmentId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'prayer_requests',
      where: 'appointmentId = ?',
      whereArgs: [appointmentId],
      orderBy: 'isAnswered ASC, createdAt DESC',
    );
    return rows.map(PrayerRequest.fromMap).toList();
  }

  Future<void> markPrayerRequestAnswered(int id, {String? answeredNote}) async {
    final db = await database;
    await db.update(
      'prayer_requests',
      {
        'isAnswered': 1,
        'answeredAt': DateTime.now().toIso8601String(),
        'answeredNote': answeredNote,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markPrayerRequestUnanswered(int id) async {
    final db = await database;
    await db.update(
      'prayer_requests',
      {'isAnswered': 0, 'answeredAt': null, 'answeredNote': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePrayerRequest(int id) async {
    final db = await database;
    await db.delete('prayer_requests', where: 'id = ?', whereArgs: [id]);
  }

  // Tasks

  Future<int> insertTask(Task task) async {
    final db = await database;
    final id = await db.insert('tasks', task.toMap()..remove('id'));
    _syncWidgets();
    return id;
  }

  Future<void> updateTask(Task task) async {
    final db = await database;
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
    _syncWidgets();
  }

  Future<void> setTaskCompleted(int id, bool completed) async {
    final db = await database;
    await db.update(
      'tasks',
      {
        'completedAt': completed ? DateTime.now().toIso8601String() : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _syncWidgets();
  }

  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    _syncWidgets();
  }

  Future<List<Map<String, Object?>>> getAllTasksWithAppointmentInfo() async {
    final db = await database;
    return db.rawQuery('''
      SELECT tasks.*, appointments.name AS appointmentName, appointments.kind AS appointmentKind, appointments.type AS appointmentType
      FROM tasks
      LEFT JOIN appointments ON tasks.appointmentId = appointments.id
      ORDER BY (tasks.dueDate IS NULL), tasks.dueDate ASC, tasks.createdAt ASC
    ''');
  }
}
