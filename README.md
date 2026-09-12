# School Schedule 📅

A clean Flutter timetable app for your school schedule. **Android now, iOS later** — one codebase for both.

## Features

- **Two views of your week**
  - **Weekly grid** — Excel-like layout: weekdays across the top, hours down the side, each class shown as a colored block sized to its duration.
  - **By day** — pick a weekday and see that day's classes as a clean chronological list.
- **Tap any class for details** — subject, day, time interval, **duration**, location, and description.
- **Notifications**
  - Toggle a reminder **for a single class** (with a configurable lead time: at start / 5 / 10 / 15 / 30 / 60 min before).
  - Toggle reminders **for all classes at once** (bell icon in the top bar → "Notify me for all classes").
  - Reminders repeat **weekly** at the class time.
- **Edit your schedule in-app** — add, edit, and delete classes; choose a color per subject.
- **Sample schedule included** — the app starts with a sample Mon–Fri timetable you can edit or replace. "Reset to sample schedule" is in the settings sheet.
- **Data is saved on device** (via `shared_preferences`) and survives restarts.
- **Light & dark theme** (follows the system).

## Project structure

```
lib/
  main.dart                     App entry, theme, provider wiring
  models/
    schedule_event.dart         ScheduleEvent + SlotTime + Weekday helpers
  data/
    sample_schedule.dart        The built-in sample timetable
  services/
    notification_service.dart   Local + timezone-aware weekly notifications
  state/
    schedule_store.dart         State + persistence (ChangeNotifier)
  screens/
    home_screen.dart            Tabs (Grid / Day) + settings + "Add class"
    week_grid_screen.dart       Excel-like weekly grid
    day_list_screen.dart        Day-by-day list
    event_details_screen.dart   Details + per-event notification toggle
    event_editor_screen.dart    Add / edit form
  widgets/
    color_utils.dart            Color contrast helper + subject palette
```

## Requirements

- **Flutter 3.19+** (Dart 3.3+). Works with current stable Flutter.
- Android Studio / Xcode as usual for device deployment.

## How to run (first time)

This repo contains the app source (`lib/`), the `pubspec.yaml`, and a customized
Android manifest. Generate the remaining platform scaffolding (Gradle/iOS
project files) with `flutter create`, which will **not** overwrite the files
already here:

```bash
cd school_schedule

# Generate android/ and ios/ platform files without clobbering lib/ or the manifest
flutter create . --project-name school_schedule --platforms=android,ios

# Fetch dependencies
flutter pub get

# Run on a connected Android device or emulator
flutter run
```

> If `flutter create .` reports that `AndroidManifest.xml` already exists, keep
> **our** version (it declares the notification permissions and receivers the
> app needs). If prompted, choose to keep existing files.

### Build a release APK for your phone

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

Copy that APK to your Android phone and install it (allow "install from unknown
sources").

## Notifications — what to expect

- On first toggle, Android 13+ will prompt for notification permission.
- Reminders are **weekly repeating** at each class's start time minus the chosen
  lead time.
- On some devices you may also want to allow "Alarms & reminders" / disable
  battery optimization for exact-time delivery.

## Replacing the sample data with your real schedule

Two easy options:

1. **In the app (no code):** Use the **Add class** button and the edit/delete
   actions to build your real timetable. Your changes are saved automatically.
2. **In code:** Edit `lib/data/sample_schedule.dart` and change the events to
   your real classes (title, day, start/end time, room, color). Then either
   reinstall, or use **Settings → Reset to sample schedule** to reload them.

   Each event looks like:

   ```dart
   ScheduleEvent(
     id: 'mon-math',
     title: 'Mathematics',
     description: 'Calculus — lecture hall A1',
     location: 'Room A1',
     weekday: Weekday.monday,           // monday..sunday
     start: SlotTime(8, 0),             // 08:00
     end: SlotTime(9, 30),              // 09:30
     colorValue: 0xFF3F51B5,            // ARGB color
   ),
   ```

## Porting to iPhone later

The codebase is already cross-platform. When you're ready for iOS:

1. `flutter create . --platforms=ios` (if not already generated).
2. Open `ios/Runner.xcworkspace` in Xcode, set your signing team.
3. In `ios/Runner/AppDelegate.swift`, set the notification center delegate (see
   the `flutter_local_notifications` iOS setup notes).
4. `flutter run` on an iOS device/simulator.

No UI or logic changes are required — the grid, day view, details, editor, and
notifications all work on both platforms.
