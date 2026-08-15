import 'package:geolocator/geolocator.dart';

class NavigationPositionFilter {
  final double maxHorizontalAccuracyMeters;
  final Duration maxStaleAge;
  final double maxReasonableSpeedMetersPerSecond;
  final double jumpToleranceMeters;

  const NavigationPositionFilter({
    this.maxHorizontalAccuracyMeters = 35,
    this.maxStaleAge = const Duration(seconds: 10),
    this.maxReasonableSpeedMetersPerSecond = 42,
    this.jumpToleranceMeters = 25,
  });

  bool shouldAccept(Position candidate, {Position? previous, DateTime? now}) {
    if (!candidate.latitude.isFinite || !candidate.longitude.isFinite) {
      return false;
    }
    if (candidate.accuracy > maxHorizontalAccuracyMeters) return false;

    final referenceNow = now ?? DateTime.now().toUtc();
    final age = referenceNow.difference(candidate.timestamp.toUtc());
    if (age > maxStaleAge) return false;

    if (previous == null) return true;
    if (candidate.timestamp.isBefore(previous.timestamp)) return false;

    final elapsedSeconds =
        candidate.timestamp.difference(previous.timestamp).inMilliseconds /
        1000;
    if (elapsedSeconds <= 0) return true;

    final distanceMeters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      candidate.latitude,
      candidate.longitude,
    );
    final allowedDistance =
        (elapsedSeconds * maxReasonableSpeedMetersPerSecond) +
        candidate.accuracy +
        previous.accuracy +
        jumpToleranceMeters;

    return distanceMeters <= allowedDistance;
  }

  double resolveHeading({
    required Position position,
    required double compassHeading,
    required double previousHeading,
  }) {
    if (compassHeading.isFinite && compassHeading >= 0) {
      return compassHeading % 360;
    }
    final hasGpsHeading =
        position.heading.isFinite &&
        position.heading >= 0 &&
        (position.headingAccuracy == 0 || position.headingAccuracy <= 45);
    if (hasGpsHeading) return position.heading;
    return previousHeading;
  }
}
