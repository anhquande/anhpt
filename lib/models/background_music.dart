class MusicTrack {
  final String id;
  final String name;
  final String mood;
  final String source;
  final bool bundled;
  final DateTime createdAt;

  const MusicTrack(
      {required this.id,
      required this.name,
      required this.mood,
      required this.source,
      required this.bundled,
      required this.createdAt});
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mood': mood,
        'source': source,
        'bundled': bundled,
        'createdAt': createdAt.toIso8601String()
      };
  static MusicTrack fromJson(Map<String, dynamic> json) => MusicTrack(
      id: json['id'] as String,
      name: json['name'] as String,
      mood: json['mood'] as String? ?? '',
      source: json['source'] as String,
      bundled: json['bundled'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String));
}

class WorkoutMusicConfig {
  final String workoutId;
  final String? trackId;
  final bool enabled;
  final double baseVolume;
  final String duckingMode;
  const WorkoutMusicConfig(
      {required this.workoutId,
      this.trackId,
      this.enabled = false,
      this.baseVolume = .35,
      this.duckingMode = 'gentle'});
  Map<String, dynamic> toJson() => {
        'workoutId': workoutId,
        'trackId': trackId,
        'enabled': enabled,
        'baseVolume': baseVolume,
        'duckingMode': duckingMode
      };
  static WorkoutMusicConfig fromJson(Map<String, dynamic> json) =>
      WorkoutMusicConfig(
          workoutId: json['workoutId'] as String,
          trackId: json['trackId'] as String?,
          enabled: json['enabled'] as bool? ?? false,
          baseVolume: (json['baseVolume'] as num?)?.toDouble() ?? .35,
          duckingMode: json['duckingMode'] as String? ?? 'gentle');
  WorkoutMusicConfig copyWith(
          {String? trackId,
          bool clearTrack = false,
          bool? enabled,
          double? baseVolume,
          String? duckingMode}) =>
      WorkoutMusicConfig(
          workoutId: workoutId,
          trackId: clearTrack ? null : trackId ?? this.trackId,
          enabled: enabled ?? this.enabled,
          baseVolume: baseVolume ?? this.baseVolume,
          duckingMode: duckingMode ?? this.duckingMode);
}
