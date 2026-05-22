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

class TripCompletedPanel extends StatefulWidget {
  final double price;
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final ValueChanged<String> onCommentChanged;
  final VoidCallback onReportProblem;
  final VoidCallback onFinish;

  const TripCompletedPanel({
    super.key,
    required this.price,
    required this.rating,
    required this.onRatingChanged,
    required this.onCommentChanged,
    required this.onReportProblem,
    required this.onFinish,
  });

  @override
  State<TripCompletedPanel> createState() => _TripCompletedPanelState();
}

class _TripCompletedPanelState extends State<TripCompletedPanel> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

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
          const Text(
            'Avalie o passageiro',
            style: TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => widget.onRatingChanged(i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < widget.rating ? Icons.star : Icons.star_border,
                    color: AppColors.highlight,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 3,
            onChanged: widget.onCommentChanged,
            decoration: InputDecoration(
              hintText: 'Observação sobre o passageiro (opcional)',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF7F7F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.highlight, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: widget.onReportProblem,
            icon: Icon(Icons.flag_outlined, color: Colors.red.shade400, size: 18),
            label: Text(
              'Relatar um problema',
              style: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.highlight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Finalizar',
                style: TextStyle(fontFamily: 'OutfitBlack', fontSize: 16),
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
  final VoidCallback onCall;

  const ArrivedAtClientPanel({
    super.key,
    required this.trip,
    required this.onStart,
    required this.onCall,
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
          Row(
            children: [
              if (trip.clientPhone != null && trip.clientPhone!.isNotEmpty) ...[
                SizedBox(
                  height: 52,
                  width: 52,
                  child: OutlinedButton(
                    onPressed: onCall,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2ECC71),
                      side: const BorderSide(color: Color(0xFF2ECC71), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.phone_outlined, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: SizedBox(
                  height: 52,
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
              ),
            ],
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
