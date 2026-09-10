import 'package:anhpt/services/workout_insights_analytics.dart';
import 'package:anhpt/widgets/workout_insights_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('insights card renders up to three insights', (tester) async {
    const insights = [
      WorkoutInsight(
        type: WorkoutInsightType.recovery,
        title: 'Strong streak',
        message: 'Recovery message',
        priority: 100,
      ),
      WorkoutInsight(
        type: WorkoutInsightType.goal,
        title: 'One day to go',
        message: 'Goal message',
        priority: 95,
      ),
      WorkoutInsight(
        type: WorkoutInsightType.trend,
        title: 'Training time is up',
        message: 'Trend message',
        priority: 60,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WorkoutInsightsCard(insights: insights)),
      ),
    );

    expect(find.byKey(const Key('workout-insights-card')), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Strong streak'), findsOneWidget);
    expect(find.text('One day to go'), findsOneWidget);
    expect(find.text('Training time is up'), findsOneWidget);
  });

  testWidgets('empty insights render nothing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WorkoutInsightsCard(insights: [])),
      ),
    );

    expect(find.byKey(const Key('workout-insights-card')), findsNothing);
  });
}
