import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kz_servicos_prestador/features/trip/domain/navigation_position_filter.dart';

void main() {
  const filter = NavigationPositionFilter();
  final now = DateTime.utc(2026, 6, 29, 12);

  Position position({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
    double accuracy = 8,
    double heading = 0,
    double headingAccuracy = 10,
    double speed = 0,
  }) {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp ?? now,
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: heading,
      headingAccuracy: headingAccuracy,
      speed: speed,
      speedAccuracy: 0,
    );
  }

  test('aceita primeira posicao precisa e recente', () {
    final candidate = position(latitude: -23.55, longitude: -46.63);

    expect(filter.shouldAccept(candidate, now: now), isTrue);
  });

  test('rejeita posicao com baixa precisao horizontal', () {
    final candidate = position(
      latitude: -23.55,
      longitude: -46.63,
      accuracy: 80,
    );

    expect(filter.shouldAccept(candidate, now: now), isFalse);
  });

  test('rejeita posicao antiga para evitar cache do sistema', () {
    final candidate = position(
      latitude: -23.55,
      longitude: -46.63,
      timestamp: now.subtract(const Duration(seconds: 20)),
    );

    expect(filter.shouldAccept(candidate, now: now), isFalse);
  });

  test('rejeita salto impossivel entre duas ruas', () {
    final previous = position(
      latitude: -23.5505,
      longitude: -46.6333,
      timestamp: now,
    );
    final candidate = position(
      latitude: -23.5580,
      longitude: -46.6420,
      timestamp: now.add(const Duration(seconds: 2)),
    );

    expect(
      filter.shouldAccept(
        candidate,
        previous: previous,
        now: candidate.timestamp,
      ),
      isFalse,
    );
  });

  test('prioriza a bussola mesmo quando o carro esta em movimento', () {
    final candidate = position(
      latitude: -23.55,
      longitude: -46.63,
      heading: 92,
      speed: 8,
    );

    expect(
      filter.resolveHeading(
        position: candidate,
        compassHeading: 20,
        previousHeading: 10,
      ),
      20,
    );
  });

  test('usa bussola quando o veiculo esta parado', () {
    final candidate = position(
      latitude: -23.55,
      longitude: -46.63,
      heading: 92,
      speed: 0.5,
    );

    expect(
      filter.resolveHeading(
        position: candidate,
        compassHeading: 35,
        previousHeading: 10,
      ),
      35,
    );
  });
}
