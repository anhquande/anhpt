import 'package:anhpt/core/pose/pose.dart';
import 'package:flutter_test/flutter_test.dart';

PosePoint _point(
  double x,
  double y, {
  double confidence = 0.9,
  double? z,
}) =>
    PosePoint(
      x: x,
      y: y,
      z: z,
      confidence: confidence,
    );

void main() {
  group('angleBetween', () {
    test('returns 180 degrees for a straight line', () {
      final angle = angleBetween(
        _point(0, 0),
        _point(1, 0),
        _point(2, 0),
      );

      expect(angle, closeTo(180, 1e-12));
    });

    test('returns 90 degrees for a right angle', () {
      final angle = angleBetween(
        _point(1, 0),
        _point(0, 0),
        _point(0, 1),
      );

      expect(angle, closeTo(90, 1e-12));
    });

    test('returns a known acute angle', () {
      final angle = angleBetween(
        _point(1, 0),
        _point(0, 0),
        _point(1, 1),
      );

      expect(angle, closeTo(45, 1e-12));
    });

    test('returns null for a zero-length vector', () {
      final angle = angleBetween(
        _point(0.5, 0.5),
        _point(0.5, 0.5),
        _point(0.8, 0.5),
      );

      expect(angle, isNull);
    });

    test('never returns NaN or infinity for degenerate input', () {
      final angle = angleBetween(
        _point(0.25, 0.25),
        _point(0.25, 0.25),
        _point(0.75, 0.25),
      );

      expect(angle?.isNaN, isNot(isTrue));
      expect(angle?.isInfinite, isNot(isTrue));
    });

    test('clamps cosine for nearly collinear coordinates', () {
      final angle = angleBetween(
        _point(1, 0),
        _point(0, 0),
        _point(1, 1e-15),
      );

      expect(angle, isNotNull);
      expect(angle!.isFinite, isTrue);
      expect(angle, closeTo(0, 1e-6));
    });
  });

  group('distance', () {
    test('uses normalized coordinates without viewport conversion', () {
      final value = distance(
        _point(0.1, 0.2),
        _point(0.4, 0.6),
      );

      expect(value, closeTo(0.5, 1e-12));
    });
  });

  group('midpoint', () {
    test('averages coordinates and keeps the lower confidence', () {
      final value = midpoint(
        _point(0.2, 0.4, confidence: 0.8),
        _point(0.6, 0.8, confidence: 0.6),
      );

      expect(value, isNotNull);
      expect(value!.x, closeTo(0.4, 1e-12));
      expect(value.y, closeTo(0.6, 1e-12));
      expect(value.confidence, 0.6);
    });

    test('averages depth only when both points have depth', () {
      final threeDimensional = midpoint(
        _point(0.2, 0.4, z: 0.1),
        _point(0.6, 0.8, z: 0.5),
      );
      final twoDimensional = midpoint(
        _point(0.2, 0.4, z: 0.1),
        _point(0.6, 0.8),
      );

      expect(threeDimensional!.z, closeTo(0.3, 1e-12));
      expect(twoDimensional!.z, isNull);
    });

    test('returns null when either point is missing', () {
      expect(midpoint(null, _point(0.6, 0.8)), isNull);
      expect(midpoint(_point(0.2, 0.4), null), isNull);
    });
  });

  group('bodyScale', () {
    test('returns the larger value between shoulder width and torso length', () {
      final value = bodyScale(
        leftShoulder: _point(0.3, 0.2),
        rightShoulder: _point(0.7, 0.2),
        leftHip: _point(0.4, 0.7),
        rightHip: _point(0.6, 0.7),
      );

      expect(value, closeTo(0.5, 1e-12));
    });

    test('can fall back to shoulder width when hips are missing', () {
      final value = bodyScale(
        leftShoulder: _point(0.3, 0.2),
        rightShoulder: _point(0.7, 0.2),
      );

      expect(value, closeTo(0.4, 1e-12));
    });

    test('returns null when no scale can be calculated', () {
      expect(bodyScale(leftShoulder: _point(0.3, 0.2)), isNull);
    });

    test('is viewport-independent because only normalized points are supplied', () {
      final value = bodyScale(
        leftShoulder: _point(0.2, 0.2),
        rightShoulder: _point(0.8, 0.2),
        leftHip: _point(0.45, 0.8),
        rightHip: _point(0.55, 0.8),
      );

      expect(value, closeTo(0.6, 1e-12));
    });
  });
}
