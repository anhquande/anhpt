class CoachRecording {
  static const currentVersion = 2;

  final String workoutId;
  final String cue;
  final String scope;
  final String? stepKey;
  final String? profile;
  final String language;
  final String audioPath;
  final DateTime createdAt;
  final int version;

  const CoachRecording(
      {required this.workoutId,
      required this.cue,
      required this.scope,
      required this.language,
      required this.audioPath,
      required this.createdAt,
      this.stepKey,
      this.profile,
      this.version = currentVersion});

  Map<String, dynamic> toJson() => {
        'workoutId': workoutId,
        'cue': cue,
        'scope': scope,
        'stepKey': stepKey,
        'profile': profile,
        'language': language,
        'audioPath': audioPath,
        'createdAt': createdAt.toIso8601String(),
        'version': version
      };

  static CoachRecording fromJson(Map<String, dynamic> json) => CoachRecording(
        workoutId: json['workoutId'] as String,
        cue: json['cue'] as String,
        scope: json['scope'] as String? ?? 'description',
        stepKey: json['stepKey'] as String?,
        profile: json['profile'] as String?,
        language: json['language'] as String,
        audioPath: json['audioPath'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        version: json['version'] as int? ?? currentVersion,
      );

  String get storageKey => '$workoutId::$scope::${stepKey ?? ''}';
}
