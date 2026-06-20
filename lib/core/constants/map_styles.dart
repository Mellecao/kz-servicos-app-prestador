import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

abstract final class MapStyles {
  static const String standard = 'asset:assets/map_style.json';

  static Future<String> loadLight() async {
    final source = await rootBundle.loadString('assets/map_style.json');
    return normalize(source);
  }

  static String normalize(String source) {
    final decoded = jsonDecode(source);
    if (decoded is List) return source;
    if (decoded is! Map<String, dynamic>) return '[]';

    final styles = decoded['styles'];
    if (styles is! List) return '[]';

    return jsonEncode(
      styles
          .whereType<Map<String, dynamic>>()
          .expand(_exportedStyleToLegacyRules)
          .toList(),
    );
  }

  static Iterable<Map<String, Object>> _exportedStyleToLegacyRules(
    Map<String, dynamic> style,
  ) sync* {
    final id = style['id'] as String?;
    if (id == null) return;

    final geometry = style['geometry'];
    if (geometry is Map<String, dynamic>) {
      final stylers = _geometryStylers(geometry);
      if (stylers.isNotEmpty) {
        yield {
          'featureType': _legacyFeatureType(id),
          'elementType': 'geometry',
          'stylers': stylers,
        };
      }
    }

    final label = style['label'];
    if (label is Map<String, dynamic>) {
      final stylers = _labelStylers(label);
      if (stylers.isNotEmpty) {
        yield {
          'featureType': _legacyFeatureType(id),
          'elementType': 'labels.text.fill',
          'stylers': stylers,
        };
      }
    }
  }

  static List<Map<String, Object>> _geometryStylers(
    Map<String, dynamic> geometry,
  ) {
    return [
      if (geometry['visible'] == false) {'visibility': 'off'},
      if (geometry['fillColor'] case final String color) {'color': color},
    ];
  }

  static List<Map<String, Object>> _labelStylers(Map<String, dynamic> label) {
    return [
      if (label['visible'] == false) {'visibility': 'off'},
      if (label['textFillColor'] case final String color) {'color': color},
    ];
  }

  static String _legacyFeatureType(String id) {
    if (id.startsWith('natural.water')) return 'water';
    if (id.startsWith('natural.land') || id == 'natural.base') {
      return 'landscape.natural';
    }
    if (id.startsWith('pointOfInterest.transit')) return 'transit';
    if (id.startsWith('pointOfInterest')) return 'poi';
    if (id == 'political') return 'administrative';
    if (id == 'infrastructure') return 'road';
    return 'all';
  }
}
