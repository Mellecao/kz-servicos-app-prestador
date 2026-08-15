class NavigationCameraState {
  final bool following;
  final bool tiltEnabled;

  const NavigationCameraState({
    required this.following,
    required this.tiltEnabled,
  });

  NavigationCameraState withManualGesture() {
    return const NavigationCameraState(following: false, tiltEnabled: false);
  }

  NavigationCameraState withRecenter() {
    return const NavigationCameraState(following: true, tiltEnabled: true);
  }

  NavigationCameraState withCameraMove({
    required double zoom,
    required double normalZoomThreshold,
  }) {
    if (zoom < normalZoomThreshold && tiltEnabled) {
      return NavigationCameraState(following: following, tiltEnabled: false);
    }
    return this;
  }
}
