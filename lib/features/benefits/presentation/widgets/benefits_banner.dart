import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';

/// Banner do clube de benefícios, desenhado em código com as cores da marca.
/// Substitui o banner raster antigo e é partilhado pela home e pelas
/// solicitações de serviço.
class BenefitsBanner extends StatelessWidget {
  final VoidCallback onTap;

  const BenefitsBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth / 3.19).clamp(88.0, 118.0);
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: height,
                width: double.infinity,
                color: AppColors.brandDark,
                child: Column(
                  children: [
                    const Expanded(child: _BannerContent()),
                    Container(
                      height: 4,
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.brandGradient,
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: AppColors.onHighlight,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clube de benefícios',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 18,
                    color: AppColors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Descontos exclusivos para parceiros',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'QuasimodoSemiBold',
                    fontSize: 12,
                    color: AppColors.highlightLight,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_rounded,
            color: AppColors.highlight,
            size: 22,
          ),
        ],
      ),
    );
  }
}
