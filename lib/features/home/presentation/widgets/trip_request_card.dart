import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';

class TripRequestCard extends StatefulWidget {
  final TripData request;
  final void Function(double price) onAccept;
  final VoidCallback onReject;

  const TripRequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<TripRequestCard> createState() => _TripRequestCardState();
}

class _TripRequestCardState extends State<TripRequestCard>
    with SingleTickerProviderStateMixin {
  final _priceController = TextEditingController();
  bool _showError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _handleAccept() {
    final text = _priceController.text.trim().replaceAll(',', '.');
    final price = double.tryParse(text);
    if (price == null || price <= 0) {
      setState(() => _showError = true);
      _shakeController.forward(from: 0);
      return;
    }
    setState(() => _showError = false);
    widget.onAccept(price);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: client name
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.highlight.withValues(alpha: 0.15),
                child: Text(
                  widget.request.clientName[0],
                  style: const TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 18,
                    color: AppColors.highlight,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.request.clientName,
                  style: const TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Route
          _RoutePoint(color: AppColors.highlight, label: widget.request.origin),
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: Container(width: 2, height: 20, color: Colors.grey.shade300),
          ),
          _RoutePoint(
            color: AppColors.highlight,
            label: widget.request.destination,
            isCircle: true,
          ),

          // Extra info chips
          if (widget.request.hasChildren || widget.request.hasLuggage) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (widget.request.hasChildren)
                  _InfoChip(
                    icon: Icons.child_care,
                    label: '${widget.request.childrenCount} criança(s)',
                  ),
                if (widget.request.hasLuggage)
                  _InfoChip(icon: Icons.luggage, label: 'Com mala'),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Price input with shake animation
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (_, child) {
              final offset = _shakeController.isAnimating
                  ? math.sin(_shakeAnimation.value * math.pi * 6) * 6
                  : 0.0;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seu valor para esta corrida:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('price_input'),
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: (_) {
                    if (_showError) setState(() => _showError = false);
                  },
                  decoration: InputDecoration(
                    prefixText: 'R\$  ',
                    hintText: '0,00',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _showError
                            ? Colors.red.shade400
                            : Colors.grey.shade200,
                        width: _showError ? 1.5 : 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _showError
                            ? Colors.red.shade400
                            : AppColors.highlight,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                if (_showError) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Informe um valor antes de aceitar',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade400,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    side: BorderSide(color: Colors.red.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Recusar solicitação',
                    style: TextStyle(fontFamily: 'OutfitBlack', fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _handleAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Aceitar solicitação',
                    style: TextStyle(fontFamily: 'OutfitBlack', fontSize: 14),
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

class _RoutePoint extends StatelessWidget {
  final Color color;
  final String label;
  final bool isCircle;

  const _RoutePoint({
    required this.color,
    required this.label,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCircle ? color : color.withValues(alpha: 0.2),
            border: isCircle ? null : Border.all(color: color, width: 2),
          ),
          child: isCircle
              ? Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
