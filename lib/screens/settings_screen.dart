import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/theme_preference.dart';
import '../services/coach_recording_service.dart';
import 'bucket_sources_screen.dart';
import 'music_library_screen.dart';

class SettingsScreen extends StatelessWidget {
  final AppController controller;
  const SettingsScreen({super.key, required this.controller});

  Future<void> _openMicrophoneSettings(BuildContext context) async {
    try {
      await CoachRecordingService.openSystemMicrophoneSettings();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not open microphone settings: $error')));
      }
    }
  }

  String _appearanceLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System (follows device)',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  IconData _appearanceIcon(ThemeMode mode) => switch (mode) {
        ThemeMode.system => Icons.brightness_auto_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, __) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AnimatedBuilder(
                  animation: ThemePreference.instance,
                  builder: (context, _) {
                    final mode = ThemePreference.instance.mode;
                    return ListTile(
                      leading: Icon(_appearanceIcon(mode)),
                      title: const Text('Appearance'),
                      subtitle: Text(_appearanceLabel(mode)),
                      trailing: DropdownButton<ThemeMode>(
                        value: mode,
                        onChanged: (value) {
                          if (value != null) {
                            ThemePreference.instance.setMode(value);
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text('System'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text('Light'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text('Dark'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Workout sources'),
                  subtitle: const Text('Manage public catalog sources'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          BucketSourcesScreen(controller: controller),
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.mic_outlined),
                  title: const Text('Microphone access'),
                  subtitle: Text(!kIsWeb &&
                          defaultTargetPlatform == TargetPlatform.windows
                      ? 'Coach recording requires microphone access for desktop apps. Manage it in Windows Privacy settings.'
                      : 'Enable microphone access for AnhPT in your system or browser settings.'),
                  trailing:
                      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
                          ? OutlinedButton.icon(
                              onPressed: () => _openMicrophoneSettings(context),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Open settings'),
                            )
                          : null,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.record_voice_over_outlined),
                  title: const Text('Default Voice Language'),
                  trailing: DropdownButton<String>(
                    value: controller.defaultVoiceLanguage,
                    items: const [
                      DropdownMenuItem(
                        value: 'vi',
                        child: Text('Vietnamese'),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text('English'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        controller.updateDefaultVoiceLanguage(value);
                      }
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.library_music_outlined),
                  title: const Text('Offline Music Library'),
                  subtitle: const Text('Bundled and personal tracks'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              MusicLibraryScreen(controller: controller))),
                ),
                const Divider(),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About'),
                  subtitle: Text('AnhPT Integrated MVP v0.6'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
