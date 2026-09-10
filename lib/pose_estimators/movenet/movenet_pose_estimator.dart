import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/pose/pose.dart';
import 'movenet_pose_mapper.dart';

/// Test seam around MoveNet inference so preprocessing/mapping can be verified
/// without loading the native ONNX runtime in unit tests.
abstract interface class MoveNetInferenceBackend {
  bool get isInitialized;

  Future<void> initialize();

  Future<List<double>> run(Int32List rgbInput);

  Future<void> dispose();
}

abstract interface class MoveNetModelProvider {
  Future<String> getModelPath();
}

/// Downloads MoveNet SinglePose Lightning once and reuses the verified cache.
///
/// The model is kept out of Git to avoid growing every checkout/release source
/// archive by ~9 MB. First use on Windows therefore requires network access;
/// later sessions use the cached, SHA-256 verified model offline.
class CachedMoveNetModelProvider implements MoveNetModelProvider {
  CachedMoveNetModelProvider({http.Client? client}) : _client = client;

  static final Uri modelUri = Uri.parse(
    'https://huggingface.co/Xenova/movenet-singlepose-lightning/'
    'resolve/main/onnx/model.onnx?download=true',
  );
  static const String modelSha256 =
      '1ad4f8d6c2f776a9967db3993c9ca740bc350104f9d37c151dc183fc29a464ad';
  static const String _fileName = 'movenet_singlepose_lightning.onnx';

  final http.Client? _client;

  @override
  Future<String> getModelPath() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final modelDirectory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}models',
    );
    await modelDirectory.create(recursive: true);

    final target = File(
      '${modelDirectory.path}${Platform.pathSeparator}$_fileName',
    );
    if (await _isValid(target)) return target.path;
    if (await target.exists()) await target.delete();

    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final response = await client.get(modelUri);
      if (response.statusCode != HttpStatus.ok) {
        throw StateError(
          'MoveNet model download failed with HTTP ${response.statusCode}.',
        );
      }
      final digest = sha256.convert(response.bodyBytes).toString();
      if (digest != modelSha256) {
        throw StateError(
          'MoveNet model checksum mismatch. Expected $modelSha256, got $digest.',
        );
      }

      final temporary = File('${target.path}.download');
      if (await temporary.exists()) await temporary.delete();
      await temporary.writeAsBytes(response.bodyBytes, flush: true);
      await temporary.rename(target.path);
      return target.path;
    } finally {
      if (ownsClient) client.close();
    }
  }

  Future<bool> _isValid(File file) async {
    if (!await file.exists()) return false;
    final digest = sha256.convert(await file.readAsBytes()).toString();
    return digest == modelSha256;
  }
}

class OnnxMoveNetInferenceBackend implements MoveNetInferenceBackend {
  OnnxMoveNetInferenceBackend({MoveNetModelProvider? modelProvider})
      : _modelProvider = modelProvider ?? CachedMoveNetModelProvider();

  static const int inputSize = 192;

  final MoveNetModelProvider _modelProvider;
  final OnnxRuntime _runtime = OnnxRuntime();
  OrtSession? _session;

  @override
  bool get isInitialized => _session != null;

  @override
  Future<void> initialize() async {
    if (_session != null) return;
    final modelPath = await _modelProvider.getModelPath();
    final session = await _runtime.createSession(modelPath);
    if (session.inputNames.isEmpty || session.outputNames.isEmpty) {
      await session.close();
      throw StateError('MoveNet model does not expose an input/output tensor.');
    }
    _session = session;
  }

  @override
  Future<List<double>> run(Int32List rgbInput) async {
    final session = _session;
    if (session == null) {
      throw StateError('MoveNet backend must be initialized before inference.');
    }
    final expectedLength = inputSize * inputSize * 3;
    if (rgbInput.length != expectedLength) {
      throw ArgumentError.value(
        rgbInput.length,
        'rgbInput',
        'Expected $expectedLength RGB values.',
      );
    }

    final input = await OrtValue.fromList(
      rgbInput,
      const [1, inputSize, inputSize, 3],
    );
    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({session.inputNames.first: input});
      final output = outputs[session.outputNames.first];
      if (output == null) {
        throw StateError('MoveNet inference returned no output tensor.');
      }
      final raw = await output.asList();
      final flattened = <double>[];
      _flattenNumbers(raw, flattened);
      return flattened;
    } finally {
      input.dispose();
      if (outputs != null) {
        for (final value in outputs.values) {
          value.dispose();
        }
      }
    }
  }

  static void _flattenNumbers(Object? value, List<double> output) {
    if (value is num) {
      output.add(value.toDouble());
      return;
    }
    if (value is Iterable) {
      for (final item in value) {
        _flattenNumbers(item, output);
      }
      return;
    }
    throw StateError('MoveNet output contains unsupported value: $value');
  }

  @override
  Future<void> dispose() async {
    final session = _session;
    _session = null;
    if (session != null) await session.close();
  }
}

