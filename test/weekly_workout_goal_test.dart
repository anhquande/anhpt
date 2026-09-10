import 'package:anhpt/services/weekly_workout_goal.dart';
import 'package:anhpt/widgets/weekly_workout_goal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('weekly goal defaults to three and stays profile scoped', () async {
    SharedPreferences.setMockInitialValues({});
    const store = WeeklyWorkoutGoalStore();

    expect(await store.load('me'), 3);
    expect(await store.load('other'), 3);

    await store.save('me', 5);
    expect(await store.load('me'), 5);
    expect(await store.load('other'), 3);
  });

  test('weekly goal rejects values outside one through seven', () async {
    SharedPreferences.setMockInitialValues({});
    const store = WeeklyWorkoutGoalStore();

    expect(() => store.save('me', 0), throwsArgumentError);
    expect(() => store.save('me', 8), throwsArgumentError);
  });

  testWidgets('weekly goal card shows progress and caps indicator at one',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyWorkoutGoalCard(
            completedDays: 5,
            goalDays: 3,
            onEdit: () {},
          ),
        ),
      ),
    );

    expect(find.text('5/3 workout days'), findsOneWidget);
    expect(find.text('Goal reached for this week.'), findsOneWidget);
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('weekly-workout-goal-progress')),
    );
    expect(indicator.value, 1);
  });
}
