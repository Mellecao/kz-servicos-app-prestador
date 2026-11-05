import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/constants/feature_flags.dart';

class ServiceProviderBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  /// Mostra a aba do Clube de benefícios (ver [FeatureFlags]).
  final bool showBenefits;

  const ServiceProviderBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.showBenefits = FeatureFlags.benefitsClubEnabled,
  });

  // O índice é o do router (`_handleProviderNavTap`), por isso não muda
  // quando uma aba é escondida.
  static const _items = [
    (index: 0, icon: Icons.handyman_rounded, label: 'Serviços'),
    (index: 1, icon: Icons.account_balance_wallet_rounded, label: 'Carteira'),
    (index: 2, icon: Icons.card_giftcard_rounded, label: 'Benefícios'),
    (index: 3, icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final visible = _items
        .where((item) => showBenefits || item.index != 2)
        .toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          for (final item in visible)
            Expanded(
              child: _NavItem(
                icon: item.icon,
                label: item.label,
                isSelected: selectedIndex == item.index,
                onTap: () => onItemSelected(item.index),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // Altura fixa: sem ela o Center expande até à altura máxima que o
      // Scaffold oferece e a barra passa a ocupar o ecrã todo.
      child: SizedBox(
        height: 56,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            width: isSelected ? 56 : 44,
            height: isSelected ? 56 : 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? AppColors.highlight.withValues(alpha: 0.85)
                  : Colors.transparent,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.highlight.withValues(alpha: 0.40),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: AnimatedScale(
                scale: isSelected ? 1.15 : 0.9,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.black45,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
