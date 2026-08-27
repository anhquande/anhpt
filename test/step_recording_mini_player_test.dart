import 'dart:ui' show PointerDeviceKind;

import 'package:anhpt/widgets/step_recording_mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('secondary recording actions appear only while hovering',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: StepRecordingMiniPlayer(
            audioPath: 'unused.m4a',
            onManage: () {},
          ),
        ),
      ),
    ));

    expect(find.byTooltip('Play recording'), findsOneWidget);
    expect(find.byTooltip('Manage recording'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byTooltip('Play recording')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Manage recording'), findsOneWidget);

    await mouse.moveTo(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Manage recording'), findsNothing);
    await mouse.removePointer();
  });
}
