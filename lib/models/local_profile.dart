class LocalProfile {
  final String id;
  final String name;
  final DateTime createdAt;

  const LocalProfile({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  LocalProfile copyWith({String? name}) => LocalProfile(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory LocalProfile.fromJson(Map<String, dynamic> json) => LocalProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}