/// Windows-friendly MoveNet implementation of AnhPT's canonical estimator.
///
/// The estimator consumes only RGBA [PoseFrame] values. It letterboxes each
/// frame into MoveNet Lightning's 192x192 input while preserving aspect ratio,
/// then maps output coordinates back into the original normalized frame space.
class MoveNetPoseEstimator implements PoseEstimator {
  MoveNetPoseEstimator({MoveNetInferenceBackend? backend})
      : _backend = backend ?? OnnxMoveNetInferenceBackend();

  static const int inputSize = OnnxMoveNetInferenceBackend.inputSize;

  static final PoseEstimatorCapabilities _capabilities =
      PoseEstimatorCapabilities(
    supportedJoints: MoveNetPoseMapper.supportedJoints,
    supports3D: false,
    supportsSegmentation: false,
    maxPoseCount: 1,
  );

  final MoveNetInferenceBackend _backend;

  @override
  PoseEstimatorCapabilities get capabilities => _capabilities;

  @override
  bool get isInitialized => _backend.isInitialized;

  @override
  Future<void> initialize() => _backend.initialize();

  @override
  Future<List<BodyPose>> estimate(PoseFrame frame) async {
    if (!isInitialized) {
      throw StateError(
        'MoveNetPoseEstimator must be initialized before estimate.',
      );
    }
    final prepared = _preprocess(frame);
    final output = await _backend.run(prepared.rgbInput);
    return [
      MoveNetPoseMapper.fromFlatOutput(
        output,
        timestamp: frame.timestamp,
        mapX: prepared.mapX,
        mapY: prepared.mapY,
      ),
    ];
  }

  _MoveNetPreparedFrame _preprocess(PoseFrame frame) {
    if (frame.rotationDegrees != 0) {
      throw UnsupportedError(
        'Windows MoveNet input currently expects an upright RGBA frame.',
      );
    }
    if (frame.format != PoseFrameFormat.rgba8888 || frame.planes.length != 1) {
      throw UnsupportedError(
        'Windows MoveNet input requires one RGBA8888 image plane.',
      );
    }

    final plane = frame.planes.single;
    final bytesPerPixel = plane.bytesPerPixel ?? 4;
    final bytesPerRow = plane.bytesPerRow ?? frame.width * bytesPerPixel;
    if (bytesPerPixel < 4 || bytesPerRow < frame.width * bytesPerPixel) {
      throw ArgumentError('Invalid RGBA frame stride metadata.');
    }
    final requiredBytes = bytesPerRow * frame.height;
    if (plane.bytes.length < requiredBytes) {
      throw ArgumentError.value(
        plane.bytes.length,
        'frame.planes[0].bytes',
        'RGBA frame requires at least $requiredBytes bytes.',
      );
    }

    final scaleX = inputSize / frame.width;
    final scaleY = inputSize / frame.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final scaledWidth =
        (frame.width * scale).round().clamp(1, inputSize).toInt();
    final scaledHeight =
        (frame.height * scale).round().clamp(1, inputSize).toInt();
    final offsetX = (inputSize - scaledWidth) ~/ 2;
    final offsetY = (inputSize - scaledHeight) ~/ 2;

    final input = Int32List(inputSize * inputSize * 3);
    for (var y = 0; y < scaledHeight; y++) {
      final sourceY = ((y * frame.height) ~/ scaledHeight)
          .clamp(0, frame.height - 1)
          .toInt();
      for (var x = 0; x < scaledWidth; x++) {
        final sourceX = ((x * frame.width) ~/ scaledWidth)
            .clamp(0, frame.width - 1)
            .toInt();
        final sourceOffset =
            sourceY * bytesPerRow + sourceX * bytesPerPixel;
        final inputOffset =
            ((y + offsetY) * inputSize + x + offsetX) * 3;
        input[inputOffset] = plane.bytes[sourceOffset];
        input[inputOffset + 1] = plane.bytes[sourceOffset + 1];
        input[inputOffset + 2] = plane.bytes[sourceOffset + 2];
      }
    }

    return _MoveNetPreparedFrame(
      rgbInput: input,
      scaledWidth: scaledWidth,
      scaledHeight: scaledHeight,
      offsetX: offsetX,
      offsetY: offsetY,
    );
  }

  @override
  Future<void> dispose() => _backend.dispose();
}

class _MoveNetPreparedFrame {
  const _MoveNetPreparedFrame({
    required this.rgbInput,
    required this.scaledWidth,
    required this.scaledHeight,
    required this.offsetX,
    required this.offsetY,
  });

  final Int32List rgbInput;
  final int scaledWidth;
  final int scaledHeight;
  final int offsetX;
  final int offsetY;

  double mapX(double modelX) =>
      (modelX * MoveNetPoseEstimator.inputSize - offsetX) / scaledWidth;

  double mapY(double modelY) =>
      (modelY * MoveNetPoseEstimator.inputSize - offsetY) / scaledHeight;
}
