import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kz_servicos_prestador/core/constants/app_brand.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';

class TripRequestCard extends StatefulWidget {
  final TripData request;
  final void Function(double? price) onAccept;
  final VoidCallback onReject;
  final VoidCallback onShowDetails;
  final ValueChanged<bool>? onPriceFieldFocusChanged;
  final bool reduceEffects;
  final bool compact;
  final bool showDetailsButton;

  const TripRequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onReject,
    required this.onShowDetails,
    this.onPriceFieldFocusChanged,
    this.reduceEffects = false,
    this.compact = false,
    this.showDetailsButton = true,
  });

  @override
  State<TripRequestCard> createState() => _TripRequestCardState();
}

class _TripRequestCardState extends State<TripRequestCard>
    with SingleTickerProviderStateMixin {
  final _priceController = TextEditingController();
  final _priceFocusNode = FocusNode();
  bool _showError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _syncKzPrice();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
    _priceFocusNode.addListener(_notifyPriceFieldFocus);
  }

  void _notifyPriceFieldFocus() {
    widget.onPriceFieldFocusChanged?.call(_priceFocusNode.hasFocus);
  }

  @override
  void didUpdateWidget(covariant TripRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.kzProposedPrice != widget.request.kzProposedPrice ||
        oldWidget.request.kzProposalLocked != widget.request.kzProposalLocked) {
      _syncKzPrice();
    }
  }

  void _syncKzPrice() {
    final kzPrice = widget.request.kzProposedPrice;
    if (widget.request.kzProposalLocked && kzPrice != null) {
      _priceController.text = kzPrice.toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  @override
  void dispose() {
    _priceFocusNode.removeListener(_notifyPriceFieldFocus);
    widget.onPriceFieldFocusChanged?.call(false);
    _priceFocusNode.dispose();
    _priceController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _handleAccept() {
    if (widget.request.isDriverRecheck) {
      widget.onAccept(null);
      return;
    }

    if (widget.request.kzProposalLocked &&
        widget.request.kzProposedPrice != null) {
      widget.onAccept(widget.request.kzProposedPrice);
      return;
    }

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
    final isCompact = widget.compact;
    final hasRejectedPrice =
        widget.request.priceRejectionReason != null &&
        widget.request.priceRejectionReason!.isNotEmpty;
    final hasKzProposal =
        widget.request.kzProposalLocked &&
        widget.request.kzProposedPrice != null;
    final inputBorderColor = hasKzProposal
        ? const Color(0xFF16A34A)
        : hasRejectedPrice || _showError
        ? Colors.red.shade400
        : Colors.grey.shade200;

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
        boxShadow: widget.reduceEffects
            ? null
            : [
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
                radius: isCompact ? 18 : 20,
                backgroundColor: AppColors.highlight.withValues(alpha: 0.15),
                backgroundImage:
                    widget.request.clientAvatarUrl != null &&
                        widget.request.clientAvatarUrl!.isNotEmpty
                    ? NetworkImage(widget.request.clientAvatarUrl!)
                    : null,
                child:
                    widget.request.clientAvatarUrl == null ||
                        widget.request.clientAvatarUrl!.isEmpty
                    ? Text(
                        widget.request.clientName.isNotEmpty
                            ? widget.request.clientName[0]
                            : '?',
                        style: const TextStyle(
                          fontFamily: 'OutfitBlack',
                          fontSize: 17,
                          color: AppColors.highlight,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.request.clientName,
                  style: TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: isCompact ? 15 : 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 12 : 16),

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

          SizedBox(height: isCompact ? 10 : 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isCompact ? 10 : 12),
            decoration: BoxDecoration(
              color: AppColors.highlight.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
              border: Border.all(
                color: AppColors.highlight.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  widget.request.isRoundTrip
                      ? Icons.sync_alt_rounded
                      : Icons.schedule_rounded,
                  size: isCompact ? 16 : 18,
                  color: AppColors.highlight,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatTripScheduleSummary(widget.request),
                    style: TextStyle(
                      fontFamily: 'QuasimodoSemiBold',
                      fontSize: isCompact ? 12 : 13,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Extra info chips
          if (widget.request.hasChildren || widget.request.hasLuggage) ...[
            SizedBox(height: isCompact ? 10 : 12),
            Wrap(
              spacing: 8,
              children: [
                if (widget.request.hasChildren)
                  _InfoChip(
                    icon: Icons.child_care,
                    label: '${widget.request.displayChildrenCount} criança(s)',
                  ),
                if (widget.request.hasLuggage)
                  _InfoChip(icon: Icons.luggage, label: 'Com mala'),
              ],
            ),
          ],

          if (widget.request.passengerLabels.isNotEmpty) ...[
            SizedBox(height: isCompact ? 8 : 10),
            _DetailList(
              icon: Icons.people_outline_rounded,
              title: 'Passageiros',
              entries: widget.request.passengerLabels,
            ),
          ],
          if (widget.request.childLabels.isNotEmpty) ...[
            SizedBox(height: isCompact ? 8 : 10),
            _DetailList(
              icon: Icons.warning_amber_rounded,
              title: 'Crianças',
              entries: widget.request.childLabels,
              warning: true,
            ),
          ],
          if (widget.request.luggageLabels.isNotEmpty) ...[
            SizedBox(height: isCompact ? 8 : 10),
            _DetailList(
              icon: Icons.luggage_outlined,
              title: 'Bagagem',
              entries: widget.request.luggageLabels,
            ),
          ],

          SizedBox(height: isCompact ? 12 : 16),

          if (widget.showDetailsButton)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onShowDetails,
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text(
                  'Mostrar detalhes',
                  style: TextStyle(fontFamily: 'OutfitBlack', fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(
                    color: AppColors.highlight.withValues(alpha: 0.7),
                  ),
                  padding: EdgeInsets.symmetric(vertical: isCompact ? 10 : 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          if (widget.showDetailsButton) SizedBox(height: isCompact ? 12 : 16),

          if (widget.request.isDriverRecheck) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF97316).withValues(alpha: 0.25),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 18,
                    color: Color(0xFFF97316),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'O passageiro confirmou a viagem. Verifique os detalhes e confirme se ainda pretende manter o agendamento.',
                      style: TextStyle(
                        fontFamily: 'QuasimodoSemiBold',
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Price input with shake animation
          if (!widget.request.isDriverRecheck) ...[
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
                    'O seu valor para esta viagem:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('price_input'),
                    controller: _priceController,
                    focusNode: _priceFocusNode,
                    enabled: !hasKzProposal,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                      fillColor: hasKzProposal
                          ? Colors.grey.shade200
                          : Colors.grey.shade50,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: inputBorderColor,
                          width: hasKzProposal || hasRejectedPrice || _showError
                              ? 1.5
                              : 1,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF16A34A),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: inputBorderColor == Colors.grey.shade200
                              ? AppColors.highlight
                              : inputBorderColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  if (hasRejectedPrice) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.request.priceRejectionReason!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (hasKzProposal) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'proposta feita pela ${AppBrand.name}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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
          ],

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
                    'Recusar',
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
                  child: Text(
                    widget.request.isDriverRecheck
                        ? 'Confirmar agendamento'
                        : 'Aceitar solicitação',
                    style: const TextStyle(
                      fontFamily: 'OutfitBlack',
                      fontSize: 14,
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

String _formatShortDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month às $hour:$minute';
}

String _formatTripScheduleSummary(TripData request) {
  final departure = 'Partida ${_formatShortDateTime(request.scheduledAt)}';
  if (!request.isRoundTrip) return departure;
  final returnAt = request.returnAt;
  if (returnAt == null) return '$departure • ida e volta';
  return '$departure • Retorno ${_formatShortDateTime(returnAt)}';
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
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
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

class _DetailList extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> entries;
  final bool warning;

  const _DetailList({
    required this.icon,
    required this.title,
    required this.entries,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFFB45309) : AppColors.textSecondary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFFFF7ED) : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: warning ? Border.all(color: AppColors.highlight) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'QuasimodoSemiBold',
                    fontSize: 12,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                ...entries.map(
                  (entry) => Text(
                    entry,
                    style: TextStyle(fontSize: 12, color: color, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
