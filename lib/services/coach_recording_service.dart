import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class CoachRecordingService {
  AudioRecorder? _recorder;
  final Directory? documentsDirectory;

  CoachRecordingService({this.documentsDirectory});

  AudioRecorder get _audioRecorder => _recorder ??= AudioRecorder();

  Future<Directory> _recordingsDirectory() async {
    final directory =
        documentsDirectory ?? await getApplicationDocumentsDirectory();
    final recordings =
        Directory('${directory.path}${Platform.pathSeparator}coach_recordings');
    await recordings.create(recursive: true);
    return recordings;
  }

  /// On Windows the record plugin currently reports `true` and does not show
  /// a consent dialog. Capture can still fail when desktop microphone access
  /// is disabled in Windows Privacy settings.
  Future<bool> canAttemptRecording() => _audioRecorder.hasPermission();

  Future<bool> isRecording() => _audioRecorder.isRecording();

  Stream<Amplitude> amplitudeStream() =>
      _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 80));

  static Future<void> openSystemMicrophoneSettings() async {
    await Process.start(
      'explorer.exe',
      ['ms-settings:privacy-microphone'],
      mode: ProcessStartMode.detached,
    );
  }

  Future<String> start(String workoutId) async {
    final recordings = await _recordingsDirectory();
    final safeId = workoutId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final path =
        '${recordings.path}${Platform.pathSeparator}${safeId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path);
    return path;
  }

  Future<String> renameForCue(String sourcePath, String cueName) async {
    final source = File(sourcePath);
    if (!await source.exists()) return sourcePath;
    final recordings = await _recordingsDirectory();
    final extension = _extension(source.path);
    final stem = readableStem(cueName);
    var fileName = '$stem$extension';
    var suffix = 2;
    while (true) {
      final destination =
          File('${recordings.path}${Platform.pathSeparator}$fileName');
      if (destination.path.toLowerCase() == source.path.toLowerCase()) {
        return source.path;
      }
      if (!await destination.exists()) {
        return (await source.rename(destination.path)).path;
      }
      fileName = '$stem-${suffix++}$extension';
    }
  }

  static String readableStem(String value) {
    var normalized = value.toLowerCase();
    const source =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const target =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    for (var index = 0; index < source.length; index++) {
      normalized = normalized.replaceAll(source[index], target[index]);
    }
    final safe = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return safe.isEmpty ? 'recording' : safe;
  }

  static String _extension(String path) {
    final leaf = path.replaceAll('\\', '/').split('/').last;
    final dot = leaf.lastIndexOf('.');
    return dot > 0 ? leaf.substring(dot).toLowerCase() : '.m4a';
  }

  Future<String?> stop() => _audioRecorder.stop();
  Future<bool> exists(String path) => File(path).exists();

  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<void> dispose() async {
    final recorder = _recorder;
    if (recorder != null) await recorder.dispose();
  }
}
