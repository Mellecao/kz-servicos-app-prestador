import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/features/benefits/data/models/benefit_discount_code.dart';
import 'package:kz_servicos_prestador/features/benefits/data/models/benefit_partner.dart';
import 'package:kz_servicos_prestador/features/benefits/data/services/benefits_service.dart';
import 'package:url_launcher/url_launcher.dart';

class BenefitsPage extends StatefulWidget {
  const BenefitsPage({super.key});

  @override
  State<BenefitsPage> createState() => _BenefitsPageState();
}

class _BenefitsPageState extends State<BenefitsPage> {
  final _service = BenefitsService();
  late Future<List<BenefitPartner>> _partnersFuture;

  @override
  void initState() {
    super.initState();
    _partnersFuture = _service.getActivePartners();
  }

  Future<void> _refresh() async {
    setState(() {
      _partnersFuture = _service.getActivePartners();
    });
    await _partnersFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Clube de benefícios',
          style: TextStyle(fontFamily: 'OutfitBlack', fontSize: 20),
        ),
      ),
      body: FutureBuilder<List<BenefitPartner>>(
        future: _partnersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final partners = snapshot.data ?? const <BenefitPartner>[];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 700;
                final horizontalPadding = isTablet ? 40.0 : 24.0;
                final crossAxisCount = isTablet ? 2 : 1;
                return GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    MediaQuery.of(context).padding.bottom + 24,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 178,
                  ),
                  itemCount: partners.length,
                  itemBuilder: (context, index) => _BenefitCard(
                    partner: partners[index],
                    onTap: () => _showBenefitDetails(context, partners[index]),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showBenefitDetails(BuildContext context, BenefitPartner partner) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BenefitDetailsSheet(partner: partner, service: _service),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final BenefitPartner partner;
  final VoidCallback onTap;

  const _BenefitCard({required this.partner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.highlight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_offer_rounded,
                      color: AppColors.highlight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner.merchantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'OutfitBlack',
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          partner.serviceOffered,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'QuasimodoSemiBold',
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'R\$ ${partner.discountedPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'OutfitBlack',
                        fontSize: 18,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '-${partner.discountPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontFamily: 'OutfitBlack',
                        fontSize: 12,
                        color: Color(0xFF2ECC71),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      partner.merchantAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitDetailsSheet extends StatefulWidget {
  final BenefitPartner partner;
  final BenefitsService service;

  const _BenefitDetailsSheet({required this.partner, required this.service});

  @override
  State<_BenefitDetailsSheet> createState() => _BenefitDetailsSheetState();
}

class _BenefitDetailsSheetState extends State<_BenefitDetailsSheet> {
  String? _discountCode;
  bool _generating = false;

  Future<void> _generateCode() async {
    setState(() => _generating = true);
    final driverProfileId = AuthState.driverProfileId;
    final backendCode = driverProfileId == null
        ? null
        : await widget.service.generateDiscountCode(
            benefitPartnerId: widget.partner.id,
            driverProfileId: driverProfileId,
          );
    if (!mounted) return;
    setState(() {
      _discountCode =
          backendCode?.code ?? BenefitDiscountCode.buildRandomCode();
      _generating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final partner = widget.partner;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              partner.merchantName,
              style: const TextStyle(
                fontFamily: 'OutfitBlack',
                fontSize: 22,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              partner.serviceOffered,
              style: const TextStyle(
                fontFamily: 'QuasimodoSemiBold',
                fontSize: 15,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              partner.serviceDescription.isEmpty
                  ? 'Benefício exclusivo para parceiros KZ.'
                  : partner.serviceDescription,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 18),
            _DetailRow(
              icon: Icons.sell_outlined,
              label:
                  'De R\$ ${partner.originalPrice.toStringAsFixed(2)} por R\$ ${partner.discountedPrice.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: partner.merchantAddress,
            ),
            if (partner.merchantPhone.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.phone_outlined,
                label: partner.merchantPhone,
                onTap: () => launchUrl(
                  Uri.parse(
                    'tel:${partner.merchantPhone.replaceAll(RegExp(r'[^0-9+]'), '')}',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_discountCode != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.highlight.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _discountCode!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 20,
                    letterSpacing: 1,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _generating ? null : _generateCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.highlight,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _generating ? 'Gerando...' : 'Gerar meu código promocional',
                  style: const TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _DetailRow({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'QuasimodoSemiBold',
                fontSize: 14,
                color: onTap == null
                    ? AppColors.textPrimary
                    : AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
