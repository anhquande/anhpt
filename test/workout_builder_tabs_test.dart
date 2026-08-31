import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/screens/workout_builder_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('workout builder uses overview and steps tabs', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final controller = AppController(LocalStore());

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutBuilderScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Introduction'), findsNothing);
    expect(find.text('Music'), findsNothing);
    expect(find.text('Structure'), findsNothing);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Workout options'), findsOneWidget);

    final overviewList =
        find.byKey(const PageStorageKey('builder-overview-tab'));
    expect(overviewList, findsOneWidget);
    await tester.drag(overviewList, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Voice settings'), findsOneWidget);
    await tester.tap(find.text('Voice settings'));
    await tester.pumpAndSettle();
    expect(find.text('Announce every'), findsOneWidget);
    expect(find.text('Countdown from'), findsOneWidget);

    await tester.tap(find.text('Steps'));
    await tester.pumpAndSettle();

    final stepsList = find.byKey(const PageStorageKey('builder-steps-tab'));
    expect(stepsList, findsOneWidget);
    await tester.drag(stepsList, const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('Add Step'), findsOneWidget);
    expect(find.text('Add Repeat'), findsOneWidget);
  });
}
