import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../models/workout_bucket.dart';

class BucketCatalogScreen extends StatefulWidget {
  final AppController controller;

  const BucketCatalogScreen({super.key, required this.controller});

  @override
  State<BucketCatalogScreen> createState() => _BucketCatalogScreenState();
}

class _BucketCatalogScreenState extends State<BucketCatalogScreen> {
  String _query = '';
  String? _installingId;

  Future<void> _install(
    WorkoutBucketEntry entry, {
    BucketInstallConflictResolution? resolution,
  }) async {
    setState(() => _installingId = entry.id);
    try {
      await widget.controller.installBucketEntry(entry, resolution: resolution);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${entry.name} installed.')),
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
        title: const Text('Workout Catalog'),
        leading: BackButton(
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Return to Home',
            onPressed: () => Navigator.of(context).popUntil(
              (route) => route.isFirst,
            ),
            icon: const Icon(Icons.home_outlined),
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
          final entries = widget.controller.bucketCatalogEntries.where((entry) {
            final needle = _query.trim().toLowerCase();
            if (needle.isEmpty) return true;
            return entry.name.toLowerCase().contains(needle) ||
                entry.description.toLowerCase().contains(needle) ||
                entry.tags.any((tag) => tag.toLowerCase().contains(needle));
          }).toList();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search workouts or tags',
                    ),
                    onChanged: (value) => setState(() => _query = value),
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
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No workouts found in enabled bucket sources.',
                        textAlign: TextAlign.center,
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
        title: Text(entry.name),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${entry.description}\nVersion ${entry.version}'),
        ),
        isThreeLine: true,
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

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
