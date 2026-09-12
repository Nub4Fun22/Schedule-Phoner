import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'state/schedule_store.dart';
import 'state/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications (timezone + channel) before the app starts.
  await NotificationService.instance.init();

  runApp(const SchoolScheduleApp());
}

class SchoolScheduleApp extends StatelessWidget {
  const SchoolScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsStore>(
          create: (_) => SettingsStore()..load(),
        ),
        ChangeNotifierProvider<ScheduleStore>(
          create: (_) => ScheduleStore()..load(),
        ),
      ],
      child: Consumer<SettingsStore>(
        builder: (context, settings, _) => MaterialApp(
          title: 'School Schedule',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: settings.themeMode,
          home: const HomeScreen(),
        ),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3F51B5),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(centerTitle: false),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
