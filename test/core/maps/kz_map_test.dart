import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kz_servicos_prestador/core/maps/kz_map.dart';

void main() {
  testWidgets('KzMap renders Google Maps without OSM decoration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: KzMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(-23.5505, -46.6333),
              zoom: 15,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(GoogleMap), findsOneWidget);
    expect(find.byType(ColorFiltered), findsNothing);
  });
}
