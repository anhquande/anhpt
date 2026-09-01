import 'package:flutter/material.dart';

import 'app/app_controller.dart';
import 'app/theme_preference.dart';
import 'app/workout_camera_preference.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/local_store.dart';
import 'services/update_service.dart';
import 'services/workout_yaml_file_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(
    LocalStore(),
    yamlFileStore: WorkoutYamlFileStore(),
  );
  await Future.wait([
    controller.initialize(),
    ThemePreference.instance.initialize(),
    WorkoutCameraPreference.instance.initialize(),
    UpdateService.instance.initialize(),
  ]);

  // When automatic updates are enabled, finish the startup update flow before
  // entering the main application. Update installers terminate this process
  // when an update is launched; otherwise startup continues normally.
  await UpdateService.instance.checkOnStartup();

  runApp(AnhPtApp(controller: controller));
}

class AnhPtApp extends StatelessWidget {
  final AppController controller;
  const AnhPtApp({super.key, required this.controller});

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF7F7FA)
          : const Color(0xFF101114),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: .35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemePreference.instance,
      builder: (_, __) => AnimatedBuilder(
        animation: controller,
        builder: (_, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'AnhPT',
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: ThemePreference.instance.mode,
          home: controller.loading
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                )
              : controller.onboarded
                  ? HomeScreen(controller: controller)
                  : OnboardingScreen(
                      onContinue: controller.completeOnboarding,
                    ),
        ),
      ),
    );
  }
}
