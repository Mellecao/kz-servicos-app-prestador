import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';

class ProviderBottomNav extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final int? scheduleBadgeCount;

  const ProviderBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.scheduleBadgeCount,
  });

  static const _items = [
    (icon: Icons.home_rounded, label: 'Início'),
    (icon: Icons.calendar_month_rounded, label: 'Agenda'),
    (icon: Icons.account_balance_wallet_rounded, label: 'Ganhos'),
    (icon: Icons.person_rounded, label: 'Perfil'),
    (icon: Icons.support_agent_rounded, label: 'Suporte'),
  ];

  @override
  State<ProviderBottomNav> createState() => _ProviderBottomNavState();
}

class _ProviderBottomNavState extends State<ProviderBottomNav> {
  @override
  void initState() {
    super.initState();
    AuthState.scheduledTrips?.addListener(_onScheduledTripsChanged);
  }

  void _onScheduledTripsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AuthState.scheduledTrips?.removeListener(_onScheduledTripsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheduleBadgeCount =
        widget.scheduleBadgeCount ??
        AuthState.scheduledTrips?.trips.length ??
        0;

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
        children: List.generate(ProviderBottomNav._items.length, (i) {
          return Expanded(
            child: _NavItem(
              icon: ProviderBottomNav._items[i].icon,
              label: ProviderBottomNav._items[i].label,
              isSelected: widget.selectedIndex == i,
              badgeCount: i == 1 ? scheduleBadgeCount : 0,
              onTap: () => widget.onItemSelected(i),
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
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
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
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
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
                  if (badgeCount > 0)
                    Positioned(
                      top: -6,
                      right: -8,
                      child: _NavBadge(count: badgeCount),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBadge extends StatelessWidget {
  final int count;

  const _NavBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.red.shade500,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
