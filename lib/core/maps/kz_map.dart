import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:kz_servicos_prestador/core/constants/map_styles.dart';

class KzMapController {
  final gm.GoogleMapController? _googleController;

  KzMapController._google(this._googleController);

  Future<void> animateTo({
    required gm.LatLng target,
    required double zoom,
    double bearing = 0,
    double tilt = 0,
  }) async {
    final googleController = _googleController;
    if (googleController != null) {
      await googleController.animateCamera(
        gm.CameraUpdate.newCameraPosition(
          gm.CameraPosition(
            target: target,
            zoom: zoom,
            bearing: bearing,
            tilt: tilt,
          ),
        ),
      );
      return;
    }
  }

  Future<void> fitBounds(gm.LatLngBounds bounds, {double padding = 80}) async {
    final googleController = _googleController;
    if (googleController != null) {
      await googleController.animateCamera(
        gm.CameraUpdate.newLatLngBounds(bounds, padding),
      );
      return;
    }
  }
}

class KzMap extends StatefulWidget {
  final gm.CameraPosition initialCameraPosition;
  final Set<gm.Marker> markers;
  final Set<gm.Polyline> polylines;
  final ValueChanged<KzMapController>? onMapCreated;
  final VoidCallback? onCameraMoveStarted;
  final ValueChanged<gm.CameraPosition>? onCameraMove;
  final VoidCallback? onCameraIdle;
  final String? style;
  final bool zoomControlsEnabled;
  final bool scrollGesturesEnabled;
  final bool rotateGesturesEnabled;
  final bool tiltGesturesEnabled;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool buildingsEnabled;

  const KzMap({
    super.key,
    required this.initialCameraPosition,
    this.markers = const {},
    this.polylines = const {},
    this.onMapCreated,
    this.onCameraMoveStarted,
    this.onCameraMove,
    this.onCameraIdle,
    this.style,
    this.zoomControlsEnabled = true,
    this.scrollGesturesEnabled = true,
    this.rotateGesturesEnabled = true,
    this.tiltGesturesEnabled = true,
    this.myLocationEnabled = false,
    this.myLocationButtonEnabled = false,
    this.buildingsEnabled = true,
  });

  @override
  State<KzMap> createState() => _KzMapState();
}

class _KzMapState extends State<KzMap> {
  String? _loadedStyle;

  @override
  void initState() {
    super.initState();
    _loadStyleIfNeeded();
  }

  @override
  void didUpdateWidget(covariant KzMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style != widget.style) {
      _loadedStyle = null;
      _loadStyleIfNeeded();
    }
  }

  void _loadStyleIfNeeded() {
    if (widget.style != MapStyles.standard) return;
    MapStyles.loadLight().then((style) {
      if (!mounted || widget.style != MapStyles.standard) return;
      setState(() => _loadedStyle = style);
    });
  }

  @override
  Widget build(BuildContext context) {
    return gm.GoogleMap(
      initialCameraPosition: widget.initialCameraPosition,
      markers: widget.markers,
      polylines: widget.polylines,
      onMapCreated: (controller) {
        widget.onMapCreated?.call(KzMapController._google(controller));
      },
      onCameraMoveStarted: widget.onCameraMoveStarted,
      onCameraMove: widget.onCameraMove,
      onCameraIdle: widget.onCameraIdle,
      style: _effectiveGoogleStyle,
      zoomControlsEnabled: widget.zoomControlsEnabled,
      scrollGesturesEnabled: widget.scrollGesturesEnabled,
      rotateGesturesEnabled: widget.rotateGesturesEnabled,
      tiltGesturesEnabled: widget.tiltGesturesEnabled,
      myLocationEnabled: widget.myLocationEnabled,
      myLocationButtonEnabled: widget.myLocationButtonEnabled,
      buildingsEnabled: widget.buildingsEnabled,
    );
  }

  String? get _effectiveGoogleStyle {
    if (widget.style == MapStyles.standard) return _loadedStyle;
    return widget.style;
  }
}
