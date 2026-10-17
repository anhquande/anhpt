import 'dart:async';

import 'package:anhpt/app/workout_camera_preference.dart';
import 'package:anhpt/core/pose/pose.dart';
import 'package:anhpt/widgets/windows_pose_camera_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ffi_uvc/flutter_ffi_uvc.dart';
import 'package:flutter_test/flutter_test.dart';

const _mode = UvcCameraMode(
  frameFormat: 0,
  formatName: 'RGBA',
  width: 640,
  height: 480,
  fps: 15,
);
const _device = UvcUsbDevice(
  deviceId: 1,
  deviceName: 'test',
  vendorId: 0,
  productId: 0,
  productName: 'test',
  manufacturerName: '',
  serialNumber: '',
  hasPermission: true,
);

class _Camera implements UvcCamera {
  final calls = <String>[];
  String? blocked;
  final gate = Completer<void>();
  bool failAttach = false;
  int copies = 0;
  Future<void> call(String name) async {
    calls.add(name);
    if (blocked == name) await gate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<UvcUsbDevice>> listUsbDevices() async {
    await call('list');
    return [_device];
  }

  @override
  Future<void> openUsbDevice(int deviceId) => call('open');
  @override
  Future<int> createPreviewTexture() async {
    await call('texture');
    return 42;
  }

  @override
  Future<UvcAutoPreviewResult> startPreviewAuto({
    List<UvcCameraMode>? candidates,
    UvcAutoPreviewPreference preference = UvcAutoPreviewPreference.reliability,
    Duration perModeTimeout = const Duration(seconds: 3),
    UvcPreviewPolicy policy = UvcPreviewPolicy.stableFrames,
    int consecutiveValidFrames = 3,
    int maxCandidates = 8,
  }) async {
    await call('start');
    return const UvcAutoPreviewResult(
      attempts: [
        UvcPreviewStartResult(
          mode: _mode,
          success: true,
          validFrameCount: 3,
          consecutiveValidFrames: 3,
          errorCount: 0,
          elapsed: Duration.zero,
        ),
      ],
    );
  }

  @override
  Future<void> attachPreviewTexture(
    int textureId, {
    int? width,
    int? height,
  }) async {
    await call('attach');
    if (failAttach) throw StateError('attach failed');
  }

  @override
  Future<void> disposePreviewTexture(int textureId) =>
      call('release:$textureId');
  @override
  Future<void> stopPreview() => call('stop');
  @override
  Future<void> closeUsbDevice() => call('close');
  @override
  Future<void> dispose() => call('dispose');
  @override
  UvcPreviewFrame? copyLatestFrame() {
    copies++;
    return null;
  }
}

class _Estimator implements PoseEstimator {
  final initialized = Completer<void>();
  @override
  bool isInitialized = false;
  @override
  PoseEstimatorCapabilities get capabilities =>
      PoseEstimatorCapabilities(supportedJoints: {});
  @override
  Future<void> initialize() async {
    await initialized.future;
    isInitialized = true;
  }

  @override
  Future<List<BodyPose>> estimate(PoseFrame frame) async => [];
  @override
  Future<void> dispose() async {
    isInitialized = false;
  }
}

Widget _preview(
  _Camera camera, {
  bool enabled = true,
  PosePipeline? pipeline,
}) => MaterialApp(
  home: SizedBox(
    width: 640,
    height: 480,
    child: WindowsPoseCameraPreview(
      camera: camera,
      enabled: enabled,
      facing: WorkoutCameraFacing.front,
      posePipeline: pipeline,
    ),
  ),
);

void main() {
  for (final stage in ['list', 'open', 'texture', 'start', 'attach']) {
    testWidgets(
      'dispose during $stage releases handles without restarting capture',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final camera = _Camera()..blocked = stage;
        await tester.pumpWidget(_preview(camera));
        await tester.pump();
        expect(camera.calls.last, stage);
        await tester.pumpWidget(const SizedBox.shrink());
        camera.gate.complete();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(camera.calls.last, 'dispose');
        expect(camera.calls.where((c) => c == 'dispose'), hasLength(1));
        if (['texture', 'start', 'attach'].contains(stage)) {
          expect(camera.calls.where((c) => c == 'release:42'), hasLength(1));
        }
        expect(camera.copies, 0);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'dispose while pose model initializes cannot resurrect frame timer',
    (tester) async {
      final camera = _Camera();
      final estimator = _Estimator();
      final pipeline = PosePipeline(estimator: estimator);
      await tester.pumpWidget(_preview(camera, pipeline: pipeline));
      await tester.pump();
      expect(camera.calls, contains('attach'));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(camera.calls, contains('release:42'));
      expect(camera.calls.last, 'close');
      estimator.initialized.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(camera.copies, 0);
      expect(pipeline.isRunning, isFalse);
      expect(camera.calls.last, 'dispose');
      expect(tester.takeException(), isNull);
      await pipeline.dispose();
    },
  );

  testWidgets(
    'failed attach releases texture retained during partial startup',
    (tester) async {
      final camera = _Camera()..failAttach = true;
      await tester.pumpWidget(_preview(camera));
      await tester.pump();
      expect(camera.calls.where((c) => c == 'release:42'), hasLength(1));
      expect(find.textContaining('attach failed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(camera.calls.last, 'dispose');
    },
  );

  testWidgets('rapid disable and enable waits for previous close', (
    tester,
  ) async {
    final camera = _Camera();
    await tester.pumpWidget(_preview(camera));
    await tester.pump();
    camera.calls.clear();
    camera.blocked = 'close';
    await tester.pumpWidget(_preview(camera, enabled: false));
    await tester.pump();
    await tester.pumpWidget(_preview(camera));
    await tester.pump();
    expect(camera.calls, isNot(contains('open')));
    camera.gate.complete();
    await tester.pump();
    expect(camera.calls, contains('open'));
    expect(
      camera.calls.indexOf('close'),
      lessThan(camera.calls.indexOf('open')),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(camera.calls.last, 'dispose');
  });
  testWidgets('pause and immediate resume serialize camera replacement', (tester) async {
    final camera = _Camera();
    await tester.pumpWidget(_preview(camera));
    await tester.pump();
    camera.calls.clear();
    camera.blocked = 'close';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(camera.calls, isNot(contains('open')));
    camera.gate.complete();
    await tester.pump();
    expect(camera.calls.where((c) => c == 'open'), hasLength(1));
    expect(find.byType(Texture), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(camera.calls.last, 'dispose');
    expect(tester.takeException(), isNull);
  });

}
