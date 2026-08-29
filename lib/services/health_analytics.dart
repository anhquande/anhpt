import 'dart:math' as math;

import '../models/health.dart';

class HealthAnalytics {
  static List<DailyWeightPoint> dailyAverages(
    List<WeightMeasurement> measurements,
  ) {
    final grouped = <DateTime, List<WeightMeasurement>>{};
    for (final measurement in measurements) {
      final local = measurement.measuredAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      grouped.putIfAbsent(day, () => []).add(measurement);
    }
    final points = grouped.entries.map((entry) {
      final average = entry.value
              .map((value) => value.weightKg)
              .reduce((a, b) => a + b) /
          entry.value.length;
      entry.value.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
      return DailyWeightPoint(
        day: entry.key,
        averageKg: average,
        measurements: List.unmodifiable(entry.value),
      );
    }).toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    return points;
  }

  static double? bmi(double? heightCm, double? weightKg) {
    if (heightCm == null || weightKg == null || heightCm <= 0) return null;
    final meters = heightCm / 100;
    return weightKg / (meters * meters);
  }

  static List<WeightForecast> forecasts(List<DailyWeightPoint> allPoints) {
    if (allPoints.length < 8) return const [];
    final span = allPoints.last.day.difference(allPoints.first.day).inDays;
    if (span < 14) return const [];

    final points = allPoints.length > 30
        ? allPoints.sublist(allPoints.length - 30)
        : allPoints;
    final origin = points.first.day;
    final xs = points
        .map((point) => point.day.difference(origin).inDays.toDouble())
        .toList();
    final ys = points.map((point) => point.averageKg).toList();
    final xMean = xs.reduce((a, b) => a + b) / xs.length;
    final yMean = ys.reduce((a, b) => a + b) / ys.length;
    var numerator = 0.0;
    var denominator = 0.0;
    for (var i = 0; i < xs.length; i++) {
      numerator += (xs[i] - xMean) * (ys[i] - yMean);
      denominator += math.pow(xs[i] - xMean, 2).toDouble();
    }
    if (denominator == 0) return const [];
    final slope = numerator / denominator;
    final intercept = yMean - slope * xMean;

    var squaredError = 0.0;
    for (var i = 0; i < xs.length; i++) {
      final predicted = intercept + slope * xs[i];
      squaredError += math.pow(ys[i] - predicted, 2).toDouble();
    }
    final rmse = math.sqrt(squaredError / xs.length);
    if (rmse > 2.5) return const [];

    WeightForecast makeForecast(int days) {
      final target = points.last.day.add(Duration(days: days));
      final targetX = target.difference(origin).inDays.toDouble();
      final center = intercept + slope * targetX;
      final horizonPenalty = days == 7 ? 1.0 : 1.7;
      final uncertainty = math.max(0.3, rmse * 1.96 * horizonPenalty);
      return WeightForecast(
        targetDate: target,
        centerKg: center,
        lowKg: center - uncertainty,
        highKg: center + uncertainty,
      );
    }

    final result = <WeightForecast>[makeForecast(7)];
    if (allPoints.length >= 12 && span >= 21) result.add(makeForecast(30));
    return result;
  }

  static String bmiLabel(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Healthy range';
    if (bmi < 30) return 'Overweight';
    return 'Obesity range';
  }
}
