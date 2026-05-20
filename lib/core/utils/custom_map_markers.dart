import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';

abstract final class CustomMapMarkers {
  static Future<BitmapDescriptor> createYellowPinIcon() async {
    const width = 32.0;
    const height = 44.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = AppColors.highlight;
    canvas.drawCircle(const Offset(width / 2, 14), 12, paint);
    final path = Path()
      ..moveTo(width / 2 - 8, 20)
      ..lineTo(width / 2, height - 2)
      ..lineTo(width / 2 + 8, 20)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      const Offset(width / 2, 14),
      5,
      Paint()..color = Colors.white,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> createYellowCircleIcon() async {
    const size = 28.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = AppColors.highlight.withValues(alpha: 0.3),
    );
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      9,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      7,
      Paint()..color = AppColors.highlight,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> createDriverLocationIcon() async {
    const size = 32.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = AppColors.highlight.withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      10,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      8,
      Paint()..color = AppColors.highlight,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> createBlueTriangleIcon() async {
    const size = 48.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final fillPaint = Paint()
      ..color = const Color(0xFF2261FE)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path()
      ..moveTo(size / 2, 2)
      ..lineTo(size - 4, size - 4)
      ..lineTo(4, size - 4)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
}
