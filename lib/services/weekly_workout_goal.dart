import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeeklyWorkoutGoalStore {
  static const int defaultGoalDays = 3;
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  const WeeklyWorkoutGoalStore();

  String _key(String profileId) => 'anhpt.weeklyWorkoutGoal.$profileId';

  Future<int> load(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_key(profileId));
    if (value == null || value < 1 || value > 7) return defaultGoalDays;
    return value;
  }

  Future<void> save(String profileId, int days) async {
    if (days < 1 || days > 7) {
      throw ArgumentError.value(days, 'days', 'must be between 1 and 7');
    }
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key(profileId));
    if (current == days) return;
    await prefs.setInt(_key(profileId), days);
    revision.value++;
  }
}
