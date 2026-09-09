import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/services/workout_history_csv_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _session({
  required String id,
  required DateTime endedAt,
  String workoutName = 'High Plank',
  String? note,
  int? calories,
  WorkoutSessionEffort? effort,
  WorkoutSessionStatus status = WorkoutSessionStatus.completed,
}) {
  return WorkoutSession(
    id: id,
    workoutId: 'plank',
    workoutName: workoutName,
    profileId: 'me',
    profileName: 'Me',
    startedAt: endedAt.subtract(const Duration(minutes: 12)),
    endedAt: endedAt,
    activeDuration: const Duration(minutes: 12),
    completedSteps: status == WorkoutSessionStatus.completed ? 4 : 2,
    totalSteps: 4,
    status: status,
    estimatedCalories: calories,
    effort: effort,
    note: note,
  );
}

void main() {
  const exporter = WorkoutHistoryCsvExporter();

  test('exports stable header optional metrics and row order', () {
    final newer = _session(
      id: 'newer',
      endedAt: DateTime(2026, 9, 10, 10),
      calories: 120,
      effort: WorkoutSessionEffort.hard,
    );
    final older = _session(
      id: 'older',
      endedAt: DateTime(2026, 9, 9, 10),
      status: WorkoutSessionStatus.incomplete,
    );

    final csv = exporter.encode([newer, older]);
    final lines = csv.trimRight().split('\r\n');

    expect(
      lines.first,
      WorkoutHistoryCsvExporter.headers.join(','),
    );
    expect(lines[1].startsWith('newer,'), isTrue);
    expect(lines[1], contains(',120,hard,'));
    expect(lines[2].startsWith('older,'), isTrue);
    expect(lines[2], contains(',incomplete,720,2,4,,,'));
  });

  test('quotes commas quotes and line breaks safely', () {
    final csv = exporter.encode([
      _session(
        id: 'escaped',
        endedAt: DateTime(2026, 9, 10, 10),
        workoutName: 'Core, Balance',
        note: 'Felt "strong"\nSecond line',
      ),
    ]);

    expect(csv, contains('"Core, Balance"'));
    expect(csv, contains('"Felt ""strong""\nSecond line"'));
  });

  test('builds a stable safe filename', () {
    expect(
      exporter.fileName(
        profileName: 'Anh Quan / Me',
        now: DateTime(2026, 9, 10, 12),
      ),
      'anhpt-workout-history-anh-quan-me-2026-09-10.csv',
    );
  });
}
