import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';

class ServiceProviderBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const ServiceProviderBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  static const _items = [
    (icon: Icons.handyman_rounded, label: 'Serviços'),
    (icon: Icons.account_balance_wallet_rounded, label: 'Carteira'),
    (icon: Icons.card_giftcard_rounded, label: 'Benefícios'),
    (icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
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
        children: List.generate(_items.length, (i) {
          return Expanded(
            child: _NavItem(
              icon: _items[i].icon,
              label: _items[i].label,
              isSelected: selectedIndex == i,
              onTap: () => onItemSelected(i),
            ),
          );
        }),
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
                      color:
                          AppColors.highlight.withValues(alpha: 0.40),
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
    );
  }
}
