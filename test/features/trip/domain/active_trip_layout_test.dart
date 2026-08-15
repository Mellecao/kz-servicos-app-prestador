import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/trip/domain/active_trip_layout.dart';

void main() {
  test('menu fica no topo quando nao ha banner de navegacao', () {
    expect(activeTripMenuTopOffset(showNavigationBanner: false), 8);
  });

  test('menu fica abaixo do banner de navegacao quando instrucoes aparecem', () {
    expect(activeTripMenuTopOffset(showNavigationBanner: true), 168);
  });
}
