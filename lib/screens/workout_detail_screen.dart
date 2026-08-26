import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../widgets/common.dart';
import '../widgets/workout_widgets.dart';
import 'workout_builder_screen.dart';
import 'workout_editor_screen.dart';
import 'workout_player_screen.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final AppController controller;
  final String workoutId;

  const WorkoutDetailScreen({super.key, required this.controller, required this.workoutId});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final workout = controller.byId(workoutId);
        if (workout == null) return const Scaffold(body: Center(child: Text('Workout not found')));
        return Scaffold(
          appBar: AppBar(
            title: Text(workout.name),
            actions: [IconButton(
              onPressed: () => controller.toggleFavorite(workout.id),
              icon: Icon(workout.favorite ? Icons.star_rounded : Icons.star_border_rounded),
            )],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(workout.name, style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8), Text(workout.description), const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    Chip(label: Text(formatDuration(workout.totalDuration))),
                    Chip(label: Text('${workout.effectiveStepCount} steps')),
                    Chip(label: Text(workout.voice.language.toUpperCase())),
                    Chip(label: Text(workout.voice.mode)),
                  ]),
                  const SizedBox(height: 22),
                  SizedBox(height: 54, child: FilledButton.icon(
                    onPressed: () {
                      controller.markUsed(workout.id);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutPlayerScreen(controller: controller, workoutId: workout.id)));
                    },
                    icon: const Icon(Icons.play_arrow_rounded), label: const Text('START WORKOUT'),
                  )),
                  const SizedBox(height: 28), const SectionTitle('Structure'), const SizedBox(height: 10),
                  WorkoutStructure(nodes: workout.steps), const SizedBox(height: 22),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.tonalIcon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutBuilderScreen(controller: controller, workoutId: workout.id))),
                      icon: const Icon(Icons.edit_outlined), label: const Text('Edit'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutBuilderScreen(controller: controller, duplicateFromId: workout.id))),
                      icon: const Icon(Icons.copy_outlined), label: const Text('Duplicate'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutEditorScreen(controller: controller, workoutId: workout.id))),
                      icon: const Icon(Icons.code), label: const Text('Edit YAML'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: workout.rawYaml));
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('YAML copied to clipboard')));
                      },
                      icon: const Icon(Icons.copy_all_outlined), label: const Text('Copy YAML'),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  TextButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                        title: Text('Delete "${workout.name}"?'), content: const Text('This cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ));
                      if (ok == true) {
                        await controller.deleteWorkout(workout.id);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.delete_outline), label: const Text('Delete Workout'),
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
