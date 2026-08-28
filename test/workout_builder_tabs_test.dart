import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/screens/workout_builder_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('workout builder uses overview tab structure', (tester) async {
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

    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Structure'), findsOneWidget);

    await tester.tap(find.text('Voice settings'));
    await tester.pumpAndSettle();
    expect(find.text('Announce every'), findsOneWidget);
    expect(find.text('Countdown from'), findsOneWidget);

    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();
    expect(find.text('Background music'), findsOneWidget);

    await tester.tap(find.text('Structure'));
    await tester.pumpAndSettle();

    // The default Step/Repeat editor is taller than the test viewport, so the
    // action buttons at the bottom are lazily built only after scrolling.
    final structureList = find.byType(ListView);
    expect(structureList, findsOneWidget);
    await tester.drag(structureList, const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('Add Step'), findsOneWidget);
    expect(find.text('Add Repeat'), findsOneWidget);
  });
}
