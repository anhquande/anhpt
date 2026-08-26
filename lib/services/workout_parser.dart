import 'dart:math';
import 'package:yaml/yaml.dart';

import '../core/duration_parser.dart';
import '../models/workout.dart';

class WorkoutValidationException implements Exception {
  final String message;
  const WorkoutValidationException(this.message);
  @override
  String toString() => message;
}

class WorkoutParser {
  static const _rootFields = {'version','name','description','tags','start_countdown','voice','feedback','audio','steps'};
  static const _voiceFields = {'language','mode','announce_every','countdown_from','announce_step_name','announce_start','announce_finish'};
  static const _feedbackFields = {'sound','haptic'};
  static const _audioFields = {'ducking'};
  static const _stepFields = {'name','duration','guide','countdown'};
  static const _repeatFields = {'repeat','steps'};

  static Workout parse(String yamlText,{required String id,required String defaultVoiceLanguage,bool favorite=false,DateTime? createdAt}) {
    dynamic loaded;
    try { loaded = loadYaml(yamlText); }
    on YamlException catch (e) { throw WorkoutValidationException('YAML syntax error: ${e.message}'); }
    if (loaded is! YamlMap) throw const WorkoutValidationException('YAML root must be an object.');
    final root = _map(loaded);
    _unknown(root,_rootFields,'root');
    if (root['version'] != 1) throw const WorkoutValidationException('version is required and must be 1.');

    final name = _string(root['name'],'name',100);
    final description = root['description'] == null ? '' : _string(root['description'],'description',500,allowEmpty:true);
    final tags = _tags(root['tags']);
    final startCountdown = root['start_countdown'] == null ? const Duration(seconds:3) : DurationParser.parseAllowZero(root['start_countdown'],field:'start_countdown');
    final voice = _voice(root['voice'],defaultVoiceLanguage);
    final (sound,haptic) = _feedback(root['feedback']);
    final ducking = _audio(root['audio']);

    final rawSteps = root['steps'];
    if (rawSteps is! YamlList || rawSteps.isEmpty) throw const WorkoutValidationException('Workout must contain at least one step.');
    final steps = _nodes(rawSteps,0);
    final now = DateTime.now();
    final workout = Workout(id:id,version:1,name:name,description:description,tags:tags,startCountdown:startCountdown,voice:voice,sound:sound,haptic:haptic,ducking:ducking,steps:steps,rawYaml:yamlText,favorite:favorite,createdAt:createdAt ?? now,updatedAt:now);
    if (workout.totalDuration > const Duration(hours:24)) throw const WorkoutValidationException('Total workout duration must not exceed 24 hours.');
    if (workout.effectiveStepCount > 100000) throw const WorkoutValidationException('Workout must not exceed 100,000 effective steps.');
    return workout;
  }

  static VoiceConfig _voice(Object? value,String defaultLanguage) {
    final map = value == null ? <String,dynamic>{} : _map(value);
    _unknown(map,_voiceFields,'voice');
    final language = (map['language'] ?? defaultLanguage).toString();
    if (!{'vi','en'}.contains(language)) throw const WorkoutValidationException('voice.language must be vi or en.');
    final mode = (map['mode'] ?? 'combined').toString();
    if (!{'continuous','interval','ending','combined'}.contains(mode)) throw const WorkoutValidationException('voice.mode must be continuous, interval, ending or combined.');
    return VoiceConfig(
      language: language,
      mode: mode,
      announceEvery: map['announce_every'] == null ? const Duration(seconds:10) : DurationParser.parse(map['announce_every'],field:'voice.announce_every'),
      countdownFrom: map['countdown_from'] == null ? const Duration(seconds:5) : DurationParser.parse(map['countdown_from'],field:'voice.countdown_from'),
      announceStepName: _bool(map['announce_step_name'],true,'voice.announce_step_name'),
      announceStart: _bool(map['announce_start'],true,'voice.announce_start'),
      announceFinish: _bool(map['announce_finish'],true,'voice.announce_finish'),
    );
  }

