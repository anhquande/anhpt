import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class CoachRecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  /// On Windows the record plugin currently reports `true` and does not show
  /// a consent dialog. Capture can still fail when desktop microphone access
  /// is disabled in Windows Privacy settings.
  Future<bool> canAttemptRecording() => _recorder.hasPermission();

  Future<bool> isRecording() => _recorder.isRecording();

  Stream<Amplitude> amplitudeStream() =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 80));

  static Future<void> openSystemMicrophoneSettings() async {
    await Process.start(
      'explorer.exe',
      ['ms-settings:privacy-microphone'],
      mode: ProcessStartMode.detached,
    );
  }

  Future<String> start(String workoutId) async {
    final directory = await getApplicationDocumentsDirectory();
    final recordings =
        Directory('${directory.path}${Platform.pathSeparator}coach_recordings');
    await recordings.create(recursive: true);
    final safeId = workoutId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final path =
        '${recordings.path}${Platform.pathSeparator}${safeId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path);
    return path;
  }

  Future<String?> stop() => _recorder.stop();
  Future<bool> exists(String path) => File(path).exists();

  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<void> dispose() => _recorder.dispose();
}
