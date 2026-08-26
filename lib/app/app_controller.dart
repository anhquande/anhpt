import 'package:flutter/foundation.dart';
import '../data/sample_data.dart';
import '../models/workout.dart';
import '../services/local_store.dart';
import '../services/workout_parser.dart';

class AppController extends ChangeNotifier {
  final LocalStore store;
  AppController(this.store);

  bool loading = true;
  bool onboarded = false;
  String defaultVoiceLanguage = 'vi';
  List<Workout> workouts = [];

  Future<void> initialize() async {
    onboarded = await store.isOnboarded();
    defaultVoiceLanguage = await store.defaultVoiceLanguage();
    workouts = await store.loadWorkouts();

    if (workouts.isEmpty) {
      final sample = WorkoutParser.parse(
        sampleYaml,
        id: WorkoutParser.generateId(),
        defaultVoiceLanguage: defaultVoiceLanguage,
        favorite: true,
      );
      workouts = [sample];
      await store.saveWorkouts(workouts);
    }

    loading = false;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    onboarded = true;
    await store.setOnboarded();
    notifyListeners();
  }

  Workout? byId(String id) {
    for (final w in workouts) {
      if (w.id == id) return w;
    }
    return null;
  }

  Future<void> saveWorkout(Workout workout) async {
    final i = workouts.indexWhere((w) => w.id == workout.id);
    if (i >= 0) {
      workouts[i] = workout;
    } else {
      workouts.add(workout);
    }
    await store.saveWorkouts(workouts);
    notifyListeners();
  }

  Future<void> deleteWorkout(String id) async {
    workouts.removeWhere((w) => w.id == id);
    await store.saveWorkouts(workouts);
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final i = workouts.indexWhere((w) => w.id == id);
    if (i < 0) return;
    workouts[i] = workouts[i].copyWith(
      favorite: !workouts[i].favorite,
      updatedAt: DateTime.now(),
    );
    await store.saveWorkouts(workouts);
    notifyListeners();
  }

  Future<void> markUsed(String id) async {
    final i = workouts.indexWhere((w) => w.id == id);
    if (i < 0) return;
    workouts[i] = workouts[i].copyWith(
      lastUsedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await store.saveWorkouts(workouts);
    notifyListeners();
  }

  Future<void> updateDefaultVoiceLanguage(String value) async {
    defaultVoiceLanguage = value;
    await store.setDefaultVoiceLanguage(value);
    notifyListeners();
  }

  List<Workout> get favorites {
    final list = workouts.where((w) => w.favorite).toList();
    list.sort(_recent);
    return list;
  }

  List<Workout> get others {
    final list = workouts.where((w) => !w.favorite).toList();
    list.sort(_recent);
    return list;
  }

  static int _recent(Workout a, Workout b) {
    final aa = a.lastUsedAt ?? a.updatedAt;
    final bb = b.lastUsedAt ?? b.updatedAt;
    return bb.compareTo(aa);
  }
}
