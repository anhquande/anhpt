import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../models/workout_bucket.dart';
import 'bucket_sources_screen.dart';
import 'workout_download_screen.dart';

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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutDownloadScreen(
          controller: widget.controller,
          entry: entry,
          sourceName: _sourceName(entry.sourceId),
          resolution: resolution,
        ),
      ),
    );
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
                Text(
                  '${_formatBytes(entry.workoutSize)} YAML + '
                  '${_formatBytes(entry.assetsSize)} assets',
                ),
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
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (state == 'updateAvailable') {
                _showUpdateChoices(entry);
              } else if (state == 'installed') {
                _install(
                  entry,
                  resolution: BucketInstallConflictResolution.installCopy,
                );
              } else {
                _install(entry);
              }
            },
            child: Text(switch (state) {
              'updateAvailable' => 'Update',
              'installed' => 'Add another',
              _ => 'Install',
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Browse Workouts',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: BackButton(onPressed: () => Navigator.maybePop(context)),
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
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final entries = _filteredEntries();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  TextField(
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
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${entries.length} workout${entries.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      PopupMenuButton<_CatalogStatus>(
                        tooltip: 'Filter workouts',
                        initialValue: _status,
                        onSelected: (value) => setState(() => _status = value),
                        icon: Icon(
                          _status == _CatalogStatus.all
                              ? Icons.filter_list_outlined
                              : Icons.filter_list,
                        ),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: _CatalogStatus.all,
                            child: Text('All workouts'),
                          ),
                          PopupMenuItem(
                            value: _CatalogStatus.notInstalled,
                            child: Text('Not installed'),
                          ),
                          PopupMenuItem(
                            value: _CatalogStatus.installed,
                            child: Text('Installed'),
                          ),
                          PopupMenuItem(
                            value: _CatalogStatus.updates,
                            child: Text('Updates available'),
                          ),
                        ],
                      ),
                      if (widget.controller.bucketSources.length > 1)
                        PopupMenuButton<String?>(
                          tooltip: 'Filter by source',
                          initialValue: _sourceId,
                          onSelected: (value) =>
                              setState(() => _sourceId = value),
                          icon: Icon(
                            _sourceId == null
                                ? Icons.cloud_outlined
                                : Icons.cloud,
                          ),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: null,
                              child: Text('All sources'),
                            ),
                            for (final source
                                in widget.controller.bucketSources)
                              PopupMenuItem(
                                value: source.id,
                                child: Text(source.name),
                              ),
                          ],
                        ),
                      PopupMenuButton<_CatalogSort>(
                        tooltip: 'Sort workouts',
                        initialValue: _sort,
                        onSelected: (value) => setState(() => _sort = value),
                        icon: const Icon(Icons.sort),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: _CatalogSort.recommended,
                            child: Text('Recommended'),
                          ),
                          PopupMenuItem(
                            value: _CatalogSort.nameAscending,
                            child: Text('Name A–Z'),
                          ),
                          PopupMenuItem(
                            value: _CatalogSort.nameDescending,
                            child: Text('Name Z–A'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                                    controller: widget.controller,
                                  ),
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
    final label = switch (state) {
      'installed' => 'Add another',
      'updateAvailable' => 'Update',
      _ => 'Install',
    };
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showDetails(entry),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (entry.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        entry.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${_sourceName(entry.sourceId)}  ·  Version ${entry.version}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (entry.tags.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        entry.tags.join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: () {
                  if (state == 'installed') {
                    _install(
                      entry,
                      resolution: BucketInstallConflictResolution.installCopy,
                    );
                  } else if (state == 'updateAvailable') {
                    _showUpdateChoices(entry);
                  } else {
                    _install(entry);
                  }
                },
                child: Text(label),
              ),
            ],
          ),
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
