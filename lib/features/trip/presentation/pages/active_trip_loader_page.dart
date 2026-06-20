import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/trip_service.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/active_trip_data.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/pages/active_trip_page.dart';

class ActiveTripLoaderPage extends StatefulWidget {
  final String? tripId;

  const ActiveTripLoaderPage({super.key, this.tripId});

  @override
  State<ActiveTripLoaderPage> createState() => _ActiveTripLoaderPageState();
}

class _ActiveTripLoaderPageState extends State<ActiveTripLoaderPage> {
  final _tripService = TripService();
  late final Future<ActiveTripData?> _future = _loadTrip();

  Future<ActiveTripData?> _loadTrip() async {
    final driverProfileId = AuthState.driverProfileId;
    if (widget.tripId != null) {
      return _tripService.getActiveTripById(
        widget.tripId!,
        driverProfileId: driverProfileId,
      );
    }
    if (driverProfileId == null) return null;
    return _tripService.getCurrentActiveTrip(driverProfileId);
  }

  bool _canOpen(ActiveTripData trip) =>
      trip.status == 'started' || trip.status == 'finished';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ActiveTripData?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final trip = snapshot.data;
        if (trip != null && _canOpen(trip)) {
          return ActiveTripPage(trip: trip);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go('/home');
        });
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
