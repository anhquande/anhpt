import 'dart:math' as math;

import 'body_pose.dart';

const double _epsilon = 1e-12;

/// Returns the 2D angle ABC in degrees, with [b] as the vertex.
///
/// The calculation uses the canonical normalized x/y pose coordinates only:
/// vector BA is compared with vector BC by `acos(dot / (|BA| * |BC|))`.
/// Optional depth is intentionally ignored so the result is viewport- and
/// engine-independent for both 2D and 3D estimators.
///
/// Degrees are returned instead of radians because exercise rules and human
/// coaching thresholds are usually specified as readable degree ranges.
///
/// Returns `null` when either vector is nearly zero length or when a stable,
/// finite result cannot be produced. The returned value is never NaN or
/// infinity.
double? angleBetween(
  PosePoint a,
  PosePoint b,
  PosePoint c,
) {
  final bax = a.x - b.x;
  final bay = a.y - b.y;
  final bcx = c.x - b.x;
  final bcy = c.y - b.y;
  final baLength = _length(bax, bay);
  final bcLength = _length(bcx, bcy);

  if (baLength <= _epsilon || bcLength <= _epsilon) {
    return null;
  }

  final denominator = baLength * bcLength;
  if (denominator <= _epsilon || !denominator.isFinite) {
    return null;
  }

  final cosine = _clamp(_dot(bax, bay, bcx, bcy) / denominator, -1, 1);
  final angle = math.acos(cosine) * 180 / math.pi;

  if (!angle.isFinite) {
    return null;
  }
  return angle;
}

/// Returns the Euclidean distance between two canonical pose points.
///
/// The distance is measured directly in normalized pose coordinates. It is not
/// converted to pixels, centimeters, or any viewport-dependent unit.
double distance(
  PosePoint a,
  PosePoint b,
) =>
    _length(b.x - a.x, b.y - a.y);

/// Returns the midpoint between [a] and [b] in normalized coordinates.
///
/// Returns `null` when either point is missing. Confidence uses the lower of
/// the two input confidences so the midpoint never appears more reliable than
/// the weaker landmark. Optional depth is averaged only when both inputs have a
/// depth value; otherwise the returned point stays 2D.
PosePoint? midpoint(
  PosePoint? a,
  PosePoint? b,
) {
  if (a == null || b == null) return null;

  final az = a.z;
  final bz = b.z;

  return PosePoint(
    x: (a.x + b.x) / 2,
    y: (a.y + b.y) / 2,
    z: az != null && bz != null ? (az + bz) / 2 : null,
    confidence: math.min(a.confidence, b.confidence),
  );
}

/// Estimates a normalized body scale from canonical upper-body landmarks.
///
/// Strategy:
///
/// 1. Calculate shoulder width when both shoulders exist.
/// 2. Calculate torso length when both shoulders and both hips exist, using the
///    distance from mid-shoulder to mid-hip.
/// 3. Return the larger available measurement.
///
/// The result stays in normalized pose-coordinate units. No viewport, pixel, or
/// centimeter conversion is performed. Returns `null` when neither shoulder
/// width nor torso length can be calculated.
double? bodyScale({
  PosePoint? leftShoulder,
  PosePoint? rightShoulder,
  PosePoint? leftHip,
  PosePoint? rightHip,
}) {
  final shoulderWidth = _distanceOrNull(leftShoulder, rightShoulder);
  final midShoulder = midpoint(leftShoulder, rightShoulder);
  final midHip = midpoint(leftHip, rightHip);
  final torsoLength = _distanceOrNull(midShoulder, midHip);

  if (shoulderWidth == null) return torsoLength;
  if (torsoLength == null) return shoulderWidth;
  return math.max(shoulderWidth, torsoLength);
}

double? _distanceOrNull(PosePoint? a, PosePoint? b) {
  if (a == null || b == null) return null;
  final value = distance(a, b);
  if (!value.isFinite) return null;
  return value;
}

double _dot(double ax, double ay, double bx, double by) => ax * bx + ay * by;

double _length(double x, double y) => math.sqrt(x * x + y * y);

double _clamp(double value, double lower, double upper) {
  if (value < lower) return lower;
  if (value > upper) return upper;
  return value;
}
