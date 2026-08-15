import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/schedules/domain/schedule_detail_mode.dart';

void main() {
  test('re-check usa texto de cliente confirmado', () {
    expect(
      scheduleDetailHeaderTitle(isDriverRecheck: true),
      'Cliente confirmou sua viagem',
    );
    expect(
      scheduleDetailHeaderSubtitle(isDriverRecheck: true),
      'Confira os detalhes e confirme se ainda quer manter o agendamento',
    );
  });

  test('re-check mostra valor sem permitir edicao', () {
    expect(shouldShowPriceOfferCard(isDriverRecheck: true), isTrue);
    expect(isPriceOfferEditable(isDriverRecheck: true), isFalse);
  });

  test('solicitacao comum mantem campo de valor editavel', () {
    expect(shouldShowPriceOfferCard(isDriverRecheck: false), isTrue);
    expect(isPriceOfferEditable(isDriverRecheck: false), isTrue);
  });
}
