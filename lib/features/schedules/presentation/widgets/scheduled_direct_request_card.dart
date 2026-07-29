import 'package:flutter/material.dart';

import '../dialogs/price_offer_dialog.dart';

class ScheduledDirectRequestCard extends StatelessWidget {
  const ScheduledDirectRequestCard({
    super.key,
    required this.tripId,
    required this.clientName,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.onAcceptWithPrice,
    required this.onReject,
  });

  final String tripId;
  final String clientName;
  final String pickupAddress;
  final String dropoffAddress;
  final Future<void> Function(double price) onAcceptWithPrice;
  final Future<void> Function() onReject;

  Future<void> _openPriceDialog(BuildContext context) async {
    final price = await showDialog<double>(
      context: context,
      builder: (_) => const PriceOfferDialog(),
    );
    if (price != null) {
      await onAcceptWithPrice(price);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Chip(
              label: Text('📅 AGENDAMENTO — NOVA'),
              backgroundColor: Color(0xFFFEF3C7),
            ),
            const SizedBox(height: 8),
            Text('Cliente: $clientName',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('De: $pickupAddress'),
            Text('Para: $dropoffAddress'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => onReject(),
                  child: const Text('Recusar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _openPriceDialog(context),
                  child: const Text('Aceitar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
