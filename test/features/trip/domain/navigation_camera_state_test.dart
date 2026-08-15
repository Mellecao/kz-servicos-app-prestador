import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/trip/domain/navigation_camera_state.dart';

void main() {
  test('interacao manual pausa follow e desativa tilt', () {
    const state = NavigationCameraState(following: true, tiltEnabled: true);

    final next = state.withManualGesture();

    expect(next.following, isFalse);
    expect(next.tiltEnabled, isFalse);
  });

  test('recenter restaura follow e tilt 3d', () {
    const state = NavigationCameraState(following: false, tiltEnabled: false);

    final next = state.withRecenter();

    expect(next.following, isTrue);
    expect(next.tiltEnabled, isTrue);
  });

  test('zoom manual baixo achata tilt sem alterar follow', () {
    const state = NavigationCameraState(following: true, tiltEnabled: true);

    final next = state.withCameraMove(zoom: 17.5, normalZoomThreshold: 18);

    expect(next.following, isTrue);
    expect(next.tiltEnabled, isFalse);
  });
}
