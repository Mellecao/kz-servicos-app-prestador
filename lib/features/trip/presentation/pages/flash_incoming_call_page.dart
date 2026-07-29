import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/flash_trip_service.dart';
import '../widgets/flash_price_input.dart';

class FlashIncomingCallPage extends StatefulWidget {
  final String tripId;
  final FlashTripService service;
  const FlashIncomingCallPage({
    super.key,
    required this.tripId,
    required this.service,
  });

  @override
  State<FlashIncomingCallPage> createState() => _FlashIncomingCallPageState();
}

class _FlashIncomingCallPageState extends State<FlashIncomingCallPage> {
  Map<String, dynamic>? trip;
  String? error;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    widget.service
        .loadIncomingCall(widget.tripId)
        .then((t) {
          if (mounted) setState(() => trip = t);
        })
        .catchError((e) {
          if (mounted) setState(() => error = e.toString());
        });
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(body: Center(child: Text(error!)));
    }
    if (trip == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pickup = (trip!['pickup'] as Map?) ?? const {};
    final dropoff = (trip!['dropoff'] as Map?) ?? const {};
    final client = (trip!['client'] as Map?) ?? const {};
    final obs = trip!['observations'] as String?;

    return Scaffold(
      appBar: AppBar(title: const Text('⚡ Corrida Flash')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Cliente: ${client['name'] ?? client['full_name'] ?? 'Cliente'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text('Origem: ${_formatAddress(pickup)}'),
          Text('Destino: ${_formatAddress(dropoff)}'),
          const SizedBox(height: 12),
          Text('Passageiros: ${trip!['passenger_count'] ?? 1}'),
          Text('Bagagens: ${trip!['luggage_count'] ?? 0}'),
          Text('Crianças: ${trip!['children_count'] ?? 0}'),
          if (obs != null && obs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Obs: $obs'),
          ],
          const SizedBox(height: 24),
          FlashPriceInput(
            onSubmit: (price) => _handleSubmit(price),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: submitting ? null : _handleReject,
            child: const Text('Recusar chamada'),
          ),
        ],
      ),
    );
  }

  String _formatAddress(Map addr) {
    final formatted = addr['formatted_address'] as String?;
    if (formatted != null && formatted.isNotEmpty) return formatted;
    final street = addr['street'] as String?;
    final city = addr['city'] as String?;
    return [street, city].where((p) => p != null && p.isNotEmpty).join(', ');
  }

  Future<void> _handleSubmit(double price) async {
    if (submitting) return;
    setState(() => submitting = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.sendProposal(widget.tripId, price);
      if (mounted) router.go('/flash/awaiting/${widget.tripId}');
    } catch (e) {
      if (mounted) {
        setState(() => submitting = false);
        messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _handleReject() async {
    setState(() => submitting = true);
    final router = GoRouter.of(context);
    try {
      await widget.service.rejectCall(widget.tripId);
      if (mounted) router.go('/home');
    } catch (_) {
      if (mounted) setState(() => submitting = false);
    }
  }
}
