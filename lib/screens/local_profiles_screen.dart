import 'package:flutter/material.dart';

import '../models/local_profile.dart';
import '../services/health_store.dart';

class LocalProfilesScreen extends StatefulWidget {
  const LocalProfilesScreen({super.key});

  @override
  State<LocalProfilesScreen> createState() => _LocalProfilesScreenState();
}

class _LocalProfilesScreenState extends State<LocalProfilesScreen> {
  final HealthStore _store = HealthStore();
  List<LocalProfile> _profiles = [];
  String? _activeId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await _store.loadLocalProfiles();
    final active = await _store.activeLocalProfile();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _activeId = active.id;
      _loading = false;
    });
  }

  Future<String?> _askName(String title, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return result == null || result.trim().isEmpty ? null : result.trim();
  }

  Future<void> _add() async {
    final name = await _askName('Add profile');
    if (name == null) return;
    final profile = await _store.createLocalProfile(name);
    await _store.setActiveProfile(profile.id);
    await _load();
  }

  Future<void> _rename(LocalProfile profile) async {
    final name = await _askName('Rename profile', initial: profile.name);
    if (name == null || name == profile.name) return;
    await _store.renameLocalProfile(profile.id, name);
    await _load();
  }

  Future<void> _delete(LocalProfile profile) async {
    final hasData = await _store.profileHasHealthData(profile.id);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${profile.name}?'),
        content: Text(
          hasData
              ? 'This profile has Health data. Deleting it permanently removes its profile settings and weight measurements. Shared workouts are not deleted.'
              : 'This removes the local profile. Shared workouts are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _store.deleteLocalProfile(profile.id);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add profile'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: _profiles.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final profile = _profiles[index];
                final active = profile.id == _activeId;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(profile.name.trim().isEmpty
                        ? '?'
                        : profile.name.trim()[0].toUpperCase()),
                  ),
                  title: Text(profile.name),
                  subtitle: Text(active ? 'Active profile' : 'Local profile'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'active') {
                        await _store.setActiveProfile(profile.id);
                        await _load();
                      } else if (value == 'rename') {
                        await _rename(profile);
                      } else if (value == 'delete') {
                        await _delete(profile);
                      }
                    },
                    itemBuilder: (_) => [
                      if (!active)
                        const PopupMenuItem(
                          value: 'active',
                          child: Text('Make active'),
                        ),
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                  onTap: active
                      ? null
                      : () async {
                          await _store.setActiveProfile(profile.id);
                          await _load();
                        },
                );
              },
            ),
    );
  }
}
