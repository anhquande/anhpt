enum HealthUnitSystem { metric, imperial }

enum HealthSex { female, male, other, unspecified }

class HealthProfile {
  final HealthSex sex;
  final int? birthYear;
  final double? heightCm;
  final HealthUnitSystem unitSystem;

  const HealthProfile({
    this.sex = HealthSex.unspecified,
    this.birthYear,
    this.heightCm,
    this.unitSystem = HealthUnitSystem.metric,
  });

  HealthProfile copyWith({
    HealthSex? sex,
    int? birthYear,
    double? heightCm,
    HealthUnitSystem? unitSystem,
  }) =>
      HealthProfile(
        sex: sex ?? this.sex,
        birthYear: birthYear ?? this.birthYear,
        heightCm: heightCm ?? this.heightCm,
        unitSystem: unitSystem ?? this.unitSystem,
      );

  Map<String, dynamic> toJson() => {
        'sex': sex.name,
        'birthYear': birthYear,
        'heightCm': heightCm,
        'unitSystem': unitSystem.name,
      };

  factory HealthProfile.fromJson(Map<String, dynamic> json) => HealthProfile(
        sex: HealthSex.values.firstWhere(
          (value) => value.name == json['sex'],
          orElse: () => HealthSex.unspecified,
        ),
        birthYear: (json['birthYear'] as num?)?.toInt(),
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        unitSystem: HealthUnitSystem.values.firstWhere(
          (value) => value.name == json['unitSystem'],
          orElse: () => HealthUnitSystem.metric,
        ),
      );
}

class WeightMeasurement {
  final String id;
  final double weightKg;
  final DateTime measuredAt;
  final String? note;

  const WeightMeasurement({
    required this.id,
    required this.weightKg,
    required this.measuredAt,
    this.note,
  });

  WeightMeasurement copyWith({
    double? weightKg,
    DateTime? measuredAt,
    String? note,
  }) =>
      WeightMeasurement(
        id: id,
        weightKg: weightKg ?? this.weightKg,
        measuredAt: measuredAt ?? this.measuredAt,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'weightKg': weightKg,
        'measuredAt': measuredAt.toUtc().toIso8601String(),
        if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      };

  factory WeightMeasurement.fromJson(Map<String, dynamic> json) =>
      WeightMeasurement(
        id: json['id'] as String,
        weightKg: (json['weightKg'] as num).toDouble(),
        measuredAt: DateTime.parse(json['measuredAt'] as String).toLocal(),
        note: json['note'] as String?,
      );
}

class DailyWeightPoint {
  final DateTime day;
  final double averageKg;
  final List<WeightMeasurement> measurements;

  const DailyWeightPoint({
    required this.day,
    required this.averageKg,
    required this.measurements,
  });
}

class WeightForecast {
  final DateTime targetDate;
  final double lowKg;
  final double highKg;
  final double centerKg;

  const WeightForecast({
    required this.targetDate,
    required this.lowKg,
    required this.highKg,
    required this.centerKg,
  });
}
