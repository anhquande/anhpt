import 'package:anhpt/models/health.dart';
import 'package:anhpt/services/health_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dailyAverages groups multiple measurements per day', () {
    final values = [
      WeightMeasurement(id: 'a', weightKg: 70, measuredAt: DateTime(2026, 8, 1, 8)),
      WeightMeasurement(id: 'b', weightKg: 72, measuredAt: DateTime(2026, 8, 1, 20)),
      WeightMeasurement(id: 'c', weightKg: 71, measuredAt: DateTime(2026, 8, 2, 8)),
    ];

    final points = HealthAnalytics.dailyAverages(values);

    expect(points, hasLength(2));
    expect(points.first.averageKg, 71);
    expect(points.first.measurements, hasLength(2));
  });

  test('bmi uses metric height and weight', () {
    expect(HealthAnalytics.bmi(175, 70), closeTo(22.86, 0.01));
  });

  test('forecast is gated until enough data exists', () {
    final sparse = List.generate(
      7,
      (index) => DailyWeightPoint(
        day: DateTime(2026, 8, 1 + index * 2),
        averageKg: 75 - index * .1,
        measurements: const [],
      ),
    );

    expect(HealthAnalytics.forecasts(sparse), isEmpty);
  });

  test('forecast returns week and month ranges for stable trend', () {
    final points = List.generate(
      15,
      (index) => DailyWeightPoint(
        day: DateTime(2026, 8, 1 + index * 2),
        averageKg: 75 - index * .12,
        measurements: const [],
      ),
    );

    final forecasts = HealthAnalytics.forecasts(points);

    expect(forecasts, hasLength(2));
    expect(forecasts.first.lowKg, lessThan(forecasts.first.centerKg));
    expect(forecasts.first.highKg, greaterThan(forecasts.first.centerKg));
  });
}
