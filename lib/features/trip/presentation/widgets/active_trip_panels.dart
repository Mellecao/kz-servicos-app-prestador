import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/widgets/circle_button.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/active_trip_data.dart';

class ActiveTripPanel extends StatelessWidget {
  final String clientName;
  final String subtitle;
  final Color phaseColor;
  final String buttonLabel;
  final VoidCallback onAdvance;
  final VoidCallback onChat;
  final VoidCallback onCall;

  const ActiveTripPanel({
    super.key,
    required this.clientName,
    required this.subtitle,
    required this.phaseColor,
    required this.buttonLabel,
    required this.onAdvance,
    required this.onChat,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.highlight.withValues(alpha: 0.15),
                child: Text(
                  clientName[0],
                  style: const TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 20,
                    color: AppColors.highlight,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: const TextStyle(
                        fontFamily: 'OutfitBlack',
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              CircleButton(icon: Icons.chat_outlined, onTap: onChat),
              const SizedBox(width: 8),
              CircleButton(icon: Icons.phone_outlined, onTap: onCall),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAdvance,
              style: ElevatedButton.styleFrom(
                backgroundColor: phaseColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(
                  fontFamily: 'OutfitBlack',
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TripCompletedPanel extends StatelessWidget {
  final double price;
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onFinish;

  const TripCompletedPanel({
    super.key,
    required this.price,
    required this.rating,
    required this.onRatingChanged,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding + 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF2ECC71),
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Viagem finalizada!',
            style: TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Valor: R\$ ${price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 24,
              color: Color(0xFF2ECC71),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Avalie o passageiro',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => onRatingChanged(i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    color: AppColors.highlight,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.highlight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Voltar ao início',
                style: TextStyle(
                  fontFamily: 'OutfitBlack',
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ArrivedAtClientPanel extends StatelessWidget {
  final ActiveTripData trip;
  final VoidCallback onStart;

  const ArrivedAtClientPanel({
    super.key,
    required this.trip,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding + 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_rounded,
            color: AppColors.highlight,
            size: 40,
          ),
          const SizedBox(height: 8),
          const Text(
            'Você chegou ao local de embarque',
            style: TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _ArrivedDetailRow(icon: Icons.person_outline, label: trip.clientName),
          const SizedBox(height: 6),
          _ArrivedDetailRow(icon: Icons.flag_outlined, label: trip.destinationAddress),
          const SizedBox(height: 6),
          _ArrivedDetailRow(
            icon: Icons.people_outline,
            label: '${trip.passengerCount} passageiro(s)',
          ),
          const SizedBox(height: 6),
          _ArrivedDetailRow(
            icon: Icons.attach_money,
            label: 'R\$ ${trip.offeredPrice.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Iniciar corrida',
                style: TextStyle(fontFamily: 'OutfitBlack', fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentCollectionPanel extends StatelessWidget {
  final double price;
  final String clientName;
  final String paymentMethodLabel;
  final VoidCallback onConfirm;

  const PaymentCollectionPanel({
    super.key,
    required this.price,
    required this.clientName,
    required this.paymentMethodLabel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding + 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF2ECC71),
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Viagem finalizada!',
            style: TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Cobre',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          Text(
            'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}',
            style: const TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 28,
              color: Color(0xFF2ECC71),
            ),
          ),
          Text(
            'de $clientName',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          Text(
            'pelo $paymentMethodLabel',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Pagamento efetuado',
                style: TextStyle(fontFamily: 'OutfitBlack', fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrivedDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ArrivedDetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
