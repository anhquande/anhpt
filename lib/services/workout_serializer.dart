import '../models/workout_draft.dart';

class WorkoutSerializer {
  static String toYaml(WorkoutDraft draft) {
    final b = StringBuffer()
      ..writeln('version: 1')
      ..writeln()
      ..writeln('name: ${_quote(draft.name.trim())}');

    if (draft.description.trim().isNotEmpty) {
      b.writeln('description: ${_quote(draft.description.trim())}');
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
      ..writeln('  ducking: ${draft.ducking}')
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
      b
        ..writeln('$pad- name: ${_quote(node.name.trim())}')
        ..writeln('$pad  duration: ${node.duration.trim()}');
      if (node.guide.trim().isNotEmpty) {
        b.writeln('$pad  guide: >');
        for (final line in node.guide.trim().split('\n')) {
          b.writeln('$pad    ${line.trim()}');
        }
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
}
