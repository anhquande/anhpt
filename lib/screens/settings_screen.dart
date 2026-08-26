import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import 'music_library_screen.dart';

class SettingsScreen extends StatelessWidget {
  final AppController controller;
  const SettingsScreen({super.key, required this.controller});

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
                const ListTile(
                  leading: Icon(Icons.brightness_6_outlined),
                  title: Text('Appearance'),
                  subtitle: Text('System (Light/Dark follows device)'),
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
