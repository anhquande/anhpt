import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anhpt/models/workout_draft.dart';
import 'package:anhpt/widgets/step_voice_cues_editor.dart';

void main() {
  testWidgets('step Voice Coach editor updates cue flags and remaining time', (
    tester,
  ) async {
    final step = StepDraft(name: 'Plank', duration: '30s');
    var changes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StepVoiceCuesEditor(
              step: step,
              changed: () => changes++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Voice Coach cues'), findsOneWidget);
    await tester.tap(find.text('Voice Coach cues'));
    await tester.pumpAndSettle();

    expect(find.text('Announce next step'), findsOneWidget);
    expect(find.text('Get ready'), findsOneWidget);
    expect(find.text('Start countdown'), findsOneWidget);
    expect(find.text('Halfway'), findsOneWidget);
    expect(find.text('Completion cue'), findsOneWidget);

    await tester.tap(find.text('Get ready'));
    await tester.pump();
    expect(step.getReady, isTrue);

    final remaining = find.widgetWithText(
      TextFormField,
      'Remaining-time cue (seconds)',
    );
    await tester.enterText(remaining, '15');
    await tester.pump();
    expect(step.remainingTimeSeconds, 15);
    expect(changes, greaterThanOrEqualTo(2));
  });
}
