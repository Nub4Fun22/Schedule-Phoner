# Schedule Phoner 📅

A clean Flutter timetable app for your school schedule. **Android now, iOS later** — one codebase for both.

## Features

- **Starts empty** — add your own items; nothing is pre-filled. A demo dataset
  can be **imported** any time from Settings (it's added alongside your own
  items) and **removed again** with one tap, without touching your data.
- **Typed items**, each with its own behavior and priority
  (low → high: **Event < Course < Lab = Seminar < (Homework = Project) < Test < Presentation < Exam**):
  - **Course** — permanent weekly reminder.
  - **Lab** — permanent weekly reminder; can carry **Homework**.
  - **Seminar** — behaves 1:1 with a Lab (permanent weekly; can carry
    **Homework**).
  - **Homework** — attached to a lab/seminar; optional description, a due date,
    and a **done** checkbox. Reminds you before **each** occurrence of that
    lab/seminar (default: 1 day before) and repeats **weekly until you mark it
    done or the due date passes**.
  - **Test** — one-time **or** weekly.
  - **Project** — one-time or weekly, meant to be linked to a lab.
  - **Project presentation** — one-time.
  - **Exam** — one-time, highest priority.
  - **Event** — a simple personal reminder (e.g. *do dishes*), one-time or
    weekly; can carry **Tasks**.
  - **Task** — attached to an Event; the personal-reminder analogue of
    Homework (description, due date, done checkbox, reminders before each
    occurrence).
- **Add sub-items on the spot** — when creating a Lab/Seminar (homework) or an
  Event (tasks), you can add them right in the editor before saving, or later
  from the item's details screen.
- **Flexible reminders** for homework/tasks — either **before each occurrence**
  of the lab/event, or **"alert me every day until then"** at a chosen hour.
- **Four views** (bottom navigation):
  - **Grid** — Excel-like weekly grid of recurring items (weekend shown by
    default). Also surfaces one-time items falling in the current week.
  - **Day** — a chosen weekday's items as a list, with homework badges. Opens
    on today.
  - **What's next** — everything upcoming by time, soonest first, with a countdown.
  - **Priority** — priority-ordered sections, top to bottom:
    **Homework → Tests → Project presentations → Exams**, each sorted
    soonest-first (nearest date = most urgent).
- **Due-date countdowns** — due dates show the time remaining (e.g.
  *12/03/2026 • in 3 days*, or *in 2h 15m* on the day).
- **Notifications** — silent by default; importance scales with item priority
  (exams are the most prominent, courses the least). A **Settings** screen lets
  you toggle **sound** and **vibration** (both off by default), send **test
  notifications**, set a default reminder lead time, choose the **theme**
  (system/light/dark), show the **weekend** in the grid, import/delete demo
  data, and **delete everything** (with confirmation).
- **Home-screen widget (Android)** — a **4×2** widget showing your next
  Course / Lab / Seminar / Test / Exam with a **countdown**, plus the item
  after it with its own time. Tap it to open the app.
- **Burning-calendar app icon.**
- **Data saved on device**; **light & dark** themes.

## Project structure

```
lib/
  main.dart                     App entry, theme, provider wiring
  models/
    schedule_item.dart          ScheduleItem, Homework, Task, ItemType + priorities
  data/
    sample_schedule.dart        Optional demo dataset (SampleData)
  services/
    notification_service.dart   Priority-based local notifications (sound/vibrate aware)
    widget_service.dart         Pushes "next item" data to the home widget
  state/
    schedule_store.dart         Items/homework/tasks state + persistence (ChangeNotifier)
    settings_store.dart         User preferences (sound, vibrate, theme, ...) + persistence
  screens/
    home_screen.dart            Bottom-nav shell (Grid / Day / What's next / Priority)
    week_grid_screen.dart       Excel-like weekly grid
    day_list_screen.dart        Day-by-day list
    whats_next_screen.dart      Upcoming items by time
    priority_screen.dart        Homework → Tests → Presentations → Exams
    item_details_screen.dart    Details + notification toggle + homework/task management
    item_editor_screen.dart     Add / edit form (with inline homework/tasks)
    homework_task_dialog.dart   Shared reminder editor (before-each / daily-until)
    settings_screen.dart        Notifications, appearance, demo data, danger zone
  widgets/
    color_utils.dart            Color contrast helper + subject palette
    date_format_utils.dart      Date + "time until" countdown formatting
```

