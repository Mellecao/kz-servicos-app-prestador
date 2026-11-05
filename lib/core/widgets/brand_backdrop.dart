import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';

/// Fundo da marca "Só Serviços": base escura com brilhos rosa e laranja,
/// desenhado em código (sem imagens raster). Usado no splash e no login.
class BrandBackdrop extends StatelessWidget {
  final Widget child;

  const BrandBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.brandDark,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _Glow(
            center: Alignment(-1.0, -0.9),
            color: AppColors.brandPink,
          ),
          const _Glow(center: Alignment(1.0, 0.95), color: AppColors.highlight),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Alignment center;
  final Color color;

  const _Glow({required this.center, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: 1.0,
          colors: [color.withValues(alpha: 0.30), Colors.transparent],
        ),
      ),
    );
  }
}
