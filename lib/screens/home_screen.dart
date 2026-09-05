import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../models/local_profile.dart';
import '../models/workout.dart';
import '../models/workout_bucket.dart';
import '../services/health_store.dart';
import '../services/workout_update_service.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/workout_widgets.dart';
import 'bucket_sources_screen.dart';
import 'health_screen.dart';
import 'local_profiles_screen.dart';
import 'settings_screen.dart';
import 'workout_builder_screen.dart';
import 'workout_detail_screen.dart';
import 'workout_download_screen.dart';
import 'workout_editor_screen.dart';

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
  bool _isRefreshing = false;
  String? _syncMessage;
  bool _syncHasError = false;
  Timer? _syncMessageTimer;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _loadTagPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshWorkouts());
  }

  Future<void> _refreshWorkouts() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _showSyncMessage('Checking workout sources…');
    final errors = <String>[];
    try {
      await controller.refreshAllBucketSources();
      if (controller.bucketCatalogError != null) {
        errors.add(controller.bucketCatalogError!);
      }
    } catch (error) {
      errors.add('$error');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
        if (errors.isNotEmpty) {
          _showSyncMessage(
            'Could not refresh workout listings: ${errors.first}',
            hasError: true,
            hideAfter: const Duration(seconds: 12),
          );
        } else {
          final count = controller.bucketCatalogEntries.length;
          _showSyncMessage(
            'Loaded $count workout ${count == 1 ? 'listing' : 'listings'}.',
            hideAfter: const Duration(seconds: 5),
          );
        }
      }
    }
  }

  void _showSyncMessage(
    String message, {
    bool hasError = false,
    Duration? hideAfter,
  }) {
    _syncMessageTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _syncMessage = message;
      _syncHasError = hasError;
    });
    if (hideAfter != null) {
      _syncMessageTimer = Timer(hideAfter, () {
        if (mounted) setState(() => _syncMessage = null);
      });
    }
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
    _syncMessageTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openWorkout(BuildContext context, Workout workout) async {
    await controller.store.markWorkoutSeen(workout.id);
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WorkoutDetailScreen(controller: controller, workoutId: workout.id),
      ),
    );
  }

  Future<void> _openWorkoutSources() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BucketSourcesScreen(controller: controller),
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
              title: Text(
                'Active profile',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Health data and future workout history stay separate.',
              ),
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
                  MaterialPageRoute(
                    builder: (_) => const LocalProfilesScreen(),
                  ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
      }
    }
  }

  bool _matchesSearch(Workout workout) {
    final needle = _normalize(_query.trim());
    if (needle.isEmpty) return true;
    return _normalize(
      [workout.name, workout.description, ...workout.tags].join(' '),
    ).contains(needle);
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

  List<WorkoutBucketEntry> _catalogWorkouts() => controller.bucketCatalogEntries
      .where((entry) => controller.bucketInstallState(entry) == 'notInstalled')
      .toList();

  bool _matchesCatalogSearch(WorkoutBucketEntry entry) {
    final needle = _normalize(_query.trim());
    if (needle.isEmpty) return true;
    return _normalize(
      [
        entry.name,
        entry.description,
        entry.author ?? '',
        _bucketSourceName(entry.sourceId),
        ...entry.tags,
      ].join(' '),
    ).contains(needle);
  }

  bool _matchesCatalogFilter(WorkoutBucketEntry entry) {
    if (_selectedFilter == 'all') return true;
    if (_selectedFilter == 'favorites' || _selectedFilter == 'recent') {
      return false;
    }
    return _normalizeTags(entry.tags).containsKey(_selectedFilter);
  }

  String _bucketSourceName(String? sourceId) {
    for (final source in controller.bucketSources) {
      if (source.id == sourceId) return source.name;
    }
    return sourceId ?? 'Workout source';
  }

  Future<void> _openCatalogWorkout(WorkoutBucketEntry entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutDownloadScreen(
          controller: controller,
          entry: entry,
          sourceName: _bucketSourceName(entry.sourceId),
        ),
      ),
    );
  }

  List<String> _availableTags(
    List<Workout> workouts, [
    List<WorkoutBucketEntry> catalogEntries = const [],
  ]) {
    final tagsByKey = <String, String>{};
    for (final workout in workouts) {
      for (final tag in workout.tags) {
        final trimmed = tag.trim();
        if (trimmed.isEmpty) continue;
        tagsByKey.putIfAbsent(_normalize(trimmed), () => trimmed);
      }
    }
    for (final entry in catalogEntries) {
      for (final tag in entry.tags) {
        final trimmed = tag.trim();
        if (trimmed.isEmpty) continue;
        tagsByKey.putIfAbsent(_normalize(trimmed), () => trimmed);
      }
    }
    final knownKeys = tagsByKey.keys.toSet();
    final orderedKeys = <String>[
      ..._tagOrder.where(knownKeys.contains),
      ...knownKeys.where((key) => !_tagOrder.contains(key)),
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
                  title: Text(
                    'Manage tags',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('Drag to reorder. Hide tags you do not need.'),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: draftOrder.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setSheetState(() {
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
                        secondary: ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
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
        title: const Text(
          'Workouts',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh workouts',
            onPressed: _isRefreshing ? null : _refreshWorkouts,
            icon: const Icon(Icons.refresh),
          ),
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
                builder: (_) => SettingsScreen(controller: controller),
              ),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final allWorkouts = _allWorkouts();
          final catalogWorkouts = _catalogWorkouts();
          final tags = _availableTags(allWorkouts, catalogWorkouts);
          final visibleTags = tags
              .where((tag) => !_hiddenTags.contains(_normalize(tag)))
              .toList();
          final visibleWorkouts = allWorkouts
              .where(_matchesSearch)
              .where(_matchesFilter)
              .toList();
          final visibleCatalogWorkouts = catalogWorkouts
              .where(_matchesCatalogSearch)
              .where(_matchesCatalogFilter)
              .toList();
          if (_selectedFilter == 'recent') {
            visibleWorkouts.sort(
              (a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!),
            );
          }
          final noResults =
              visibleWorkouts.isEmpty && visibleCatalogWorkouts.isEmpty;

          return RefreshIndicator(
            onRefresh: _refreshWorkouts,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                            onChanged: (value) =>
                                setState(() => _query = value),
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
                            } else if (value == 'sources') {
                              _openWorkoutSources();
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
                            PopupMenuItem(
                              value: 'sources',
                              child: ListTile(
                                leading: Icon(Icons.cloud_outlined),
                                title: Text('Workout sources'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _syncMessage == null
                          ? const SizedBox.shrink()
                          : Container(
                              key: ValueKey(_syncMessage),
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _syncHasError
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.errorContainer
                                    : Theme.of(
                                        context,
                                      ).colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  if (_isRefreshing) ...[
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ] else ...[
                                    Icon(
                                      _syncHasError
                                          ? Icons.error_outline
                                          : Icons.check_circle_outline,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(_syncMessage!),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                                  onSelected: (_) => setState(
                                    () => _selectedFilter = 'recent',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Favors'),
                                  selected: _selectedFilter == 'favorites',
                                  onSelected: (_) => setState(
                                    () => _selectedFilter = 'favorites',
                                  ),
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
                        bucketEntry: controller.bucketEntryForWorkout(
                          workout.id,
                        ),
                        bucketService: controller.workoutBuckets,
                        sourceName: _sourceNameFor(workout),
                        originalName: _originalNameFor(workout),
                        availableUpdateVersion: controller
                            .updateForWorkout(workout.id)
                            ?.availableVersion,
                        onStart: () => _openWorkout(context, workout),
                        onFavorite: () => controller.toggleFavorite(workout.id),
                      ),
                      const SizedBox(height: 10),
                    ],
                    for (final entry in visibleCatalogWorkouts) ...[
                      CatalogWorkoutCard(
                        entry: entry,
                        sourceName: _bucketSourceName(entry.sourceId),
                        bucketService: controller.workoutBuckets,
                        onTap: () => _openCatalogWorkout(entry),
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _query.isEmpty
                                  ? 'No workouts in this filter.'
                                  : 'No workouts match “$_query”.',
                              textAlign: TextAlign.center,
                            ),
                            if (_query.trim().isNotEmpty) ...[
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _openWorkoutSources,
                                icon: const Icon(Icons.cloud_outlined),
                                label: const Text('Manage workout sources'),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
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
