import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:kz_servicos_prestador/core/models/trip_data.dart';
import 'package:kz_servicos_prestador/core/services/trip_service.dart';

class ScheduledTripsService extends ChangeNotifier {
  final String _driverProfileId;
  final _tripService = TripService();

  List<TripData> _trips = [];
  List<TripData> get trips => List.unmodifiable(_trips);

  RealtimeChannel? _candidatesChannel;
  RealtimeChannel? _tripsChannel;

  ScheduledTripsService(this._driverProfileId) {
    load();
    _subscribe();
  }

  /// Mescla duas listas deduplificando por tripId e ordenando por scheduledAt.
  static List<TripData> mergeAndSort(List<TripData> a, List<TripData> b) {
    final seen = <String>{};
    final merged = <TripData>[];
    for (final trip in [...a, ...b]) {
      if (seen.add(trip.tripId)) merged.add(trip);
    }
    merged.sort((x, y) => x.scheduledAt.compareTo(y.scheduledAt));
    return merged;
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([
        _tripService.getDriverAcceptedCandidacies(_driverProfileId),
        _tripService.getDriverScheduledTrips(_driverProfileId),
      ]);
      _trips = mergeAndSort(results[0], results[1]);
      notifyListeners();
    } catch (e) {
      debugPrint('[ScheduledTripsService] load erro: $e');
    }
  }

  void _subscribe() {
    final client = Supabase.instance.client;
    _candidatesChannel = client
        .channel('sched-candidates-$_driverProfileId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trip_driver_candidates',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_profile_id',
            value: _driverProfileId,
          ),
          callback: (_) => load(),
        )
        .subscribe();

    _tripsChannel = client
        .channel('sched-trips-$_driverProfileId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trips',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_profile_id',
            value: _driverProfileId,
          ),
          callback: (_) => load(),
        )
        .subscribe();
  }

  void unsubscribe() {
    _candidatesChannel?.unsubscribe();
    _tripsChannel?.unsubscribe();
    _candidatesChannel = null;
    _tripsChannel = null;
  }

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
  }
}
