import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../models/workout_bucket.dart';
import 'bucket_sources_screen.dart';
import 'workout_detail_screen.dart';

enum _CatalogStatus { all, notInstalled, installed, updates }

enum _CatalogSort { recommended, nameAscending, nameDescending }

class BucketCatalogScreen extends StatefulWidget {
  final AppController controller;

  const BucketCatalogScreen({super.key, required this.controller});

  @override
  State<BucketCatalogScreen> createState() => _BucketCatalogScreenState();
}

class _BucketCatalogScreenState extends State<BucketCatalogScreen> {
  String _query = '';
  String? _sourceId;
  _CatalogStatus _status = _CatalogStatus.all;
  _CatalogSort _sort = _CatalogSort.recommended;
  String? _installingId;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) setState(() => _query = value);
    });
  }

  Future<void> _install(
    WorkoutBucketEntry entry, {
    BucketInstallConflictResolution? resolution,
  }) async {
    final existingWorkoutIds =
        widget.controller.workouts.map((workout) => workout.id).toSet();
    setState(() => _installingId = entry.id);
    try {
      final installed = await widget.controller
          .installBucketEntry(entry, resolution: resolution);
      if (mounted && installed) {
        String? workoutId;
        for (final workout in widget.controller.workouts) {
          if (!existingWorkoutIds.contains(workout.id)) {
            workoutId = workout.id;
            break;
          }
        }
        if (workoutId == null) {
          for (final item in widget.controller.installedBucketWorkouts) {
            if (item.sourceId == entry.sourceId && item.entryId == entry.id) {
              workoutId = item.workoutId;
              break;
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${entry.name} installed.'),
            action: workoutId == null
                ? null
                : SnackBarAction(
                    label: 'Open',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkoutDetailScreen(
                          controller: widget.controller,
                          workoutId: workoutId!,
                        ),
                      ),
                    ),
                  ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Install failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _installingId = null);
    }
  }

  Future<void> _showUpdateChoices(WorkoutBucketEntry entry) async {
    final choice = await showDialog<BucketInstallConflictResolution>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update installed workout'),
        content: const Text(
          'Choose how to handle the workout already on this device. Replacing it discards local edits.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              BucketInstallConflictResolution.keepLocal,
            ),
            child: const Text('Keep local'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              BucketInstallConflictResolution.installCopy,
            ),
            child: const Text('Install as copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              BucketInstallConflictResolution.replace,
            ),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (choice == null || choice == BucketInstallConflictResolution.keepLocal) {
      return;
    }
    await _install(entry, resolution: choice);
  }

  void _showDetails(WorkoutBucketEntry entry) {
    final state = widget.controller.bucketInstallState(entry);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(entry.name),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.description),
                const SizedBox(height: 16),
                Text('Version ${entry.version}'),
                if (entry.author != null) Text('By ${entry.author}'),
                if (entry.size != null) Text(_formatBytes(entry.size!)),
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in entry.tags) Chip(label: Text(tag)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (state != 'installed')
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                if (state == 'updateAvailable') {
                  _showUpdateChoices(entry);
                } else {
                  _install(entry);
                }
              },
              child: Text(state == 'updateAvailable' ? 'Update' : 'Install'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Workouts'),
        leading: BackButton(
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Manage workout sources',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    BucketSourcesScreen(controller: widget.controller),
              ),
            ),
            icon: const Icon(Icons.tune_outlined),
          ),
          IconButton(
            tooltip: 'Refresh catalog',
            onPressed: widget.controller.bucketCatalogLoading
                ? null
                : widget.controller.refreshAllBucketSources,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _searchChanged,
              decoration: InputDecoration(
                filled: true,
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search workouts, tags, or sources',
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchDebounce?.cancel();
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
            ),
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final entries = _filteredEntries();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<_CatalogStatus>(
                        value: _status,
                        underline: const SizedBox.shrink(),
                        onChanged: (value) => setState(() => _status = value!),
                        items: const [
                          DropdownMenuItem(
                              value: _CatalogStatus.all,
                              child: Text('All workouts')),
                          DropdownMenuItem(
                              value: _CatalogStatus.notInstalled,
                              child: Text('Not installed')),
                          DropdownMenuItem(
                              value: _CatalogStatus.installed,
                              child: Text('Installed')),
                          DropdownMenuItem(
                              value: _CatalogStatus.updates,
                              child: Text('Updates available')),
                        ],
                      ),
                      if (widget.controller.bucketSources.length > 1)
                        DropdownButton<String?>(
                          value: _sourceId,
                          underline: const SizedBox.shrink(),
                          onChanged: (value) =>
                              setState(() => _sourceId = value),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('All sources')),
                            for (final source
                                in widget.controller.bucketSources)
                              DropdownMenuItem(
                                  value: source.id, child: Text(source.name)),
                          ],
                        ),
                      DropdownButton<_CatalogSort>(
                        value: _sort,
                        underline: const SizedBox.shrink(),
                        onChanged: (value) => setState(() => _sort = value!),
                        items: const [
                          DropdownMenuItem(
                              value: _CatalogSort.recommended,
                              child: Text('Recommended')),
                          DropdownMenuItem(
                              value: _CatalogSort.nameAscending,
                              child: Text('Name A–Z')),
                          DropdownMenuItem(
                              value: _CatalogSort.nameDescending,
                              child: Text('Name Z–A')),
                        ],
                      ),
                      Text(
                        '${entries.length} workout${entries.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (widget.controller.bucketCatalogLoading)
                    const LinearProgressIndicator(),
                  if (widget.controller.bucketCatalogError != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Some sources could not be refreshed. Showing saved results.\n${widget.controller.bucketCatalogError}',
                        ),
                      ),
                    ),
                  if (!widget.controller.bucketCatalogLoading &&
                      entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text(
                            widget.controller.bucketSources.isEmpty
                                ? 'Add a workout source to start discovering workouts.'
                                : 'No workouts match your search and filters.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          if (widget.controller.bucketSources.isEmpty)
                            OutlinedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BucketSourcesScreen(
                                      controller: widget.controller),
                                ),
                              ),
                              child: const Text('Manage sources'),
                            )
                          else
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                  _sourceId = null;
                                  _status = _CatalogStatus.all;
                                });
                              },
                              child: const Text('Clear search and filters'),
                            ),
                        ],
                      ),
                    ),
                  for (final entry in entries) _entryCard(context, entry),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _entryCard(BuildContext context, WorkoutBucketEntry entry) {
    final state = widget.controller.bucketInstallState(entry);
    final installing = _installingId == entry.id;
    final label = switch (state) {
      'installed' => 'Installed',
      'updateAvailable' => 'Update',
      _ => 'Install',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(entry.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.description.isNotEmpty) Text(entry.description),
              const SizedBox(height: 6),
              Text('${_sourceName(entry.sourceId)} · Version ${entry.version}'),
              if (entry.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in entry.tags)
                      Chip(
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide.none,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        onTap: () => _showDetails(entry),
        trailing: installing
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FilledButton.tonal(
                onPressed: state == 'installed'
                    ? null
                    : () => state == 'updateAvailable'
                        ? _showUpdateChoices(entry)
                        : _install(entry),
                child: Text(label),
              ),
      ),
    );
  }

  List<WorkoutBucketEntry> _filteredEntries() {
    final needle = _normalize(_query.trim());
    final entries = widget.controller.bucketCatalogEntries.where((entry) {
      final state = widget.controller.bucketInstallState(entry);
      final matchesStatus = switch (_status) {
        _CatalogStatus.all => true,
        _CatalogStatus.notInstalled => state == 'notInstalled',
        _CatalogStatus.installed => state == 'installed',
        _CatalogStatus.updates => state == 'updateAvailable',
      };
      if (!matchesStatus ||
          (_sourceId != null && entry.sourceId != _sourceId)) {
        return false;
      }
      if (needle.isEmpty) return true;
      final searchable = [
        entry.name,
        entry.description,
        entry.author ?? '',
        _sourceName(entry.sourceId),
        ...entry.tags,
      ].map(_normalize).join(' ');
      return searchable.contains(needle);
    }).toList();
    if (_sort == _CatalogSort.nameAscending) {
      entries.sort((a, b) => _normalize(a.name).compareTo(_normalize(b.name)));
    } else if (_sort == _CatalogSort.nameDescending) {
      entries.sort((a, b) => _normalize(b.name).compareTo(_normalize(a.name)));
    }
    return entries;
  }

  String _sourceName(String? sourceId) {
    for (final source in widget.controller.bucketSources) {
      if (source.id == sourceId) return source.name;
    }
    return 'Unknown source';
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

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
