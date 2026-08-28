import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/screens/workout_builder_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('workout builder uses overview tab structure', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(LocalStore());

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutBuilderScreen(controller: controller),
      ),
    );
    await tester.pump();

    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Structure'), findsOneWidget);

    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();
    expect(find.text('Background music'), findsOneWidget);

    await tester.tap(find.text('Structure'));
    await tester.pumpAndSettle();
    expect(find.text('Add Step'), findsOneWidget);
    expect(find.text('Add Repeat'), findsOneWidget);
  });
}
