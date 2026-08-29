class LocalProfile {
  final String id;
  final String name;
  final String? avatarBase64;
  final DateTime createdAt;

  const LocalProfile({
    required this.id,
    required this.name,
    this.avatarBase64,
    required this.createdAt,
  });

  LocalProfile copyWith({
    String? name,
    String? avatarBase64,
    bool clearAvatar = false,
  }) =>
      LocalProfile(
        id: id,
        name: name ?? this.name,
        avatarBase64: clearAvatar ? null : avatarBase64 ?? this.avatarBase64,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (avatarBase64 != null) 'avatarBase64': avatarBase64,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory LocalProfile.fromJson(Map<String, dynamic> json) => LocalProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        avatarBase64: json['avatarBase64'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}
