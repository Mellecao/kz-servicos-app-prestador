import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/active_trip_data.dart';
import 'package:kz_servicos_prestador/core/utils/kz_format.dart';

enum TripPhase {
  navigatingToClient,
  arrivedAtClient,
  tripInProgress,
  tripCompleted,
}

extension TripPhaseProperties on TripPhase {
  String get title => switch (this) {
    TripPhase.navigatingToClient => 'A caminho do passageiro',
    TripPhase.arrivedAtClient => 'Chegou ao local',
    TripPhase.tripInProgress => 'Viagem em andamento',
    TripPhase.tripCompleted => 'Viagem finalizada',
  };

  String subtitle(ActiveTripData trip) => switch (this) {
    TripPhase.navigatingToClient => trip.pickupAddress,
    TripPhase.arrivedAtClient => 'A aguardar ${trip.clientName}',
    TripPhase.tripInProgress => trip.destinationAddress,
    TripPhase.tripCompleted => formatKz(trip.offeredPrice),
  };

  Color get color => switch (this) {
    TripPhase.navigatingToClient => AppColors.secondary,
    TripPhase.arrivedAtClient => AppColors.highlight,
    TripPhase.tripInProgress => const Color(0xFF2ECC71),
    TripPhase.tripCompleted => const Color(0xFF2ECC71),
  };

  IconData get icon => switch (this) {
    TripPhase.navigatingToClient => Icons.navigation_rounded,
    TripPhase.arrivedAtClient => Icons.location_on_rounded,
    TripPhase.tripInProgress => Icons.directions_car_rounded,
    TripPhase.tripCompleted => Icons.check_circle_rounded,
  };

  String get buttonLabel => switch (this) {
    TripPhase.navigatingToClient => 'Cheguei ao local',
    TripPhase.arrivedAtClient => 'Iniciar viagem',
    TripPhase.tripInProgress => 'Finalizar viagem',
    TripPhase.tripCompleted => '',
  };

  bool get isGpsMode =>
      this == TripPhase.navigatingToClient || this == TripPhase.tripInProgress;

  // Publica localização também quando aguardando o passageiro no local
  bool get isPublishingGps =>
      this == TripPhase.navigatingToClient ||
      this == TripPhase.arrivedAtClient ||
      this == TripPhase.tripInProgress;

  bool get isActive => this != TripPhase.tripCompleted;
}
