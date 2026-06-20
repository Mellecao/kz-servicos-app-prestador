import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';

void showExternalNavSheet(BuildContext context, LatLng target) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Abrir rota',
            style: TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Escolha o app de navegação',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _ExternalNavOption(
                  icon: Icons.navigation_rounded,
                  label: 'Waze',
                  color: const Color(0xFF33CCFF),
                  onTap: () {
                    Navigator.pop(ctx);
                    launchUrl(
                      Uri.parse(
                        'https://waze.com/ul?ll=${target.latitude},${target.longitude}&navigate=yes',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _ExternalNavOption(
                  icon: Icons.map_rounded,
                  label: 'Google Maps',
                  color: AppColors.secondary,
                  onTap: () {
                    Navigator.pop(ctx);
                    launchUrl(
                      Uri.parse(
                        'google.navigation:q=${target.latitude},${target.longitude}',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

class _ExternalNavOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ExternalNavOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: const TextStyle(fontFamily: 'OutfitBlack', fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      ),
    );
  }
}
