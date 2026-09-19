# Shepherd Notes

A Flutter app for organizing recurring 1-on-1 and group Bible studies:
schedule appointments, keep session notes, track prayer requests, and manage
simple to-dos. Data is stored locally on the device (no account or server
required).

Currently targets **Android only**.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (see
  `environment.sdk` in `pubspec.yaml` for the required Dart SDK version)
- [Android Studio](https://developer.android.com/studio) with the Android
  SDK and platform tools installed
- A physical Android device with USB debugging enabled, or an Android
  emulator set up through Android Studio

Confirm your setup is ready by running:

```
flutter doctor
```

Resolve any issues it reports before continuing.

## Setup

1. Clone the repo and move into it:

   ```
   git clone https://github.com/jordanselio/shepherd_notes.git
   cd shepherd_notes
   ```

2. Install dependencies:

   ```
   flutter pub get
   ```

3. Connect an Android device (with USB debugging on) or start an emulator,
   then confirm Flutter sees it:

   ```
   flutter devices
   ```

4. Run the app:

   ```
   flutter run
   ```

## Running tests

```
flutter test
```

## Project structure

- `lib/models/` — data model classes (Appointment, PrayerRequest, Task, etc.)
- `lib/data/database_helper.dart` — sqflite database setup, migrations, and
  CRUD methods
- `lib/screens/` — one screen per tab (Schedule, Appointments, Notes,
  Prayer, To-do), plus their form sheets
- `lib/widgets/` — shared, reusable UI components
- `lib/theme/` — light/dark theme tokens and color helpers
