import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../models/local_profile.dart';
import '../models/workout.dart';
import '../services/health_store.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/workout_widgets.dart';
import 'health_screen.dart';
import 'local_profiles_screen.dart';
import 'settings_screen.dart';
import 'workout_builder_screen.dart';
import 'workout_detail_screen.dart';
import 'workout_editor_screen.dart';
import 'workout_player_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppController controller;
  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';
  final _searchController = TextEditingController();
  final HealthStore _healthStore = HealthStore();
  List<LocalProfile> _profiles = [];
  LocalProfile? _activeProfile;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await _healthStore.loadLocalProfiles();
    final active = await _healthStore.activeLocalProfile();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _activeProfile = active;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openDetail(BuildContext context, Workout w) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                WorkoutDetailScreen(controller: controller, workoutId: w.id)));
  }

  Future<void> _start(BuildContext context, Workout w) async {
    await _loadProfiles();
    if (!mounted) return;
    final participant = _activeProfile;
    controller.markUsed(w.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutPlayerScreen(
          controller: controller,
          workoutId: w.id,
          profileId: participant?.id,
          profileName: participant?.name,
        ),
      ),
    );
  }

  Future<void> _chooseActiveProfile() async {
    await _loadProfiles();
    if (!mounted) return;
    final selected = await showModalBottomSheet<LocalProfile>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Active profile',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Health data and future workout history stay separate.'),
            ),
            for (final profile in _profiles)
              ListTile(
                leading: ProfileAvatar(profile: profile),
                title: Text(profile.name),
                trailing: profile.id == _activeProfile?.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, profile),
              ),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Manage profiles'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  this.context,
                  MaterialPageRoute(builder: (_) => const LocalProfilesScreen()),
                );
                await _loadProfiles();
              },
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _healthStore.setActiveProfile(selected.id);
    await _loadProfiles();
  }

  Future<void> _importPackage() async {
    try {
      final imported = await controller.importWorkoutPackage();
      if (mounted && imported) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout package imported.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $error')),
        );
      }
    }
  }

  bool _matches(Workout workout) {
    final needle = _normalize(_query.trim());
    if (needle.isEmpty) return true;
    return _normalize([
      workout.name,
      workout.description,
      ...workout.tags,
    ].join(' '))
        .contains(needle);
  }

  static String _normalize(String value) {
    var normalized = value.toLowerCase();
    const source =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const target =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    for (var index = 0; index < source.length; index++) {
      normalized = normalized.replaceAll(source[index], target[index]);
    }
    return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton.icon(
            onPressed: _chooseActiveProfile,
            icon: _activeProfile == null
                ? const Icon(Icons.person_outline)
                : ProfileAvatar(profile: _activeProfile!, radius: 13),
            label: Text(_activeProfile?.name ?? 'Profile'),
          ),
          IconButton(
            tooltip: 'Health',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HealthScreen()),
              );
              await _loadProfiles();
            },
            icon: const Icon(Icons.favorite_outline),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SettingsScreen(controller: controller))),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final favorites = controller.favorites.where(_matches).toList();
          final others = controller.others.where(_matches).toList();
          final noResults = favorites.isEmpty && others.isEmpty;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WorkoutBuilderScreen(
                                controller: controller,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('New workout'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        tooltip: 'More ways to add',
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'package') {
                            _importPackage();
                          } else if (value == 'yaml') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WorkoutEditorScreen(
                                  controller: controller,
                                  importMode: true,
                                ),
                              ),
                            );
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'package',
                            child: ListTile(
                              leading: Icon(Icons.unarchive_outlined),
                              title: Text('Import package'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'yaml',
                            child: ListTile(
                              leading: Icon(Icons.code),
                              title: Text('Import YAML'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      filled: true,
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search my workouts',
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 26),
                  if (favorites.isNotEmpty) ...[
                    _HomeSectionHeader(
                        title: 'Favorites', count: favorites.length),
                    const SizedBox(height: 10),
                    for (final workout in favorites) ...[
                      WorkoutCard(
                        workout: workout,
                        sourceName: _sourceNameFor(workout),
                        originalName: _originalNameFor(workout),
                        onOpen: () => _openDetail(context, workout),
                        onStart: () => _start(context, workout),
                        onFavorite: () => controller.toggleFavorite(workout.id),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 18),
                  ],
                  if (others.isNotEmpty) ...[
                    _HomeSectionHeader(
                        title: 'All workouts', count: others.length),
                    const SizedBox(height: 10),
                    for (final workout in others) ...[
                      WorkoutCard(
                        workout: workout,
                        sourceName: _sourceNameFor(workout),
                        originalName: _originalNameFor(workout),
                        onOpen: () => _openDetail(context, workout),
                        onStart: () => _start(context, workout),
                        onFavorite: () => controller.toggleFavorite(workout.id),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                  if (noResults)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            _query.isEmpty
                                ? Icons.fitness_center_outlined
                                : Icons.search_off_outlined,
                            size: 36,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _query.isEmpty
                                ? 'Create your first workout.'
                                : 'No workouts match “$_query”.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String? _sourceNameFor(Workout workout) {
    final provenance = controller.bucketProvenanceFor(workout.id);
    return provenance == null ? null : controller.bucketSourceName(provenance);
  }

  String? _originalNameFor(Workout workout) {
    final provenance = controller.bucketProvenanceFor(workout.id);
    return provenance == null
        ? null
        : controller.bucketOriginalName(provenance);
  }
}

class _HomeSectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _HomeSectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '$count',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
