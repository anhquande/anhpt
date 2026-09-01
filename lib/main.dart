import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

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

  final updater = UpdateService.instance;
  if (updater.supported && updater.autoUpdateEnabled) {
    runApp(const UpdateStartupApp());
    await updater.checkOnStartup();
  }

  runApp(AnhPtApp(controller: controller));
}

class UpdateStartupMessage {
  final String title;
  final String text;

  const UpdateStartupMessage(this.title, this.text);
}

class UpdateStartupApp extends StatefulWidget {
  const UpdateStartupApp({super.key});

  @override
  State<UpdateStartupApp> createState() => _UpdateStartupAppState();
}

class _UpdateStartupAppState extends State<UpdateStartupApp> {
  static const _fallbackFeature = UpdateStartupMessage(
    'NEW IN AnhPT',
    'Discover new ways to make every workout clearer, simpler, and more motivating.',
  );

  static const _fallbackQuote = UpdateStartupMessage(
    'KEEP MOVING',
    'Consistency beats intensity. A short workout today still moves you forward.',
  );

  List<UpdateStartupMessage> _messages = const [
    _fallbackFeature,
    _fallbackQuote,
  ];
  int _messageIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadStartupContent();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _messages.isNotEmpty) {
        setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
      }
    });
  }

  Future<List<UpdateStartupMessage>> _loadMessages(
    String assetPath,
    String rootKey,
  ) async {
    final source = await rootBundle.loadString(assetPath);
    final yaml = loadYaml(source);
    final rawItems = yaml is YamlMap ? yaml[rootKey] : null;
    if (rawItems is! YamlList) return const [];

    final messages = <UpdateStartupMessage>[];
    for (final entry in rawItems) {
      if (entry is! YamlMap) continue;
      final title = entry['title']?.toString().trim() ?? '';
      final text = entry['text']?.toString().trim() ?? '';
      if (title.isEmpty || text.isEmpty) continue;
      messages.add(UpdateStartupMessage(title, text));
    }
    return messages;
  }

  Future<void> _loadStartupContent() async {
    var features = <UpdateStartupMessage>[];
    var quotes = <UpdateStartupMessage>[];

    try {
      features = await _loadMessages(
        'assets/content/whats_new.yaml',
        'items',
      );
    } catch (_) {
      // Optional promotional content must never block app startup.
    }

    try {
      quotes = await _loadMessages(
        'assets/content/motivational_quotes.yaml',
        'quotes',
      );
    } catch (_) {
      // Optional motivational content must never block app startup.
    }

    if (!mounted) return;
    setState(() {
      _messages = [
        ...(features.isEmpty ? const [_fallbackFeature] : features),
        ...(quotes.isEmpty ? const [_fallbackQuote] : quotes),
      ];
      _messageIndex %= _messages.length;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _status(UpdateService updater) => switch (updater.status) {
        UpdateStatus.checking => 'Checking for updates…',
        UpdateStatus.available => 'Preparing version ${updater.latestVersion ?? ''}…',
        UpdateStatus.downloading => 'Downloading update… ${(updater.downloadProgress * 100).round()}%',
        UpdateStatus.ready => 'Update downloaded',
        UpdateStatus.installing => 'Installing update…',
        UpdateStatus.upToDate => 'AnhPT is up to date',
        UpdateStatus.error => 'Could not check for updates. Starting current version…',
        UpdateStatus.idle => 'Preparing update check…',
      };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemePreference.instance.mode,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF4F46E5)),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark, colorSchemeSeed: const Color(0xFF4F46E5)),
      home: Scaffold(
        body: SafeArea(
          child: AnimatedBuilder(
            animation: UpdateService.instance,
            builder: (context, _) {
              final updater = UpdateService.instance;
              final message = _messages[_messageIndex];
              final downloading = updater.status == UpdateStatus.downloading;
              return Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('AnhPT', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: ConstrainedBox(
                            key: ValueKey(_messageIndex),
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(message.title, style: Theme.of(context).textTheme.labelLarge),
                                const SizedBox(height: 16),
                                Text(
                                  message.text,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(_status(updater), textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(value: downloading && updater.downloadProgress > 0 ? updater.downloadProgress : null),
                          const SizedBox(height: 8),
                          Text(
                            downloading ? 'Keep AnhPT open while the update downloads.' : 'Getting AnhPT ready…',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
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
