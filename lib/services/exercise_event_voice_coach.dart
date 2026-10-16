import '../core/pose/exercise_analysis.dart';
import 'exercise_event_feedback.dart';

/// Best-effort bridge from pose events to the existing workout voice output.
///
/// It never queues camera-frame events: if the coach is already talking or a
/// prior event is in flight, the incoming event is dropped.
class ExerciseEventVoiceCoach {
  ExerciseEventVoiceCoach({
    required this.speak,
    required this.canSpeak,
    required this.isAudioBusy,
    required this.language,
    this.minSpacing = const Duration(milliseconds: 3500),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Future<void> Function(String) speak;
  final bool Function() canSpeak;
  final bool Function() isAudioBusy;
  final String Function() language;
  final Duration minSpacing;
  final DateTime Function() _clock;

  DateTime? _lastSpeechAt;
  bool _speaking = false;
  bool _disposed = false;

  void handle(ExerciseEvent event) {
    if (_disposed || _speaking || !canSpeak() || isAudioBusy()) return;
    final phrase = ExerciseEventFeedback.phrase(event, language: language());
    if (phrase == null) return;
    final now = _clock();
    if (_lastSpeechAt != null &&
        now.difference(_lastSpeechAt!) < minSpacing) {
      return;
    }
    _lastSpeechAt = now;
    _speaking = true;
    _deliver(phrase);
  }

  Future<void> _deliver(String phrase) async {
    try {
      if (!_disposed && canSpeak() && !isAudioBusy()) {
        await speak(phrase);
      }
    } catch (_) {
      // Camera analysis and workout progression must survive audio failures.
    } finally {
      _speaking = false;
    }
  }

  void dispose() {
    _disposed = true;
  }
}
