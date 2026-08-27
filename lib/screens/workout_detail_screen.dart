import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../models/workout.dart';
import '../widgets/coach_recording_card.dart';
import '../widgets/common.dart';
import '../widgets/workout_widgets.dart';
import '../widgets/workout_music_card.dart';
import 'workout_builder_screen.dart';
import 'workout_editor_screen.dart';
import 'workout_player_screen.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final AppController controller;
  final String workoutId;

  const WorkoutDetailScreen(
      {super.key, required this.controller, required this.workoutId});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final _musicCardKey = GlobalKey<WorkoutMusicCardState>();

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
            title: Text(workout.name),
            actions: [
              IconButton(
                onPressed: () => controller.toggleFavorite(workout.id),
                icon: Icon(workout.favorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded),
              )
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(workout.name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(workout.description),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    Chip(label: Text(formatDuration(workout.totalDuration))),
                    Chip(label: Text('${workout.effectiveStepCount} steps')),
                    Chip(label: Text(workout.voice.language.toUpperCase())),
                    Chip(label: Text(workout.voice.mode)),
                  ]),
                  const SizedBox(height: 22),
                  SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await _musicCardKey.currentState?.stopPreview();
                          if (!context.mounted) return;
                          await controller.markUsed(workout.id);
                          if (!context.mounted) return;
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => WorkoutPlayerScreen(
                                      controller: controller,
                                      workoutId: workout.id)));
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('START WORKOUT'),
                      )),
                  const SizedBox(height: 18),
                  CoachRecordingCard(
                    controller: controller,
                    workout: workout,
                    scope: 'description',
                    title: 'Workout introduction recording',
                    cueDescription:
                        'Record the spoken description for this workout.',
                  ),
                  const SizedBox(height: 18),
                  WorkoutMusicCard(
                    key: _musicCardKey,
                    controller: controller,
                    workout: workout,
                  ),
                  const SizedBox(height: 28),
                  const SectionTitle('Structure'),
                  const SizedBox(height: 10),
                  WorkoutStructure(
                    nodes: workout.steps,
                    recordedStepKeys: recordedStepKeys,
                    onRecordStep: (context, step, stepKey) =>
                        _openStepRecording(context, workout, step, stepKey),
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
                  const SizedBox(height: 22),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.tonalIcon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => WorkoutBuilderScreen(
                                  controller: controller,
                                  workoutId: workout.id))),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => WorkoutBuilderScreen(
                                  controller: controller,
                                  duplicateFromId: workout.id))),
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Duplicate'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => WorkoutEditorScreen(
                                  controller: controller,
                                  workoutId: workout.id))),
                      icon: const Icon(Icons.code),
                      label: const Text('Edit YAML'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: workout.rawYaml));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('YAML copied to clipboard')));
                        }
                      },
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('Copy YAML'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final exported =
                              await controller.exportWorkoutPackage(workout.id);
                          if (context.mounted && exported) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Workout package exported.')));
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Export failed: $error')));
                          }
                        }
                      },
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Export package'),
                    ),
                  ]),
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
                                      child: const Text('Cancel')),
                                  FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete')),
                                ],
                              ));
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
            ),
          ),
        );
      },
    );
  }
}
