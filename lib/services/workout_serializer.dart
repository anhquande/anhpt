import '../models/workout_draft.dart';

class WorkoutSerializer {
  static String toYaml(WorkoutDraft draft) {
    final b = StringBuffer()
      ..writeln('version: 2')
      ..writeln()
      ..writeln('name: ${_quote(draft.name.trim())}');

    if (draft.description.trim().isNotEmpty) {
      b.writeln('description: ${_quote(draft.description.trim())}');
    }

    if (draft.tags.isNotEmpty) {
      b.writeln('tags:');
      for (final tag in draft.tags) {
        b.writeln('  - ${_quote(tag.trim())}');
      }
    }

    if (draft.recording.trim().isNotEmpty) {
      b.writeln('recording: ${_quote(draft.recording.trim())}');
    }

    if (draft.completionAction != 'none') {
      b.writeln('completion_action: ${draft.completionAction}');
    }

    b
      ..writeln()
      ..writeln('start_countdown: ${draft.startCountdown.trim()}')
      ..writeln()
      ..writeln('voice:')
      ..writeln('  language: ${draft.voiceLanguage}')
      ..writeln('  mode: ${draft.voiceMode}')
      ..writeln('  announce_every: ${draft.announceEvery.trim()}')
      ..writeln('  countdown_from: ${draft.countdownFrom.trim()}')
      ..writeln('  announce_step_name: ${draft.announceStepName}')
      ..writeln('  announce_start: ${draft.announceStart}')
      ..writeln('  announce_finish: ${draft.announceFinish}')
      ..writeln()
      ..writeln('feedback:')
      ..writeln('  sound: ${draft.sound}')
      ..writeln('  haptic: ${draft.haptic}')
      ..writeln()
      ..writeln('audio:')
      ..writeln('  ducking: ${draft.ducking}');

    if (draft.backgroundMusicSource.trim().isNotEmpty) {
      b
        ..writeln()
        ..writeln('background_music:')
        ..writeln('  source: ${_quote(draft.backgroundMusicSource.trim())}');
      if (draft.backgroundMusicName.trim().isNotEmpty) {
        b.writeln('  name: ${_quote(draft.backgroundMusicName.trim())}');
      }
      if (!draft.backgroundMusicEnabled) b.writeln('  enabled: false');
      b.writeln('  volume: ${_number(draft.backgroundMusicVolume)}');
      if (draft.backgroundMusicDucking != 'gentle') {
        b.writeln('  ducking: ${draft.backgroundMusicDucking}');
      }
    }

    if (draft.exercises.isNotEmpty) {
      b
        ..writeln()
        ..writeln('exercises:');
      for (final exercise in draft.exercises) {
        b
          ..writeln('  - id: ${_quote(exercise.id)}')
          ..writeln('    name: ${_quote(exercise.name)}');
        if (exercise.demoMediaId != null) {
          b.writeln('    demo_media: ${_quote(exercise.demoMediaId!)}');
        }
      }
    }

    b
      ..writeln()
      ..writeln('steps:');

    for (final node in draft.steps) {
      _writeNode(b, node, 2);
    }
    return b.toString();
  }

  static void _writeNode(StringBuffer b, WorkoutDraftNode node, int indent) {
    final pad = ' ' * indent;
    if (node is StepDraft) {
      b.writeln('$pad- name: ${_quote(node.name.trim())}');

      if (node.hasExplicitId || node.recording.trim().isNotEmpty) {
        b.writeln('$pad  id: ${_quote(node.id.trim())}');
      }

      final duration = node.duration.trim();
      if (duration.isNotEmpty && duration != '0s') {
        b.writeln('$pad  duration: $duration');
      }

      if (!node.countdown) {
        b.writeln('$pad  countdown: false');
      }

      if (node.guide.trim().isNotEmpty) {
        b.writeln('$pad  guide: >');
        for (final line in node.guide.trim().split('\n')) {
          b.writeln('$pad    ${line.trim()}');
        }
      }
      if (node.recording.trim().isNotEmpty) {
        b.writeln('$pad  recording: ${_quote(node.recording.trim())}');
      }
      if (node.exerciseId.trim().isNotEmpty) {
        b.writeln('$pad  exercise_id: ${_quote(node.exerciseId.trim())}');
      }
      return;
    }

    final repeat = node as RepeatDraft;
    b
      ..writeln('$pad- repeat: ${repeat.repeat}')
      ..writeln('$pad  steps:');
    for (final child in repeat.steps) {
      _writeNode(b, child, indent + 4);
    }
  }

  static String _quote(String value) {
    if (value.isEmpty) return '""';
    final mustQuote = value.contains(':') ||
        value.contains('#') ||
        value.startsWith('-') ||
        value.startsWith('[') ||
        value.startsWith('{');
    if (!mustQuote) return value;
    final escaped = value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    return '"$escaped"';
  }

  static String _number(double value) {
    final fixed = value.toStringAsFixed(3);
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
