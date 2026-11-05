import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/models/service_request_data.dart';
import 'package:kz_servicos_prestador/features/other_services/domain/service_request_flow.dart';

const _me = 'prov-me';

ServiceRequestData _request({
  String status = 'searching_provider',
  String? providerProfileId,
  String? candidateStatus,
  double? candidateOfferedPrice,
  double? finalPrice,
}) {
  return ServiceRequestData.fromMap(
    {
      'id': 'req-1',
      'service_category_id': 'cat-1',
      'description': 'Tomada sem energia',
      'service_date': '2026-11-05T12:00:00.000Z',
      'status': status,
      'provider_profile_id': providerProfileId,
      'final_price': finalPrice,
      'is_paid': false,
      'created_at': '2026-11-05T10:00:00.000Z',
      'service_categories': {'name': 'Eletricista'},
      'addresses': {'formatted_address': 'Talatona, Luanda'},
      'client': {'full_name': 'Miguel Cliente'},
    },
  ).withCandidate(status: candidateStatus, offeredPrice: candidateOfferedPrice);
}

void main() {
  group('providerActionFor', () {
    test('convite pending permite propor preço', () {
      final r = _request(candidateStatus: 'pending');
      expect(providerActionFor(r, _me), ProviderServiceAction.proposePrice);
    });

    test('convite com proposta enviada aguarda o administrador', () {
      final r = _request(
        candidateStatus: 'accepted',
        candidateOfferedPrice: 15000,
      );
      expect(providerActionFor(r, _me), ProviderServiceAction.awaitingAdmin);
    });

    test('convite recusado não tem ação', () {
      final r = _request(candidateStatus: 'rejected');
      expect(providerActionFor(r, _me), ProviderServiceAction.none);
    });

    test(
      'pedido sem prestador e sem convite não tem ação (open é inalcançável)',
      () {
        final r = _request(status: 'open');
        expect(providerActionFor(r, _me), ProviderServiceAction.none);
      },
    );

    test('escolhido, aguardando cliente', () {
      final r = _request(
        status: 'awaiting_client_confirmation',
        providerProfileId: _me,
      );
      expect(providerActionFor(r, _me), ProviderServiceAction.awaitingClient);
    });

    test('awaiting_provider_confirmation -> confirmar', () {
      final r = _request(
        status: 'awaiting_provider_confirmation',
        providerProfileId: _me,
      );
      expect(providerActionFor(r, _me), ProviderServiceAction.confirm);
    });

    test('assigned -> iniciar; in_progress -> concluir', () {
      expect(
        providerActionFor(
          _request(status: 'assigned', providerProfileId: _me),
          _me,
        ),
        ProviderServiceAction.start,
      );
      expect(
        providerActionFor(
          _request(status: 'in_progress', providerProfileId: _me),
          _me,
        ),
        ProviderServiceAction.finish,
      );
    });

    test('finished e cancelled não têm ação', () {
      for (final s in ['finished', 'cancelled']) {
        expect(
          providerActionFor(_request(status: s, providerProfileId: _me), _me),
          ProviderServiceAction.none,
          reason: s,
        );
      }
    });

    test('pedido de outro prestador não tem ação', () {
      final r = _request(status: 'assigned', providerProfileId: 'outro');
      expect(providerActionFor(r, _me), ProviderServiceAction.none);
    });
  });

  group('nextStatusFor', () {
    test('mapeia ação para o próximo estado', () {
      expect(nextStatusFor(ProviderServiceAction.confirm), 'assigned');
      expect(nextStatusFor(ProviderServiceAction.start), 'in_progress');
      expect(nextStatusFor(ProviderServiceAction.finish), 'finished');
      expect(nextStatusFor(ProviderServiceAction.proposePrice), isNull);
      expect(nextStatusFor(ProviderServiceAction.none), isNull);
    });
  });

  group('serviceStatusLabel (pt-AO)', () {
    test('textos por estado', () {
      expect(
        serviceStatusLabel(_request(candidateStatus: 'pending'), _me),
        'Convite — proponha o seu preço',
      );
      expect(
        serviceStatusLabel(_request(candidateStatus: 'accepted'), _me),
        'Proposta enviada · a aguardar o administrador',
      );
      expect(
        serviceStatusLabel(
          _request(
            status: 'awaiting_client_confirmation',
            providerProfileId: _me,
          ),
          _me,
        ),
        'A aguardar a confirmação do cliente',
      );
      expect(
        serviceStatusLabel(
          _request(
            status: 'awaiting_provider_confirmation',
            providerProfileId: _me,
          ),
          _me,
        ),
        'Aguarda a sua confirmação',
      );
      expect(
        serviceStatusLabel(
          _request(status: 'assigned', providerProfileId: _me),
          _me,
        ),
        'Confirmado',
      );
      expect(
        serviceStatusLabel(
          _request(status: 'in_progress', providerProfileId: _me),
          _me,
        ),
        'Em curso',
      );
      expect(
        serviceStatusLabel(
          _request(status: 'finished', providerProfileId: _me),
          _me,
        ),
        'Concluído',
      );
      expect(
        serviceStatusLabel(
          _request(status: 'cancelled', providerProfileId: _me),
          _me,
        ),
        'Cancelado',
      );
    });
  });

  group('servicePriceLabel', () {
    test('sem preço mostra "Preço por propor" em vez de 0,00 Kz', () {
      expect(
        servicePriceLabel(_request(candidateStatus: 'pending')),
        'Preço por propor',
      );
    });

    test('com preço proposto ou final mostra em Kz', () {
      expect(
        servicePriceLabel(
          _request(candidateStatus: 'accepted', candidateOfferedPrice: 18500),
        ),
        '18.500,00 Kz',
      );
      expect(
        servicePriceLabel(
          _request(
            status: 'finished',
            providerProfileId: _me,
            finalPrice: 15000,
          ),
        ),
        '15.000,00 Kz',
      );
    });
  });

  group('parseKzAmount', () {
    test('aceita formatos angolanos e simples', () {
      expect(parseKzAmount('15000'), 15000);
      expect(parseKzAmount('15.000'), 15000);
      expect(parseKzAmount('15.000,50'), 15000.5);
      expect(parseKzAmount('1.500,00 Kz'), 1500);
      expect(parseKzAmount(' 2500,5 '), 2500.5);
      expect(parseKzAmount('1.234.567'), 1234567);
    });

    test('rejeita vazio, zero, negativo, lixo e valores absurdos', () {
      expect(parseKzAmount(''), isNull);
      expect(parseKzAmount('0'), isNull);
      expect(parseKzAmount('-10'), isNull);
      expect(parseKzAmount('abc'), isNull);
      expect(parseKzAmount('12,3,4'), isNull);
      expect(parseKzAmount('99999999999'), isNull);
    });
  });

  group('ensureRowsAffected', () {
    test('lança erro visível quando o UPDATE afetou 0 linhas', () {
      expect(
        () => ensureRowsAffected(const [], 'Não foi possível atualizar'),
        throwsA(
          isA<ServiceActionException>().having(
            (e) => e.message,
            'message',
            'Não foi possível atualizar',
          ),
        ),
      );
    });

    test('não lança quando há linhas', () {
      expect(
        () => ensureRowsAffected([
          {'id': 'x'},
        ], 'erro'),
        returnsNormally,
      );
    });
  });

  group('ServiceRequestData.fromInviteRow', () {
    test('lê o pedido aninhado e os dados do convite', () {
      final r = ServiceRequestData.fromInviteRow({
        'service_request_id': 'req-9',
        'status': 'accepted',
        'offered_price': 15000,
        'service_requests': {
          'id': 'req-9',
          'description': 'Fuga de água',
          'service_date': '2026-11-05T12:00:00.000Z',
          'status': 'searching_provider',
          'is_paid': false,
          'created_at': '2026-11-05T10:00:00.000Z',
          'service_categories': {'name': 'Canalizador'},
        },
      });
      expect(r, isNotNull);
      expect(r!.id, 'req-9');
      expect(r.candidateStatus, 'accepted');
      expect(r.candidateOfferedPrice, 15000);
      expect(r.displayPrice, 15000);
    });

    test('devolve null se o pedido aninhado não estiver visível', () {
      expect(
        ServiceRequestData.fromInviteRow({
          'service_request_id': 'x',
          'status': 'pending',
          'service_requests': null,
        }),
        isNull,
      );
    });
  });
}
