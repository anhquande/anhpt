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
  String _selectedFilter = 'all';
  final _searchController = TextEditingController();
  final HealthStore _healthStore = HealthStore();
  List<LocalProfile> _profiles = [];
  LocalProfile? _activeProfile;
  List<String> _tagOrder = [];
  Set<String> _hiddenTags = {};

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _loadTagPreferences();
  }

  Future<void> _loadTagPreferences() async {
    final order = await controller.store.loadQuickFilterTagOrder();
    final hidden = await controller.store.loadQuickFilterHiddenTags();
    if (!mounted) return;
    setState(() {
      _tagOrder = order;
      _hiddenTags = hidden;
    });
  }

  Future<void> _saveTagPreferences() =>
      controller.store.saveQuickFilterPreferences(
        orderedTags: _tagOrder,
        hiddenTags: _hiddenTags,
      );

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

  Future<void> _start(BuildContext context, Workout w) async {
    await _loadProfiles();
    if (!context.mounted) return;
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
              subtitle:
                  Text('Health data and future workout history stay separate.'),
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

  bool _matchesSearch(Workout workout) {
    final needle = _normalize(_query.trim());
    if (needle.isEmpty) return true;
    return _normalize([
      workout.name,
      workout.description,
      ...workout.tags,
    ].join(' '))
        .contains(needle);
  }

  bool _matchesFilter(Workout workout) {
    if (_selectedFilter == 'all') return true;
    if (_selectedFilter == 'recent') return workout.lastUsedAt != null;
    if (_selectedFilter == 'favorites') {
      return controller.favorites.any((favorite) => favorite.id == workout.id);
    }
    return workout.tags.any((tag) => _normalize(tag) == _selectedFilter);
  }

  List<Workout> _allWorkouts() => List<Workout>.from(controller.workouts);

  List<String> _availableTags(List<Workout> workouts) {
    final tagsByKey = <String, String>{};
    for (final workout in workouts) {
      for (final tag in workout.tags) {
        final trimmed = tag.trim();
        if (trimmed.isEmpty) continue;
        tagsByKey.putIfAbsent(_normalize(trimmed), () => trimmed);
      }
    }
    final knownKeys = tagsByKey.keys.toSet();
    final orderedKeys = <String>[
      ..._tagOrder.where(knownKeys.contains),
      ...knownKeys.where((key) => !_tagOrder.contains(key))
        ..toList().sort((a, b) =>
            tagsByKey[a]!.toLowerCase().compareTo(tagsByKey[b]!.toLowerCase())),
    ];
    return orderedKeys.map((key) => tagsByKey[key]!).toList();
  }

  Future<void> _manageTags(List<String> tags) async {
    final displayByKey = _normalizeTags(tags);
    final allKeys = tags.map(_normalize).toList();
    var draftOrder = <String>[
      ..._tagOrder.where(allKeys.contains),
      ...allKeys.where((key) => !_tagOrder.contains(key)),
    ];
    var draftHidden = Set<String>.from(_hiddenTags);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.tune),
                  title: Text('Manage tags',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Drag to reorder. Hide tags you do not need.'),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: draftOrder.length,
                    onReorder: (oldIndex, newIndex) {
                      setSheetState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = draftOrder.removeAt(oldIndex);
                        draftOrder.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final key = draftOrder[index];
                      final label = displayByKey[key] ?? key;
                      final visible = !draftHidden.contains(key);
                      return SwitchListTile(
                        key: ValueKey(key),
                        secondary: const Icon(Icons.drag_handle),
                        title: Text(label),
                        value: visible,
                        onChanged: (value) => setSheetState(() {
                          if (value) {
                            draftHidden.remove(key);
                          } else {
                            draftHidden.add(key);
                          }
                        }),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => setSheetState(() {
                          draftOrder = List<String>.from(allKeys);
                          draftHidden.clear();
                        }),
                        child: const Text('Reset'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;
    setState(() {
      _tagOrder = draftOrder;
      _hiddenTags = draftHidden;
      if (_hiddenTags.contains(_selectedFilter)) _selectedFilter = 'all';
    });
    await _saveTagPreferences();
  }

  Map<String, String> _normalizeTags(List<String> tags) => {
        for (final tag in tags) _normalize(tag): tag,
      };

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
          final allWorkouts = _allWorkouts();
          final tags = _availableTags(allWorkouts);
          final visibleTags = tags
              .where((tag) => !_hiddenTags.contains(_normalize(tag)))
              .toList();
          final visibleWorkouts = allWorkouts
              .where(_matchesSearch)
              .where(_matchesFilter)
              .toList();
          if (_selectedFilter == 'recent') {
            visibleWorkouts.sort(
              (a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!),
            );
          }
          final noResults = visibleWorkouts.isEmpty;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            filled: true,
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search workouts',
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
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        tooltip: 'Workout actions',
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'new') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WorkoutBuilderScreen(
                                  controller: controller,
                                ),
                              ),
                            );
                          } else if (value == 'package') {
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
                            value: 'new',
                            child: ListTile(
                              leading: Icon(Icons.add),
                              title: Text('Create new workout'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
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
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 42,
                    child: Row(
                      children: [
                        Expanded(
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ChoiceChip(
                                label: const Text('All'),
                                selected: _selectedFilter == 'all',
                                onSelected: (_) =>
                                    setState(() => _selectedFilter = 'all'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Recent'),
                                selected: _selectedFilter == 'recent',
                                onSelected: (_) =>
                                    setState(() => _selectedFilter = 'recent'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Favors'),
                                selected: _selectedFilter == 'favorites',
                                onSelected: (_) => setState(
                                    () => _selectedFilter = 'favorites'),
                              ),
                              for (final tag in visibleTags) ...[
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: Text(tag),
                                  selected:
                                      _selectedFilter == _normalize(tag),
                                  onSelected: (_) => setState(
                                    () => _selectedFilter = _normalize(tag),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Manage tags',
                          onPressed: () => _manageTags(tags),
                          icon: const Icon(Icons.tune),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final workout in visibleWorkouts) ...[
                    WorkoutCard(
                      workout: workout,
                      sourceName: _sourceNameFor(workout),
                      originalName: _originalNameFor(workout),
                      onStart: () => _start(context, workout),
                      onFavorite: () => controller.toggleFavorite(workout.id),
                    ),
                    const SizedBox(height: 10),
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
                                ? 'No workouts in this filter.'
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
