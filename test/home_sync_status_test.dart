import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/models/workout_bucket.dart';
import 'package:anhpt/screens/home_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const entry = WorkoutBucketEntry(
    sourceId: 'official',
    id: 'flow',
    name: 'Morning Flow',
    version: '1.0.0',
    workoutUrl: 'https://example.com/flow.yaml',
    workoutSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    workoutSize: 512,
  );

  testWidgets('Dashboard reports catalog listing count then hides it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = _SyncController(entry: entry);

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(controller: controller)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Loaded 1 workout listing.'), findsOneWidget);
    expect(find.text('Morning Flow'), findsOneWidget);
    expect(find.textContaining('Not downloaded'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Loaded 1 workout listing.'), findsNothing);
  });

  testWidgets('Dashboard reports catalog errors then hides them', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = _SyncController(
      entry: entry,
      error: 'network unavailable',
    );

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(controller: controller)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('network unavailable'), findsOneWidget);
    await tester.pump(const Duration(seconds: 13));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('network unavailable'), findsNothing);
  });

  testWidgets('catalog details do not download until Download is pressed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = _SyncController(entry: entry);

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(controller: controller)),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Morning Flow'));
    await tester.pumpAndSettle();

    expect(find.text('Workout details'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(controller.installCalls, 0);

    await tester.tap(find.text('Download'));
    await tester.pump();
    expect(controller.installCalls, 1);
  });
}

class _SyncController extends AppController {
  final WorkoutBucketEntry entry;
  final String? error;
  int installCalls = 0;

  _SyncController({required this.entry, this.error}) : super(LocalStore());

  @override
  Future<void> refreshAllBucketSources() async {
    if (error != null) throw StateError(error!);
    bucketCatalogEntries = [entry];
  }

  @override
  Future<bool> installBucketEntry(
    WorkoutBucketEntry entry, {
    BucketInstallConflictResolution? resolution,
  }) async {
    installCalls++;
    return true;
  }
}
