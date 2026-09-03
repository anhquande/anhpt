import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../models/workout.dart';
import '../models/workout_bucket.dart';
import '../services/workout_update_service.dart';
import '../widgets/coach_recording_card.dart';
import '../widgets/common.dart';
import '../widgets/demo_media_source_sheet.dart';
import '../widgets/workout_music_card.dart';
import '../widgets/workout_artwork.dart';
import '../widgets/workout_widgets.dart';
import 'workout_builder_screen.dart';
import 'workout_download_screen.dart';
import 'workout_editor_screen.dart';
import 'workout_player_screen.dart';

enum _WorkoutAction {
  edit,
  duplicate,
  copyYaml,
  editYaml,
  exportPackage,
  viewSource,
  delete,
}

class WorkoutDetailScreen extends StatefulWidget {
  final AppController controller;
  final String workoutId;

  const WorkoutDetailScreen({
    super.key,
    required this.controller,
    required this.workoutId,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen>
    with SingleTickerProviderStateMixin {
  final _musicCardKey = GlobalKey<WorkoutMusicCardState>();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    widget.controller.refreshAllBucketSources();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startWorkout(Workout workout) async {
    await _musicCardKey.currentState?.stopPreview();
    if (!mounted) return;
    await widget.controller.markUsed(workout.id);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutPlayerScreen(
          controller: widget.controller,
          workoutId: workout.id,
        ),
      ),
    );
  }

  Future<void> _updateWorkout(WorkoutUpdateInfo update) async {
    final resolution =
        await showModalBottomSheet<BucketInstallConflictResolution>(
          context: context,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.system_update_alt),
                  title: const Text(
                    'Update workout',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'v${update.installedVersion} → v${update.availableVersion}',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Replace current workout'),
                  subtitle: const Text(
                    'Install the new bucket version in place of this workout.',
                  ),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    BucketInstallConflictResolution.replace,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.copy_outlined),
                  title: const Text('Install as copy'),
                  subtitle: const Text(
                    'Keep the current workout and install the update separately.',
                  ),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    BucketInstallConflictResolution.installCopy,
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
    if (resolution == null || !mounted) return;

    await _musicCardKey.currentState?.stopPreview();
    if (!mounted) return;

    final route = MaterialPageRoute(
      builder: (_) => WorkoutDownloadScreen(
        controller: widget.controller,
        entry: update.available,
        sourceName: widget.controller.bucketSourceName(update.installed),
        resolution: resolution,
      ),
    );

    if (resolution == BucketInstallConflictResolution.replace) {
      await Navigator.pushReplacement(context, route);
    } else {
      await Navigator.push(context, route);
    }
  }

  Future<void> _handleWorkoutAction(
    _WorkoutAction action,
    Workout workout,
  ) async {
    switch (action) {
      case _WorkoutAction.edit:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkoutBuilderScreen(
              controller: widget.controller,
              workoutId: workout.id,
            ),
          ),
        );
        return;
      case _WorkoutAction.duplicate:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkoutBuilderScreen(
              controller: widget.controller,
              duplicateFromId: workout.id,
            ),
          ),
        );
        return;
      case _WorkoutAction.copyYaml:
        await Clipboard.setData(ClipboardData(text: workout.rawYaml));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('YAML copied to clipboard')),
          );
        }
        return;
      case _WorkoutAction.editYaml:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkoutEditorScreen(
              controller: widget.controller,
              workoutId: workout.id,
            ),
          ),
        );
        return;
      case _WorkoutAction.exportPackage:
        try {
          final exported = await widget.controller.exportWorkoutPackage(
            workout.id,
          );
          if (mounted && exported) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Workout package exported.')),
            );
          }
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Export failed: $error')));
          }
        }
        return;
      case _WorkoutAction.viewSource:
        final provenance = widget.controller.bucketProvenanceFor(workout.id);
        if (provenance == null) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Workout source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Source: ${widget.controller.bucketSourceName(provenance)}',
                ),
                const SizedBox(height: 8),
                Text('Workout ID: ${provenance.entryId}'),
                Text('Installed version: ${provenance.version}'),
                if (widget.controller.bucketOriginalName(provenance)
                    case final originalName?) ...[
                  const SizedBox(height: 8),
                  Text('Original name: $originalName'),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      case _WorkoutAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Delete “${workout.name}”?'),
            content: const Text(
              'This workout will be removed from this device. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await widget.controller.deleteWorkout(workout.id);
        if (mounted) Navigator.pop(context);
        return;
    }
  }

  PopupMenuItem<_WorkoutAction> _menuItem(
    _WorkoutAction value,
    IconData icon,
    String label, {
    Color? color,
  }) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    ),
  );

  Future<void> _openStepRecording(
    BuildContext context,
    Workout workout,
    WorkoutStep step,
    String stepKey,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: CoachRecordingCard(
              controller: widget.controller,
              workout: workout,
              scope: 'step',
              stepKey: stepKey,
              title: 'Step recording: ${step.name}',
              cueDescription: 'Record the spoken cue for this step.',
              scriptText: step.guide,
              showCloseButton: true,
              closeAfterSave: true,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _browseStepMedia(String stepKey) async {
    try {
      final asset = await pickDemoMedia(context, widget.controller);
      if (asset == null) return;
      await widget.controller.assignStepDemoMedia(
        workoutId: widget.workoutId,
        stepKey: stepKey,
        asset: asset,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach demonstration: $error')),
        );
      }
    }
  }

  Future<void> _removeStepMedia(String stepKey) => widget.controller
      .removeStepDemoMedia(workoutId: widget.workoutId, stepKey: stepKey);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (_, __) {
        final controller = widget.controller;
        final workout = controller.byId(widget.workoutId);
        if (workout == null) {
          return const Scaffold(body: Center(child: Text('Workout not found')));
        }

        final recordedStepKeys = <String>{};
        void collectRecordings(List<WorkoutNode> nodes, [String prefix = '']) {
          for (var index = 0; index < nodes.length; index++) {
            final key = prefix.isEmpty ? '$index' : '$prefix.$index';
            final node = nodes[index];
            if (node is WorkoutStep && node.recording != null) {
              recordedStepKeys.add(key);
            } else if (node is RepeatGroup) {
              collectRecordings(node.steps, key);
            }
          }
        }

        collectRecordings(workout.steps);
        final provenance = controller.bucketProvenanceFor(workout.id);
        final update = controller.updateForWorkout(workout.id);
        final sourceName = provenance == null
            ? null
            : controller.bucketSourceName(provenance);
        final bucketEntry = controller.bucketEntryForWorkout(workout.id);
        final isWideLayout = MediaQuery.sizeOf(context).width >= 840;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              workout.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (isWideLayout)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: FilledButton.icon(
                    onPressed: () => _startWorkout(workout),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start'),
                  ),
                ),
              PopupMenuButton<_WorkoutAction>(
                tooltip: 'Workout actions',
                icon: const Icon(Icons.more_vert),
                onSelected: (action) async =>
                    _handleWorkoutAction(action, workout),
                itemBuilder: (_) => [
                  _menuItem(_WorkoutAction.edit, Icons.edit_outlined, 'Edit'),
                  _menuItem(
                    _WorkoutAction.duplicate,
                    Icons.copy_outlined,
                    'Duplicate',
                  ),
                  _menuItem(
                    _WorkoutAction.copyYaml,
                    Icons.copy_all_outlined,
                    'Copy YAML',
                  ),
                  _menuItem(_WorkoutAction.editYaml, Icons.code, 'Edit YAML'),
                  _menuItem(
                    _WorkoutAction.exportPackage,
                    Icons.archive_outlined,
                    'Export package',
                  ),
                  if (provenance != null)
                    _menuItem(
                      _WorkoutAction.viewSource,
                      Icons.cloud_outlined,
                      'View source',
                    ),
                  const PopupMenuDivider(),
                  _menuItem(
                    _WorkoutAction.delete,
                    Icons.delete_outline,
                    'Delete workout',
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                children: [
                  if (update != null)
                    _WorkoutUpdateBanner(
                      update: update,
                      onUpdate: () => _updateWorkout(update),
                    ),
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      const Tab(text: 'Overview'),
                      Tab(text: 'Exercises · ${workout.effectiveStepCount}'),
                      const Tab(text: 'Audio'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        ListView(
                          key: const PageStorageKey('overview-tab'),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                          children: [
                            _WorkoutHero(
                              workout: workout,
                              sourceName: sourceName,
                              bucketEntry: bucketEntry,
                              controller: controller,
                            ),
                            const SizedBox(height: 14),
                            _CompactWorkoutHeader(workout: workout),
                            if (workout.tags.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  for (final tag in workout.tags)
                                    Chip(
                                      label: Text(tag),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      side: BorderSide.none,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.secondaryContainer,
                                    ),
                                ],
                              ),
                            ],
                            if (workout.description.trim().isNotEmpty) ...[
                              const SizedBox(height: 18),
                              const _SectionTitle('About'),
                              const SizedBox(height: 8),
                              _WorkoutDescription(workout.description.trim()),
                            ],
                            const SizedBox(height: 20),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final preview = _WorkoutPreview(
                                  workout: workout,
                                  onViewAll: () => _tabController.animateTo(1),
                                );
                                final options = _WorkoutOptions(
                                  controller: controller,
                                  workout: workout,
                                );
                                if (constraints.maxWidth < 680) {
                                  return Column(
                                    children: [
                                      preview,
                                      const SizedBox(height: 12),
                                      options,
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 3, child: preview),
                                    const SizedBox(width: 12),
                                    Expanded(flex: 2, child: options),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                        ListView(
                          key: const PageStorageKey('exercises-tab'),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                          children: [
                            WorkoutStructure(
                              nodes: workout.steps,
                              recordedStepKeys: recordedStepKeys,
                              onRecordStep: (context, step, stepKey) =>
                                  _openStepRecording(
                                    context,
                                    workout,
                                    step,
                                    stepKey,
                                  ),
                              onBrowseStepMedia: (_, __, stepKey) =>
                                  _browseStepMedia(stepKey),
                              onRemoveStepMedia: (_, __, stepKey) =>
                                  _removeStepMedia(stepKey),
                              demoMediaIdForStep: (step) {
                                for (final exercise in workout.exercises) {
                                  if (exercise.id == step.exerciseId) {
                                    return exercise.demoMediaId;
                                  }
                                }
                                return null;
                              },
                              resolveMediaAsset: controller.mediaAsset,
                              resolveMediaUri: controller.resolveMediaUri,
                              resolveStepRecording: (step) =>
                                  step.recording == null
                                  ? null
                                  : controller.resolveAudioSource(
                                      step.recording!,
                                    ),
                            ),
                          ],
                        ),
                        ListView(
                          key: const PageStorageKey('audio-tab'),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                          children: [
                            const _SectionTitle('Background music'),
                            const SizedBox(height: 8),
                            WorkoutMusicCard(
                              key: _musicCardKey,
                              controller: controller,
                              workout: workout,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: isWideLayout
              ? null
              : SafeArea(
                  top: false,
                  child: Material(
                    elevation: 8,
                    child: Center(
                      heightFactor: 1,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: () => _startWorkout(workout),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Start workout'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _WorkoutHero extends StatelessWidget {
  final Workout workout;
  final String? sourceName;
  final WorkoutBucketEntry? bucketEntry;
  final AppController controller;

  const _WorkoutHero({
    required this.workout,
    required this.sourceName,
    required this.bucketEntry,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final description = workout.description.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 210,
        child: Stack(
          fit: StackFit.expand,
          children: [
            WorkoutArtwork(
              tags: workout.tags,
              kind: WorkoutArtworkKind.feature,
              bucketEntry: bucketEntry,
              bucketService: controller.workoutBuckets,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                  stops: [.35, 1],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sourceName != null) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.cloud_done_outlined,
                          size: 17,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            sourceName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    workout.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.surface, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutPreview extends StatelessWidget {
  final Workout workout;
  final VoidCallback onViewAll;

  const _WorkoutPreview({required this.workout, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final steps = workout.expand().take(3).toList();
    return _OverviewPanel(
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: _SectionTitle('Workout preview')),
              TextButton(
                onPressed: onViewAll,
                child: Text('View all ${workout.effectiveStepCount}'),
              ),
            ],
          ),
          for (var index = 0; index < steps.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            _PreviewStep(index: index + 1, executable: steps[index]),
          ],
          if (steps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No exercises yet',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewStep extends StatelessWidget {
  final int index;
  final ExecutableStep executable;

  const _PreviewStep({required this.index, required this.executable});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final step = executable.step;
    final guide = step.guide?.trim() ?? '';
    final repeat = executable.repeat;
    final detail = repeat != null && repeat.total > 1
        ? 'Repeat ${repeat.index} of ${repeat.total}'
        : guide;
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text('$index'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            step.duration == Duration.zero
                ? 'Instruction'
                : formatDuration(step.duration),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _WorkoutOptions extends StatelessWidget {
  final AppController controller;
  final Workout workout;

  const _WorkoutOptions({required this.controller, required this.workout});

  @override
  Widget build(BuildContext context) {
    return _OverviewPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('Workout options'),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.screen_lock_landscape_outlined),
            title: const Text('Screen during workout'),
            subtitle: Text(
              workout.screenOffAfterStart != null
                  ? 'Turn display off after Start'
                  : 'Keep current display behavior',
            ),
            value: workout.screenOffAfterStart != null,
            onChanged: (enabled) => controller.setWorkoutScreenOffAfterStart(
              workout.id,
              enabled: enabled,
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.power_settings_new),
            title: const Text('After workout'),
            subtitle: Text(
              workout.completionAction == 'shutdown_or_exit'
                  ? 'Shut down or exit when complete'
                  : 'Stay open after completion',
            ),
            value: workout.completionAction == 'shutdown_or_exit',
            onChanged: (enabled) => controller.setWorkoutCompletionAction(
              workout.id,
              enabled: enabled,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  final Widget child;

  const _OverviewPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _WorkoutUpdateBanner extends StatelessWidget {
  final WorkoutUpdateInfo update;
  final VoidCallback onUpdate;

  const _WorkoutUpdateBanner({required this.update, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.system_update_alt, color: colors.onPrimaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update available',
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'v${update.installedVersion} → v${update.availableVersion}',
                    style: TextStyle(color: colors.onPrimaryContainer),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onUpdate, child: const Text('Update')),
          ],
        ),
      ),
    );
  }
}

class _CompactWorkoutHeader extends StatelessWidget {
  final Workout workout;

  const _CompactWorkoutHeader({required this.workout});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          _MetadataItem(
            icon: Icons.schedule_outlined,
            label: formatDuration(workout.totalDuration),
          ),
          _MetadataItem(
            icon: Icons.format_list_numbered,
            label: '${workout.effectiveStepCount} steps',
          ),
          _MetadataItem(
            icon: Icons.language_outlined,
            label: workout.voice.language.toUpperCase(),
          ),
          if (workout.voice.announceElapsedTime ||
              workout.voice.announceInterval ||
              workout.voice.announceFinalCountdown)
            Text(
              [
                if (workout.voice.announceElapsedTime) 'Elapsed',
                if (workout.voice.announceInterval) 'Periodic',
                if (workout.voice.announceFinalCountdown) 'Countdown',
              ].join(' · '),
              style: TextStyle(color: color),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _WorkoutDescription extends StatefulWidget {
  final String text;

  const _WorkoutDescription(this.text);

  @override
  State<_WorkoutDescription> createState() => _WorkoutDescriptionState();
}

class _WorkoutDescriptionState extends State<_WorkoutDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.4,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: Directionality.of(context),
          maxLines: 3,
        )..layout(maxWidth: constraints.maxWidth);
        final canExpand = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: Text(
                widget.text,
                style: style,
                maxLines: _expanded ? null : 3,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
            ),
            if (canExpand)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(top: 2),
                  minimumSize: const Size(48, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(_expanded ? 'Less' : 'More'),
              ),
          ],
        );
      },
    );
  }
}

class _MetadataItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetadataItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
