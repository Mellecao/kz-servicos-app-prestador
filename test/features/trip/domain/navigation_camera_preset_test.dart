import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/trip/domain/navigation_camera_preset.dart';

void main() {
  test('navigation zoom preset is tighter for trip GPS mode', () {
    expect(navigationTiltZoom, equals(20.8));
    expect(navigationTiltZoom, greaterThan(20));
    expect(navigationNormalZoomThreshold, equals(17.8));
    expect(navigationTiltDegrees, equals(65));
  });
}
