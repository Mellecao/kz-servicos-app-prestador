import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/models/provider_profile_data.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/provider_service.dart';
import 'package:kz_servicos_prestador/core/services/trip_service.dart';
import 'package:kz_servicos_prestador/core/widgets/service_provider_bottom_nav.dart';
import 'package:kz_servicos_prestador/features/earnings/presentation/widgets/earnings_chart_card.dart';
import 'package:kz_servicos_prestador/core/utils/kz_format.dart';

class ProviderEarningsPage extends StatefulWidget {
  final ValueChanged<int> onNavTap;

  const ProviderEarningsPage({super.key, required this.onNavTap});

  @override
  State<ProviderEarningsPage> createState() => _ProviderEarningsPageState();
}

class _ProviderEarningsPageState extends State<ProviderEarningsPage> {
  final _providerService = ProviderService();

  EarningsData? _earnings;
  ProviderProfileData? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final providerId = AuthState.providerProfileId ?? '';
    final userId = AuthState.userId ?? '';
    final results = await Future.wait([
      _providerService.getProviderEarnings(providerId),
      _providerService.getProviderProfile(userId),
    ]);
    if (!mounted) return;
    setState(() {
      _earnings = results[0] as EarningsData;
      _profile = results[1] as ProviderProfileData?;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: ServiceProviderBottomNav(
          selectedIndex: 1,
          onItemSelected: widget.onNavTap,
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Carteira',
                        style: TextStyle(
                          fontFamily: 'OutfitBlack',
                          fontSize: 24,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _BalanceCard(earnings: _earnings!),
                      const SizedBox(height: 16),
                      _TotalReceivedCard(earnings: _earnings!),
                      const SizedBox(height: 16),
                      EarningsChartCard(
                        monthlyHistory: _earnings!.monthlyHistory,
                        monthOverMonthDiff:
                            _earnings!.currentMonthTotal -
                            _earnings!.previousMonthTotal,
                      ),
                      if (_profile != null) ...[
                        const SizedBox(height: 16),
                        _BankInfoCard(profile: _profile!),
                      ],
                      const SizedBox(height: 20),
                      _StatementSection(entries: _earnings!.recentEntries),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final EarningsData earnings;

  const _BalanceCard({required this.earnings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2261FE), Color(0xFF1A4BC9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Valor a receber',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            formatKz(earnings.availableBalance),
            style: const TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 32,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalReceivedCard extends StatelessWidget {
  final EarningsData earnings;

  const _TotalReceivedCard({required this.earnings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total recebido',
            style: TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatKz(earnings.totalReceived),
            style: const TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 28,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${earnings.totalTrips} serviços no total',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BankInfoCard extends StatelessWidget {
  final ProviderProfileData profile;

  const _BankInfoCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final bank = profile.bankName ?? '-';
    final agency = profile.bankAgency ?? '-';
    final account = profile.bankAccount ?? '-';
    final pix = profile.pixKey ?? '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Dados bancários',
                style: TextStyle(
                  fontFamily: 'OutfitBlack',
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Editar',
                  style: TextStyle(color: AppColors.secondary, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$bank · Ag $agency · Cc $account',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'IBAN: $pix',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatementSection extends StatelessWidget {
  final List<EarningEntry> entries;

  const _StatementSection({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Extrato',
          style: TextStyle(
            fontFamily: 'OutfitBlack',
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Nenhuma transação encontrada',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
          )
        else
          ...entries.map((e) => _EntryTile(entry: e)),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  final EarningEntry entry;

  const _EntryTile({required this.entry});

  IconData get _icon => switch (entry.type) {
    EarningType.trip => Icons.handyman_rounded,
    EarningType.bonus => Icons.star,
    EarningType.withdrawal => Icons.arrow_downward,
  };

  Color get _color => switch (entry.type) {
    EarningType.trip => const Color(0xFF2ECC71),
    EarningType.bonus => AppColors.highlight,
    EarningType.withdrawal => Colors.red,
  };

  @override
  Widget build(BuildContext context) {
    final isNegative = entry.type == EarningType.withdrawal;
    final statusColor = entry.isPaid
        ? const Color(0xFF2ECC71)
        : Colors.orange.shade600;
    final statusLabel = entry.isPaid ? 'Pago' : 'Não pago';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: _color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: const TextStyle(
                    fontFamily: 'QuasimodoSemiBold',
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${entry.date.day.toString().padLeft(2, '0')}/${entry.date.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontFamily: 'QuasimodoSemiBold',
                          fontSize: 10,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isNegative ? '-' : '+'}${formatKz(entry.amount)}',
            style: TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 15,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
