import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../models/workout.dart';
import '../widgets/coach_recording_card.dart';
import '../widgets/common.dart';
import '../widgets/workout_widgets.dart';
import '../widgets/workout_music_card.dart';
import '../widgets/step_recording_mini_player.dart';
import 'workout_builder_screen.dart';
import 'workout_editor_screen.dart';
import 'workout_player_screen.dart';

enum _WorkoutAction { edit, duplicate, copyYaml, editYaml, exportPackage }

class WorkoutDetailScreen extends StatefulWidget {
  final AppController controller;
  final String workoutId;

  const WorkoutDetailScreen(
      {super.key, required this.controller, required this.workoutId});

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
    _tabController = TabController(length: 3, initialIndex: 2, vsync: this);
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
          final exported =
              await widget.controller.exportWorkoutPackage(workout.id);
          if (mounted && exported) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Workout package exported.')),
            );
          }
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Export failed: $error')),
            );
          }
        }
        return;
    }
  }

  PopupMenuItem<_WorkoutAction> _menuItem(
    _WorkoutAction value,
    IconData icon,
    String label,
  ) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Text(label),
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

  Future<void> _openIntroductionRecording(
    BuildContext context,
    Workout workout,
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
              scope: 'description',
              title: 'Workout introduction recording',
              cueDescription:
                  'Record the spoken introduction for this workout.',
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
      final asset = await widget.controller.importDemoMedia();
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

  Future<void> _removeStepMedia(String stepKey) =>
      widget.controller.removeStepDemoMedia(
        workoutId: widget.workoutId,
        stepKey: stepKey,
      );

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
        return Scaffold(
          appBar: AppBar(
            title: Text(
              workout.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              FilledButton.icon(
                onPressed: () => _startWorkout(workout),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start'),
              ),
              PopupMenuButton<_WorkoutAction>(
                tooltip: 'Workout actions',
                icon: const Icon(Icons.more_vert),
                onSelected: (action) async =>
                    _handleWorkoutAction(action, workout),
                itemBuilder: (_) => [
                  _menuItem(_WorkoutAction.edit, Icons.edit_outlined, 'Edit'),
                  _menuItem(_WorkoutAction.duplicate, Icons.copy_outlined,
                      'Duplicate'),
                  _menuItem(_WorkoutAction.copyYaml, Icons.copy_all_outlined,
                      'Copy YAML'),
                  _menuItem(_WorkoutAction.editYaml, Icons.code, 'Edit YAML'),
                  _menuItem(_WorkoutAction.exportPackage,
                      Icons.archive_outlined, 'Export package'),
                ],
              )
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: _WorkoutSummary(workout: workout),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _PinnedTabBarDelegate(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      tabBar: TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'Introduction'),
                          Tab(text: 'Music'),
                          Tab(text: 'Structure'),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    ListView(
                      key: const PageStorageKey('introduction-tab'),
                      padding: const EdgeInsets.all(20),
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Workout introduction recording',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (workout.recording == null)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Record workout introduction',
                                  onPressed: () => _openIntroductionRecording(
                                      context, workout),
                                  icon: Icon(
                                    Icons.mic_none_outlined,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                )
                              else
                                StepRecordingMiniPlayer(
                                  audioPath: controller
                                      .resolveAudioSource(workout.recording!),
                                  onManage: () => _openIntroductionRecording(
                                      context, workout),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    ListView(
                      key: const PageStorageKey('music-tab'),
                      padding: const EdgeInsets.all(20),
                      children: [
                        WorkoutMusicCard(
                          key: _musicCardKey,
                          controller: controller,
                          workout: workout,
                        ),
                      ],
                    ),
                    ListView(
                      key: const PageStorageKey('structure-tab'),
                      padding: const EdgeInsets.all(20),
                      children: [
                        WorkoutStructure(
                          nodes: workout.steps,
                          recordedStepKeys: recordedStepKeys,
                          onRecordStep: (context, step, stepKey) =>
                              _openStepRecording(
                                  context, workout, step, stepKey),
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
                          resolveStepRecording: (step) => step.recording == null
                              ? null
                              : controller.resolveAudioSource(step.recording!),
                        ),
                        const SizedBox(height: 18),
                        TextButton.icon(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text('Delete "${workout.name}"?'),
                                content: const Text('This cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await controller.deleteWorkout(workout.id);
                              if (context.mounted) Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete Workout'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WorkoutSummary extends StatelessWidget {
  final Workout workout;

  const _WorkoutSummary({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (workout.description.trim().isNotEmpty) ...[
          _WorkoutDescription(workout.description.trim()),
          const SizedBox(height: 16),
        ],
        if (workout.tags.isNotEmpty) ...[
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final tag in workout.tags)
                Chip(
                  label: Text(tag),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide.none,
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 18,
          runSpacing: 10,
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
            _MetadataItem(
              icon: Icons.graphic_eq_outlined,
              label: workout.voice.mode,
            ),
          ],
        ),
      ],
    );
  }
}

class _PinnedTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color color;

  const _PinnedTabBarDelegate({required this.tabBar, required this.color});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: color,
      elevation: overlapsContent ? 1 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_PinnedTabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar || oldDelegate.color != color;
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
    final style = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.45,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.notes_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LayoutBuilder(
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
          ),
        ),
      ],
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
