import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/flash_trip_service.dart';

class FlashRecheckPage extends StatefulWidget {
  final String tripId;
  final FlashTripService service;
  const FlashRecheckPage({
    super.key,
    required this.tripId,
    required this.service,
  });

  @override
  State<FlashRecheckPage> createState() => _FlashRecheckPageState();
}

class _FlashRecheckPageState extends State<FlashRecheckPage> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.recheckConfirm(widget.tripId);
      if (mounted) router.go('/home?activeTripId=${widget.tripId}');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _reject() async {
    if (_busy) return;
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.recheckReject(widget.tripId);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Você desistiu desta corrida')),
        );
        router.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cliente aceitou sua proposta!')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Deseja iniciar a corrida?',
              style: TextStyle(fontSize: 20),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _busy ? null : _confirm,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Iniciar corrida'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _reject,
              child: const Text('Desistir'),
            ),
          ],
        ),
      ),
    );
  }
}
