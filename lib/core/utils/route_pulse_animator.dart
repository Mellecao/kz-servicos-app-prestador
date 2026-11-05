import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RoutePulseAnimator {
  final TickerProvider vsync;
  final VoidCallback onTick;

  AnimationController? _controller;
  List<LatLng> _points = [];
  List<double> _distances = [];
  double _totalLength = 0;

  RoutePulseAnimator({required this.vsync, required this.onTick});

  void start(List<LatLng> points) {
    stop();
    if (points.length < 2) return;
    _points = points;
    _distances = _computeSegmentDistances(points);
    _totalLength = _distances.isEmpty ? 0 : _distances.last;
    _controller = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 3000),
    );
    _controller!.addListener(onTick);
    _controller!.repeat();
  }

  void stop() {
    _controller?.removeListener(onTick);
    _controller?.dispose();
    _controller = null;
  }

  void dispose() => stop();

  Set<Polyline> buildPulsePolylines() {
    if (_points.length < 2 || _controller == null) return {};
    final t = _controller!.value;
    const segmentRatio = 0.20;
    final headDist = t * (_totalLength * (1 + segmentRatio));
    final tailDist = headDist - _totalLength * segmentRatio;
    final clampedHead = headDist.clamp(0.0, _totalLength);
    final clampedTail = tailDist.clamp(0.0, _totalLength);

    if (clampedHead - clampedTail < 1) return {};

    final glowPoints = _extractSubRoute(clampedTail, clampedHead);
    final fadeFactor = _computeFade(t);
    if (glowPoints.length < 2) return {};

    return {
      Polyline(
        polylineId: const PolylineId('pulse_glow'),
        points: glowPoints,
        color: Colors.white.withValues(alpha: 0.45 * fadeFactor),
        width: 12,
      ),
      Polyline(
        polylineId: const PolylineId('pulse_core'),
        points: glowPoints,
        color: Colors.white.withValues(alpha: 0.85 * fadeFactor),
        width: 5,
      ),
    };
  }

  List<double> _computeSegmentDistances(List<LatLng> pts) {
    final dists = <double>[0.0];
    for (int i = 1; i < pts.length; i++) {
      dists.add(dists.last + _haversine(pts[i - 1], pts[i]));
    }
    return dists;
  }

  double _haversine(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final hav =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(a.latitude)) *
            math.cos(_toRad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(hav), math.sqrt(1 - hav));
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  LatLng _interpolateAtDistance(double dist) {
    if (dist <= 0) return _points.first;
    if (dist >= _totalLength) return _points.last;
    int lo = 0, hi = _distances.length - 1;
    while (lo < hi - 1) {
      final mid = (lo + hi) ~/ 2;
      if (_distances[mid] <= dist) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final segStart = _distances[lo];
    final segEnd = _distances[hi];
    final t = (dist - segStart) / (segEnd - segStart);
    final a = _points[lo];
    final b = _points[hi];
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  List<LatLng> _extractSubRoute(double from, double to) {
    final result = <LatLng>[];
    result.add(_interpolateAtDistance(from));
    for (int i = 0; i < _distances.length; i++) {
      final d = _distances[i];
      if (d > from && d < to) result.add(_points[i]);
    }
    result.add(_interpolateAtDistance(to));
    return result;
  }

  double _computeFade(double t) {
    const fadeZone = 0.08;
    if (t < fadeZone) return t / fadeZone;
    if (t > 1 - fadeZone) return (1 - t) / fadeZone;
    return 1.0;
  }
}
