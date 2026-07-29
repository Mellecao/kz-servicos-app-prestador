import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/flash_trip_service.dart';

class FlashAwaitingClientPage extends StatefulWidget {
  final String tripId;
  final FlashTripService service;
  const FlashAwaitingClientPage({
    super.key,
    required this.tripId,
    required this.service,
  });

  @override
  State<FlashAwaitingClientPage> createState() =>
      _FlashAwaitingClientPageState();
}

class _FlashAwaitingClientPageState extends State<FlashAwaitingClientPage> {
  StreamSubscription? _sub;
  String? _myDriverProfileId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final profile = await client
          .from('driver_profiles')
          .select('id, provider_profiles!inner(user_id)')
          .eq('provider_profiles.user_id', userId)
          .single();
      _myDriverProfileId = profile['id'] as String;
    } catch (_) {
      // segue sem id — trata como "não sou o escolhido"
    }
    _sub = widget.service.watchTripStatus(widget.tripId).listen(_onStatus);
  }

  void _onStatus(Map<String, dynamic> row) {
    if (!mounted) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    switch (row['status']) {
      case 'awaiting_driver_confirmation':
        if (_myDriverProfileId != null &&
            row['driver_profile_id'] == _myDriverProfileId) {
          router.go('/flash/recheck/${widget.tripId}');
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Cliente escolheu outro motorista'),
            ),
          );
          router.go('/home');
        }
        break;
      case 'cancelled':
        messenger.showSnackBar(
          const SnackBar(content: Text('Cliente cancelou a Flash')),
        );
        router.go('/home');
        break;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Proposta enviada, aguardando cliente escolher...'),
            ],
          ),
        ),
      );
}
