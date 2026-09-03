import 'dart:convert';
import 'dart:typed_data';

import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/models/workout_bucket.dart';
import 'package:anhpt/screens/home_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/workout_bucket_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final previewYaml = Uint8List.fromList(
    utf8.encode('''
version: 2
name: Morning Flow
steps:
  - name: Warm up
    duration: 1m
  - repeat: 2
    steps:
      - name: Flow
        duration: 4m
        guide: Move smoothly.
'''),
  );
  final previewService = _PreviewBucketService(previewYaml);
  final entry = WorkoutBucketEntry(
    sourceId: 'official',
    id: 'flow',
    name: 'Morning Flow',
    version: '1.0.0',
    workoutUrl: 'https://example.com/flow.yaml',
    workoutSha256: sha256.convert(previewYaml).toString(),
    workoutSize: previewYaml.length,
    author: 'Trusted Coach',
    authorVerified: true,
    durationSeconds: 600,
    stepCount: 3,
    difficulty: 'Beginner',
    intensity: 'Gentle',
    benefits: ['Move with confidence'],
    stepPreview: [
      WorkoutBucketStepPreview(name: 'Warm up', durationSeconds: 60),
      WorkoutBucketStepPreview(
        name: 'Flow',
        durationSeconds: 480,
        hasGuide: true,
      ),
      WorkoutBucketStepPreview(name: 'Cool down', durationSeconds: 60),
    ],
  );

  testWidgets('Dashboard reports catalog listing count then hides it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = _SyncController(entry: entry, service: previewService);

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(controller: controller)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Loaded 1 workout listing.'), findsOneWidget);
    expect(find.text('Morning Flow'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
    expect(find.textContaining('Not downloaded'), findsNothing);
    expect(find.textContaining('v1.0.0'), findsNothing);
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
      service: previewService,
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

  testWidgets('catalog details preview YAML but install only on Download', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = _SyncController(entry: entry, service: previewService);

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(controller: controller)),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Morning Flow'));
    await tester.pumpAndSettle();

    expect(find.text('Workout details'), findsOneWidget);
    expect(find.text('Trusted Coach'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bucket-steps-tab')));
    await tester.pump();
    for (var attempt = 0; attempt < 20; attempt++) {
      if (find.text('Warm up').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Warm up'), findsOneWidget);
    expect(find.text('Repeat ×2'), findsOneWidget);
    expect(find.text('Flow'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_outlined), findsNothing);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);

    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -280));
    await tester.pumpAndSettle();
    expect(find.text('Move with confidence'), findsOneWidget);
    expect(find.textContaining('Download workout'), findsOneWidget);
    expect(controller.installCalls, 0);

    await tester.tap(find.textContaining('Download workout'));
    await tester.pump();
    expect(controller.installCalls, 1);
  });
}

class _PreviewBucketService extends WorkoutBucketService {
  final Uint8List bytes;

  _PreviewBucketService(this.bytes);

  @override
  Future<Uint8List> downloadWorkout(
    WorkoutBucketEntry entry, {
    BucketDownloadProgress? onProgress,
  }) async => bytes;
}

class _SyncController extends AppController {
  final WorkoutBucketEntry entry;
  final String? error;
  int installCalls = 0;

  _SyncController({
    required this.entry,
    required WorkoutBucketService service,
    this.error,
  }) : super(LocalStore(), workoutBuckets: service);

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
