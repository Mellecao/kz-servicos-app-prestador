import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';

class ActiveTripNavigationDrawer extends StatelessWidget {
  final String clientName;
  final String destinationAddress;
  final ValueChanged<String> onSelectRoute;

  const ActiveTripNavigationDrawer({
    super.key,
    required this.clientName,
    required this.destinationAddress,
    required this.onSelectRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.highlight.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.route_rounded,
                      color: AppColors.highlight,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Corrida em andamento',
                    style: TextStyle(
                      fontFamily: 'OutfitBlack',
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$clientName • $destinationAddress',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.calendar_month_outlined,
              label: 'Agendamentos',
              route: '/schedules',
              onSelectRoute: onSelectRoute,
            ),
            _DrawerItem(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Carteira',
              route: '/earnings',
              onSelectRoute: onSelectRoute,
            ),
            _DrawerItem(
              icon: Icons.person_outline,
              label: 'Perfil',
              route: '/profile',
              onSelectRoute: onSelectRoute,
            ),
            _DrawerItem(
              icon: Icons.chat_bubble_outline,
              label: 'Mensagens',
              route: '/messages',
              onSelectRoute: onSelectRoute,
            ),
            _DrawerItem(
              icon: Icons.history_outlined,
              label: 'Histórico de corridas',
              route: '/trip-history',
              onSelectRoute: onSelectRoute,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.directions_car_outlined, size: 18),
                  label: const Text('Voltar para corrida'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final ValueChanged<String> onSelectRoute;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.onSelectRoute,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minLeadingWidth: 24,
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      onTap: () => onSelectRoute(route),
    );
  }
}
