import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/theme_preference.dart';
import '../app/workout_camera_preference.dart';
import '../services/coach_recording_service.dart';
import '../services/update_service.dart';
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

  bool get _cameraSupported => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  String get _cameraSubtitle => switch (defaultTargetPlatform) {
        TargetPlatform.windows =>
          'Use a built-in or USB webcam for live workout comparison.',
        TargetPlatform.android || TargetPlatform.iOS =>
          'Use the front camera for live workout comparison.',
        _ => 'Workout camera is not supported on this platform.',
      };

  String _updateStatus(UpdateService updater) {
    switch (updater.status) {
      case UpdateStatus.checking:
        return 'Checking for updates…';
      case UpdateStatus.downloading:
        return 'Downloading ${(updater.downloadProgress * 100).round()}%';
      case UpdateStatus.ready:
        return 'Update downloaded';
      case UpdateStatus.installing:
        return 'Starting installer…';
      case UpdateStatus.available:
        return 'Version ${updater.latestVersion} is available';
      case UpdateStatus.upToDate:
        return 'You are up to date';
      case UpdateStatus.error:
        return updater.errorMessage ?? 'Update check failed';
      case UpdateStatus.idle:
        return updater.autoUpdateEnabled
            ? 'Checks and installs updates before the app starts'
            : 'Off by default; enable to update before startup';
    }
  }

  @override
  Widget build(BuildContext context) {
    WorkoutCameraPreference.instance.initialize();
    UpdateService.instance.initialize();
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
                          DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                          DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(),
                AnimatedBuilder(
                  animation: WorkoutCameraPreference.instance,
                  builder: (context, _) {
                    final preference = WorkoutCameraPreference.instance;
                    return Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.videocam_outlined),
                          title: const Text('Start workout camera automatically'),
                          subtitle: Text(_cameraSubtitle),
                          value: _cameraSupported && preference.autoStart,
                          onChanged: _cameraSupported ? preference.setAutoStart : null,
                        ),
                        ListTile(
                          leading: const Icon(Icons.view_quilt_outlined),
                          title: const Text('Default camera layout'),
                          subtitle: const Text('Used when camera and demonstration are both visible.'),
                          trailing: DropdownButton<WorkoutCameraLayout>(
                            value: preference.layout,
                            onChanged: _cameraSupported
                                ? (value) {
                                    if (value != null) preference.setLayout(value);
                                  }
                                : null,
                            items: [
                              for (final layout in WorkoutCameraLayout.values)
                                DropdownMenuItem(value: layout, child: Text(layout.label)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const Divider(),
                AnimatedBuilder(
                  animation: UpdateService.instance,
                  builder: (context, _) {
                    final updater = UpdateService.instance;
                    if (!updater.supported) return const SizedBox.shrink();
                    final busy = updater.status == UpdateStatus.checking ||
                        updater.status == UpdateStatus.downloading ||
                        updater.status == UpdateStatus.installing;
                    return Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.system_update_alt),
                          title: const Text('Automatic updates'),
                          subtitle: Text(_updateStatus(updater)),
                          value: updater.autoUpdateEnabled,
                          onChanged: updater.setAutoUpdateEnabled,
                        ),
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: Text('Current version ${updater.currentVersion.isEmpty ? '…' : updater.currentVersion}'),
                          subtitle: Text(updater.latestVersion == null
                              ? 'Latest version not checked yet'
                              : 'Latest release ${updater.latestVersion}'),
                          trailing: updater.status == UpdateStatus.available
                              ? FilledButton(
                                  onPressed: busy ? null : updater.downloadAndInstall,
                                  child: const Text('Update now'),
                                )
                              : OutlinedButton(
                                  onPressed: busy
                                      ? null
                                      : () => updater.checkForUpdates(autoInstall: false),
                                  child: const Text('Check now'),
                                ),
                        ),
                        if (updater.status == UpdateStatus.downloading)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: LinearProgressIndicator(value: updater.downloadProgress),
                          ),
                      ],
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
                    MaterialPageRoute(builder: (_) => BucketSourcesScreen(controller: controller)),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.mic_outlined),
                  title: const Text('Microphone access'),
                  subtitle: Text(!kIsWeb && defaultTargetPlatform == TargetPlatform.windows
                      ? 'Coach recording requires microphone access for desktop apps. Manage it in Windows Privacy settings.'
                      : 'Enable microphone access for AnhPT in your system or browser settings.'),
                  trailing: !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
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
                      DropdownMenuItem(value: 'vi', child: Text('Vietnamese')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (value) {
                      if (value != null) controller.updateDefaultVoiceLanguage(value);
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
                    MaterialPageRoute(builder: (_) => MusicLibraryScreen(controller: controller)),
                  ),
                ),
                const Divider(),
                AnimatedBuilder(
                  animation: UpdateService.instance,
                  builder: (context, _) => ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About'),
                    subtitle: Text('AnhPT ${UpdateService.instance.currentVersion}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
