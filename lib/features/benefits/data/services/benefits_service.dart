import 'package:flutter/foundation.dart';
import 'package:kz_servicos_prestador/features/benefits/data/models/benefit_discount_code.dart';
import 'package:kz_servicos_prestador/features/benefits/data/models/benefit_partner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BenefitsService {
  final SupabaseClient _client;

  BenefitsService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<List<BenefitPartner>> getActivePartners() async {
    try {
      final res = await _client
          .from('benefit_partners')
          .select()
          .eq('is_active', true)
          .order('merchant_name');
      final partners = (res as List)
          .map((row) => BenefitPartner.fromMap(row as Map<String, dynamic>))
          .toList();
      return partners.isEmpty ? mockPartners : partners;
    } catch (e) {
      debugPrint('[BenefitsService] getActivePartners erro: $e');
      return mockPartners;
    }
  }

  Future<BenefitDiscountCode?> generateDiscountCode({
    required String benefitPartnerId,
    required String driverProfileId,
  }) async {
    try {
      final res = await _client
          .rpc(
            'generate_benefit_discount_code',
            params: {
              'p_benefit_partner_id': benefitPartnerId,
              'p_driver_profile_id': driverProfileId,
            },
          )
          .single();
      return BenefitDiscountCode.fromMap(res);
    } catch (e) {
      debugPrint('[BenefitsService] generateDiscountCode erro: $e');
      return null;
    }
  }

  static const mockPartners = [
    BenefitPartner(
      id: 'mock-auto-center',
      merchantName: 'Auto Center KZ',
      merchantAddress: 'Av. Brasil, 1200 - Centro',
      merchantPhone: '(11) 4002-0101',
      serviceOffered: 'Troca de óleo completa',
      serviceDescription:
          'Troca de óleo com filtro, revisão visual de fluidos e calibragem dos pneus para parceiros KZ.',
      discountPercent: 20,
      originalPrice: 180,
      isActive: true,
    ),
    BenefitPartner(
      id: 'mock-lava-rapido',
      merchantName: 'Lava Rápido Prime',
      merchantAddress: 'Rua das Palmeiras, 88 - Vila Nova',
      merchantPhone: '(11) 98888-1212',
      serviceOffered: 'Lavagem completa',
      serviceDescription:
          'Lavagem externa, aspiração interna, pretinho nos pneus e higienização simples do painel.',
      discountPercent: 15,
      originalPrice: 90,
      isActive: true,
    ),
    BenefitPartner(
      id: 'mock-pneus',
      merchantName: 'Pneus & Alinhamento Norte',
      merchantAddress: 'Av. do Contorno, 455 - Jardim Norte',
      merchantPhone: '(11) 3555-7890',
      serviceOffered: 'Alinhamento e balanceamento',
      serviceDescription:
          'Pacote com alinhamento dianteiro, balanceamento das quatro rodas e checagem de suspensão.',
      discountPercent: 18,
      originalPrice: 160,
      isActive: true,
    ),
  ];
}
