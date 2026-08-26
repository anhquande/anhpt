import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../models/workout.dart';
import '../widgets/common.dart';
import '../widgets/workout_widgets.dart';
import 'settings_screen.dart';
import 'workout_builder_screen.dart';
import 'workout_detail_screen.dart';
import 'workout_editor_screen.dart';
import 'workout_player_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppController controller;
  const HomeScreen({super.key, required this.controller});

  void _openDetail(BuildContext context, Workout w) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutDetailScreen(controller: controller, workoutId: w.id)));
  }

  void _start(BuildContext context, Workout w) {
    controller.markUsed(w.id);
    Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutPlayerScreen(controller: controller, workoutId: w.id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AnhPT', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Import YAML',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutEditorScreen(controller: controller, importMode: true))),
            icon: const Icon(Icons.content_paste_go_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(controller: controller))),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutBuilderScreen(controller: controller))),
        icon: const Icon(Icons.add),
        label: const Text('New Workout'),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (_, __) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                Text('Ready to move?', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 28),
                if (controller.favorites.isNotEmpty) ...[
                  const SectionTitle('Favorites'), const SizedBox(height: 10),
                  for (final w in controller.favorites) ...[
                    WorkoutCard(workout: w, onOpen: () => _openDetail(context, w), onStart: () => _start(context, w), onFavorite: () => controller.toggleFavorite(w.id)),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 22),
                ],
                const SectionTitle('My Workouts'), const SizedBox(height: 10),
                for (final w in controller.others) ...[
                  WorkoutCard(workout: w, onOpen: () => _openDetail(context, w), onStart: () => _start(context, w), onFavorite: () => controller.toggleFavorite(w.id)),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