  static (String,String) _feedback(Object? value) {
    final map = value == null ? <String,dynamic>{} : _map(value);
    _unknown(map,_feedbackFields,'feedback');
    final sound = (map['sound'] ?? 'beep').toString();
    final haptic = (map['haptic'] ?? 'medium').toString();
    if (!{'beep','bell','click','none'}.contains(sound)) throw const WorkoutValidationException('feedback.sound must be beep, bell, click or none.');
    if (!{'off','light','medium','strong'}.contains(haptic)) throw const WorkoutValidationException('feedback.haptic must be off, light, medium or strong.');
    return (sound,haptic);
  }

  static String _audio(Object? value) {
    final map = value == null ? <String,dynamic>{} : _map(value);
    _unknown(map,_audioFields,'audio');
    final ducking = (map['ducking'] ?? 'medium').toString();
    if (!{'off','low','medium','high'}.contains(ducking)) throw const WorkoutValidationException('audio.ducking must be off, low, medium or high.');
    return ducking;
  }

  static List<WorkoutNode> _nodes(YamlList list,int depth) {
    if (depth > 10) throw const WorkoutValidationException('Maximum repeat nesting depth is 10.');
    final out = <WorkoutNode>[];
    for (final item in list) {
      if (item is! YamlMap) throw const WorkoutValidationException('Each step must be an object.');
      final map = _map(item);
      if (map.containsKey('repeat')) {
        _unknown(map,_repeatFields,'repeat step');
        final repeat = map['repeat'];
        if (repeat is! int || repeat < 1 || repeat > 10000) throw const WorkoutValidationException('repeat must be an integer from 1 to 10,000.');
        final children = map['steps'];
        if (children is! YamlList || children.isEmpty) throw const WorkoutValidationException('Repeat group steps must not be empty.');
        out.add(RepeatGroup(repeat:repeat,steps:_nodes(children,depth+1)));
      } else {
        _unknown(map,_stepFields,'timed step');
        final name = _string(map['name'],'step.name',100);
        final duration = map['duration'] == null
            ? Duration.zero
            : DurationParser.parseAllowZero(map['duration'],field:'step.duration');
        final guide = map['guide'] == null ? null : _string(map['guide'],'step.guide',500);
        final countdown = _bool(map['countdown'],true,'step.countdown');
        out.add(WorkoutStep(name:name,duration:duration,guide:guide,countdown:countdown));
      }
    }
    return out;
  }

  static List<String> _tags(Object? value) {
    if (value == null) return const [];
    if (value is! YamlList) throw const WorkoutValidationException('tags must be a list.');
    if (value.length > 20) throw const WorkoutValidationException('Maximum 20 tags.');
    return value.map((e) => _string(e,'tag',30)).toList(growable:false);
  }

  static Map<String,dynamic> _map(Object? value) {
    if (value is! YamlMap) throw const WorkoutValidationException('Expected an object/map.');
    return {for (final e in value.entries) e.key.toString():e.value};
  }

  static void _unknown(Map<String,dynamic> map,Set<String> allowed,String context) {
    for (final key in map.keys) {
      if (!allowed.contains(key)) throw WorkoutValidationException('Unknown field "$key" in $context.');
    }
  }

  static String _string(Object? value,String field,int max,{bool allowEmpty=false}) {
    if (value is! String) throw WorkoutValidationException('$field must be a string.');
    final trimmed = value.trim();
    if (!allowEmpty && trimmed.isEmpty) throw WorkoutValidationException('$field must not be empty.');
    if (trimmed.length > max) throw WorkoutValidationException('$field must be at most $max characters.');
    return value;
  }

  static bool _bool(Object? value,bool fallback,String field) {
    if (value == null) return fallback;
    if (value is! bool) throw WorkoutValidationException('$field must be true or false.');
    return value;
  }

  static String generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final randomA = Random().nextInt(1 << 30);
    final randomB = Random().nextInt(1 << 30);
    return '${now.toRadixString(16)}-${randomA.toRadixString(16)}-${randomB.toRadixString(16)}';
  }
}
