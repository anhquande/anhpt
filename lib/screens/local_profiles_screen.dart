import 'package:flutter/material.dart';

import '../models/health.dart';
import '../models/local_profile.dart';
import '../services/health_store.dart';
import '../widgets/profile_editor_dialog.dart';

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

  Future<void> _add() async {
    final result = await showProfileEditorDialog(
      context,
      title: 'Add profile',
      initialName: '',
      initialHealth: const HealthProfile(),
    );
    if (result == null) return;
    final profile = await _store.createLocalProfile(result.name);
    await _store.saveProfile(result.health, profile.id);
    await _store.setActiveProfile(profile.id);
    await _load();
  }

  Future<void> _edit(LocalProfile profile) async {
    final health = await _store.loadProfile(profile.id);
    if (!mounted) return;
    final result = await showProfileEditorDialog(
      context,
      title: 'Edit profile',
      initialName: profile.name,
      initialHealth: health,
    );
    if (result == null) return;
    await _store.renameLocalProfile(profile.id, result.name);
    await _store.saveProfile(result.health, profile.id);
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
              ? 'This profile has personal Health data. Deleting it permanently removes its profile details and weight measurements. Shared workouts are not deleted.'
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

  String _profileSummary(HealthProfile health) {
    final values = <String>[];
    if (health.birthYear != null) values.add('Born ${health.birthYear}');
    if (health.heightCm != null) {
      values.add('${health.heightCm!.toStringAsFixed(0)} cm');
    }
    if (health.sex != HealthSex.unspecified) values.add(health.sex.name);
    return values.isEmpty ? 'Profile details not completed' : values.join(' · ');
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
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final profile = _profiles[index];
                final active = profile.id == _activeId;
                return FutureBuilder<HealthProfile>(
                  future: _store.loadProfile(profile.id),
                  builder: (context, snapshot) {
                    final health = snapshot.data ?? const HealthProfile();
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        leading: CircleAvatar(
                          child: Text(
                            profile.name.trim().isEmpty
                                ? '?'
                                : profile.name.trim()[0].toUpperCase(),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(profile.name)),
                            if (active)
                              const Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text('Active'),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_profileSummary(health)),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'active') {
                              await _store.setActiveProfile(profile.id);
                              await _load();
                            } else if (value == 'edit') {
                              await _edit(profile);
                            } else if (value == 'delete') {
                              await _delete(profile);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit profile'),
                            ),
                            if (!active)
                              const PopupMenuItem(
                                value: 'active',
                                child: Text('Make active'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                        onTap: () => _edit(profile),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