Android home-screen widget (native) lives under `android_overlay/` and is
merged into the generated `android/` project by CI:

```
android_overlay/app/src/main/
  AndroidManifest.xml                          Permissions + notification/widget receivers
  kotlin/.../NextItemWidgetProvider.kt         4×2 widget provider
  res/layout/next_item_widget.xml              Widget layout
  res/xml/next_item_widget_info.xml            Widget config (4×2)
  res/drawable/widget_background.xml           Widget background
  proguard-rules.pro                           Keep rules for flutter_local_notifications
```

## Requirements

- **Flutter 3.19+** (Dart 3.3+). Works with current stable Flutter.
- Android Studio / Xcode as usual for device deployment.

## 📥 Downloading the app (no computer needed)

This repo builds the app automatically in the cloud with GitHub Actions and
publishes a downloadable Android file on the **Releases** page.

### Android — download & install (like an .exe)

**Direct download link:**
👉 https://github.com/Nub4Fun22/Schedule-Phoner/releases/latest

1. Open that link on your **Android phone**.
2. Download **`schedule-phoner.apk`**.
3. Tap the downloaded file.
4. When prompted, allow **"install from unknown sources"** (it's your own app).
5. Tap **Install**. Done. 🎉

> The APK on the **latest** release is rebuilt **automatically every time the
> code is updated** (any push to `main`), so it always has the newest fixes and
> features. Just re-download and reinstall to update.
>
> Pushing a version tag also creates a permanent, versioned release:
> ```bash
> git tag v1.1.0
> git push origin v1.1.0
> ```
> You can also trigger a build manually from the repo's **Actions** tab.

### iPhone / iOS — important

Unlike Android, **Apple does not allow installing iPhone apps from a downloaded
file**. There is no `.apk`/`.exe` equivalent you can just tap. iOS apps can only
be installed through one of:

- the **App Store** (requires an Apple Developer account, $99/year, + review),
- **TestFlight** (Apple's beta system, also needs the paid account), or
- **Xcode on a Mac** (plug in your own iPhone; free account works but the app
  expires after 7 days).

This is Apple's platform rule — no tool changes it. The code here is fully
iOS-ready: the CI builds it for iPhone to prove it compiles, so the moment you
have an Apple Developer account you can ship it to TestFlight or the App Store
without code changes. See **"Porting to iPhone later"** below.

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

- On first launch, Android 13+ prompts for notification permission (and the app
  also requests the exact-alarm permission).
- Weekly items repeat at each item's start time minus the chosen lead time;
  one-time items fire once. Homework/task reminders repeat before each
  occurrence of their lab/event (or daily until, if you chose that mode) and
  stop once marked **done** or past due.
- Sound and vibration are **off by default**; enable either in **Settings**.
- Use **Settings → Send a test notification / Test a scheduled reminder** to
  confirm delivery on your device.
- On some devices you may also want to allow "Alarms & reminders" / disable
  battery optimization for exact-time delivery.

## Building your schedule

Two easy options:

1. **In the app (no code):** Tap **Add**, choose a type (Course, Lab, Seminar,
   Test, Project, Presentation, Exam, or Event), fill in the details, and save.
   For a Lab/Seminar you can add **homework**, and for an Event you can add
   **tasks** — inline while creating, or later from the item's details screen.
   Everything is saved automatically on-device.
2. **Try the demo:** **Settings → Import demo data** loads one example of each
   type (kept alongside your own items); **Delete demo data** removes just the
   demo entries.

To tweak the demo dataset in code, edit `lib/data/sample_schedule.dart`. A
recurring item looks like:

   ```dart
   ScheduleItem(
     id: 'mon-math',
     type: ItemType.course,             // course/lab/seminar/test/...
     title: 'Mathematics',
     description: 'Calculus lecture',
     location: 'Room A1',
     oneTime: false,                    // weekly
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
