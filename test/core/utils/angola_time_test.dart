import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/utils/angola_time.dart';

void main() {
  test('converte UTC do backend para a hora de Luanda (UTC+1)', () {
    final t = AngolaTime.fromBackend('2026-11-05T12:00:00Z');
    expect(t.hour, 13);
    expect(t.day, 5);
  });

  test('passa para o dia seguinte depois das 23:00 UTC', () {
    final t = AngolaTime.fromBackend('2026-11-05T23:30:00Z');
    expect(t.day, 6);
    expect(t.hour, 0);
  });

  test('vazio ou nulo devolve null', () {
    expect(AngolaTime.maybeFromBackend(null), isNull);
    expect(AngolaTime.maybeFromBackend(''), isNull);
  });
}
