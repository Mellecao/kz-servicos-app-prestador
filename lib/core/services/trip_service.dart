import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';

const _tripSelect =
    '*, pickup_address:addresses!pickup_address_id(formatted_address,latitude,longitude), '
    'dropoff_address:addresses!dropoff_address_id(formatted_address,latitude,longitude), '
    'client:users!client_id(full_name,phone)';

const _tripDetailSelect =
    '*, pickup_address:addresses!pickup_address_id(formatted_address,latitude,longitude), '
    'dropoff_address:addresses!dropoff_address_id(formatted_address,latitude,longitude), '
    'client:users!client_id(full_name,phone), '
    'trip_children(*), trip_luggage(*)';

const _tripHistorySelect =
    '*, pickup_address:addresses!pickup_address_id(formatted_address,latitude,longitude), '
    'dropoff_address:addresses!dropoff_address_id(formatted_address,latitude,longitude), '
    'client:users!client_id(full_name), '
    'ratings(score)';

class TripService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Convites pendentes para o motorista — tela home (ainda não respondidos).
  Future<List<TripData>> getDriverInvitations(String driverProfileId) async {
    try {
      final res = await _client
          .from('trip_driver_candidates')
          .select('id, trip:trips!trip_id($_tripSelect)')
          .eq('driver_profile_id', driverProfileId)
          .eq('status', 'pending');
      return (res as List)
          .map((c) {
            final cMap = c as Map<String, dynamic>;
            final trip = cMap['trip'] as Map<String, dynamic>?;
            if (trip == null) return null;
            return TripData.fromMap({...trip, 'candidate_id': cMap['id']});
          })
          .whereType<TripData>()
          .toList();
    } catch (e) {
      debugPrint('[TripService] getDriverInvitations erro: $e');
      return [];
    }
  }

  /// Candidaturas aceitas pelo motorista ainda aguardando aprovação — tela agendamentos.
  Future<List<TripData>> getDriverAcceptedCandidacies(String driverProfileId) async {
    try {
      final res = await _client
          .from('trip_driver_candidates')
          .select('trip:trips!trip_id($_tripSelect)')
          .eq('driver_profile_id', driverProfileId)
          .eq('status', 'accepted');
      return (res as List)
          .map((c) => (c as Map)['trip'] as Map<String, dynamic>?)
          .where((trip) => trip != null)
          .map((trip) => TripData.fromMap(trip!))
          .where((trip) =>
              trip.status == 'searching_drivers' ||
              trip.status == 'awaiting_client_confirmation')
          .toList();
    } catch (e) {
      debugPrint('[TripService] getDriverAcceptedCandidacies erro: $e');
      return [];
    }
  }

  /// Aceita um convite de corrida (atualiza candidato para 'accepted').
  Future<bool> acceptCandidate(
    String tripId,
    String driverProfileId, {
    double? offeredPrice,
  }) async {
    try {
      // ignore: use_null_aware_elements
      final updateMap = {
        'status': 'accepted',
        'responded_at': DateTime.now().toIso8601String(),
        if (offeredPrice != null) 'offered_price': offeredPrice,
      };
      await _client
          .from('trip_driver_candidates')
          .update(updateMap)
          .eq('trip_id', tripId)
          .eq('driver_profile_id', driverProfileId);
      return true;
    } catch (e) {
      debugPrint('[TripService] acceptCandidate erro: $e');
      return false;
    }
  }

  /// Recusa um convite de corrida (atualiza candidato para 'rejected').
  Future<bool> rejectCandidate(
    String tripId,
    String driverProfileId, {
    String? observation,
  }) async {
    try {
      await _client
          .from('trip_driver_candidates')
          .update({
            'status': 'rejected',
            'responded_at': DateTime.now().toIso8601String(),
            if (observation != null && observation.isNotEmpty)
              'observations': observation,
          })
          .eq('trip_id', tripId)
          .eq('driver_profile_id', driverProfileId);
      return true;
    } catch (e) {
      debugPrint('[TripService] rejectCandidate erro: $e');
      return false;
    }
  }

  /// Todas as viagens atribuídas ao motorista (agendamentos).
  Future<List<TripData>> getDriverScheduledTrips(String driverProfileId) async {
    try {
      final res = await _client
          .from('trips')
          .select(_tripSelect)
          .eq('driver_profile_id', driverProfileId)
          .inFilter('status', [
            'awaiting_driver_confirmation',
            'awaiting_client_confirmation',
            'scheduled',
          ])
          .order('scheduled_datetime');
      return (res as List).map((m) => TripData.fromMap(m as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[TripService] getDriverScheduledTrips erro: $e');
      return [];
    }
  }

  /// Inicia uma corrida agendada (scheduled → started).
  Future<bool> startTrip(String tripId) async {
    try {
      await _client
          .from('trips')
          .update({'status': 'started'})
          .eq('id', tripId);
      return true;
    } catch (e) {
      debugPrint('[TripService] startTrip erro: $e');
      return false;
    }
  }

  /// Detalhes completos de uma corrida por ID.
  Future<TripData?> getTripById(String tripId) async {
    try {
      final res = await _client
          .from('trips')
          .select(_tripDetailSelect)
          .eq('id', tripId)
          .single();
      return TripData.fromMap(res);
    } catch (e) {
      debugPrint('[TripService] getTripById erro: $e');
      return null;
    }
  }

  /// Histórico de corridas finalizadas do motorista.
  Future<List<TripData>> getDriverTripHistory(String providerProfileId) async {
    try {
      final res = await _client
          .from('trips')
          .select(_tripHistorySelect)
          .eq('driver_profile_id', providerProfileId)
          .eq('status', 'finished')
          .order('finished_at', ascending: false);
      return (res as List).map((m) => TripData.fromMap(m as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[TripService] getDriverTripHistory erro: $e');
      return [];
    }
  }

  /// Aceita uma corrida disponível da home (status searching_drivers).
  Future<bool> acceptAvailableTrip(String tripId, String providerProfileId) async {
    try {
      await _client.from('trips').update({
        'driver_profile_id': providerProfileId,
        'status': 'awaiting_client_confirmation',
      }).eq('id', tripId);
      return true;
    } catch (e) {
      debugPrint('[TripService] acceptAvailableTrip erro: $e');
      return false;
    }
  }

  /// Confirma um agendamento aguardando confirmação do motorista.
  Future<bool> confirmScheduledTrip(String tripId, String? driverObservation) async {
    try {
      await _client.from('trips').update({
        'status': 'scheduled',
        if (driverObservation != null && driverObservation.isNotEmpty)
          'driver_observations': driverObservation,
      }).eq('id', tripId);
      return true;
    } catch (e) {
      debugPrint('[TripService] confirmScheduledTrip erro: $e');
      return false;
    }
  }

  /// Recusa uma corrida (disponível ou agendamento).
  Future<bool> rejectTrip(String tripId, String reason) async {
    try {
      await _client.from('trips').update({
        'driver_profile_id': null,
        'status': 'searching_drivers',
        'driver_observations': reason,
      }).eq('id', tripId);
      return true;
    } catch (e) {
      debugPrint('[TripService] rejectTrip erro: $e');
      return false;
    }
  }

  /// Ganhos do motorista: busca todas as corridas atribuídas e agrega por is_driver_paied.
  Future<EarningsData> getDriverEarnings(String driverProfileId) async {
    try {
      final res = await _client
          .from('trips')
          .select('id, estimated_price, final_price, scheduled_datetime, finished_at, payment_method, is_driver_paied, status, payment_date')
          .eq('driver_profile_id', driverProfileId)
          .order('scheduled_datetime', ascending: false);

      final trips = (res as List).cast<Map<String, dynamic>>();
      return EarningsData.fromTrips(trips);
    } catch (e) {
      debugPrint('[TripService] getDriverEarnings erro: $e');
      return EarningsData.empty();
    }
  }
}

// ── Earnings models ──────────────────────────────────────────────────────────

enum EarningType { trip, bonus, withdrawal }

class PeriodEarning {
  final double total;
  final int trips;
  const PeriodEarning({required this.total, required this.trips});
}

class MonthlyEarning {
  final int month;
  final int year;
  final double total;
  final int trips;
  const MonthlyEarning({
    required this.month,
    required this.year,
    required this.total,
    required this.trips,
  });
}

class EarningEntry {
  final String id;
  final String description;
  final double amount;
  final DateTime date;
  final EarningType type;
  final bool isPaid;
  const EarningEntry({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
    this.isPaid = false,
  });
}

class EarningsData {
  final double availableBalance;
  final double totalReceived;
  final double currentMonthTotal;
  final double previousMonthTotal;
  final PeriodEarning dailyEarning;
  final PeriodEarning weeklyEarning;
  final PeriodEarning monthlyEarning;
  final PeriodEarning yearlyEarning;
  final List<MonthlyEarning> monthlyHistory;
  final List<EarningEntry> recentEntries;
  final int totalTrips;

  const EarningsData({
    required this.availableBalance,
    required this.totalReceived,
    required this.currentMonthTotal,
    required this.previousMonthTotal,
    required this.dailyEarning,
    required this.weeklyEarning,
    required this.monthlyEarning,
    required this.yearlyEarning,
    required this.monthlyHistory,
    required this.recentEntries,
    required this.totalTrips,
  });

  EarningEntry get lastTransaction => recentEntries.isNotEmpty
      ? recentEntries.first
      : EarningEntry(
          id: '',
          description: '-',
          amount: 0,
          date: DateTime.now(),
          type: EarningType.trip,
        );

  factory EarningsData.empty() => const EarningsData(
        availableBalance: 0,
        totalReceived: 0,
        currentMonthTotal: 0,
        previousMonthTotal: 0,
        dailyEarning: PeriodEarning(total: 0, trips: 0),
        weeklyEarning: PeriodEarning(total: 0, trips: 0),
        monthlyEarning: PeriodEarning(total: 0, trips: 0),
        yearlyEarning: PeriodEarning(total: 0, trips: 0),
        monthlyHistory: [],
        recentEntries: [],
        totalTrips: 0,
      );

  factory EarningsData.fromTrips(List<Map<String, dynamic>> trips) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final prevMonthStart = DateTime(now.year, now.month - 1, 1);
    final yearStart = DateTime(now.year, 1, 1);

    final paidTrips = trips.where((t) => t['is_driver_paied'] == true).toList();
    final unpaidTrips = trips.where((t) => t['is_driver_paied'] != true).toList();

    // Valor a receber: TODAS as corridas onde is_driver_paied = false
    double availableBalance = 0;
    for (final t in unpaidTrips) {
      availableBalance +=
          ((t['final_price'] ?? t['estimated_price']) as num?)?.toDouble() ?? 0;
    }

    // Total recebido: soma de todas as corridas pagas (histórico completo)
    double totalReceived = 0;
    for (final t in paidTrips) {
      totalReceived +=
          ((t['final_price'] ?? t['estimated_price']) as num?)?.toDouble() ?? 0;
    }

    // Ganhos por período (apenas pagas) — mantidos no modelo para uso futuro
    double daily = 0, weekly = 0, monthly = 0, yearly = 0;
    int dailyCount = 0, weeklyCount = 0, monthlyCount = 0, yearlyCount = 0;
    for (final t in paidTrips) {
      final price =
          ((t['final_price'] ?? t['estimated_price']) as num?)?.toDouble() ?? 0;
      final dateStr =
          (t['payment_date'] ?? t['finished_at'] ?? t['scheduled_datetime']) as String?;
      if (dateStr == null) continue;
      final date = DateTime.parse(dateStr);
      if (!date.isBefore(yearStart)) { yearly += price; yearlyCount++; }
      if (!date.isBefore(monthStart)) { monthly += price; monthlyCount++; }
      if (!date.isBefore(weekStart)) { weekly += price; weeklyCount++; }
      if (!date.isBefore(todayStart)) { daily += price; dailyCount++; }
    }

    // Histórico mensal: TODAS as corridas (pagas e não pagas) agrupadas por mês
    // Usa scheduled_datetime como fallback para garantir que todas apareçam no gráfico
    double currentMonthAll = 0, prevMonthAll = 0;
    final monthMap = <String, MonthlyEarning>{};
    for (final t in trips) {
      final price =
          ((t['final_price'] ?? t['estimated_price']) as num?)?.toDouble() ?? 0;
      final dateStr =
          (t['payment_date'] ?? t['finished_at'] ?? t['scheduled_datetime']) as String?;
      if (dateStr == null) continue;
      final date = DateTime.parse(dateStr);

      if (!date.isBefore(monthStart)) currentMonthAll += price;
      if (!date.isBefore(prevMonthStart) && date.isBefore(monthStart)) {
        prevMonthAll += price;
      }

      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final existing = monthMap[key];
      monthMap[key] = MonthlyEarning(
        month: date.month,
        year: date.year,
        total: (existing?.total ?? 0) + price,
        trips: (existing?.trips ?? 0) + 1,
      );
    }

    final history = monthMap.values.toList()
      ..sort((a, b) =>
          DateTime(a.year, a.month).compareTo(DateTime(b.year, b.month)));

    // Extrato: últimas 10 corridas do motorista (pagas e não pagas)
    final entries = trips.take(10).map((t) {
      final price =
          ((t['final_price'] ?? t['estimated_price']) as num?)?.toDouble() ?? 0;
      final dateStr =
          (t['payment_date'] ?? t['finished_at'] ?? t['scheduled_datetime'] ?? '') as String;
      final date =
          dateStr.isNotEmpty ? DateTime.parse(dateStr) : DateTime.now();
      return EarningEntry(
        id: t['id'] as String? ?? '',
        description: 'Corrida',
        amount: price,
        date: date,
        type: EarningType.trip,
        isPaid: t['is_driver_paied'] == true,
      );
    }).toList();

    return EarningsData(
      availableBalance: availableBalance,
      totalReceived: totalReceived,
      currentMonthTotal: currentMonthAll,
      previousMonthTotal: prevMonthAll,
      dailyEarning: PeriodEarning(total: daily, trips: dailyCount),
      weeklyEarning: PeriodEarning(total: weekly, trips: weeklyCount),
      monthlyEarning: PeriodEarning(total: monthly, trips: monthlyCount),
      yearlyEarning: PeriodEarning(total: yearly, trips: yearlyCount),
      monthlyHistory: history,
      recentEntries: entries,
      totalTrips: trips.length,
    );
  }

  /// Agrega ganhos a partir de service_requests do prestador.
  /// Usa is_paid (em vez de is_driver_paied) e service_date como data de referência.
  factory EarningsData.fromServiceRequests(
    List<Map<String, dynamic>> requests,
  ) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final prevMonthStart = DateTime(now.year, now.month - 1, 1);
    final yearStart = DateTime(now.year, 1, 1);

    final paid = requests.where((r) => r['is_paid'] == true).toList();
    final unpaid = requests.where((r) => r['is_paid'] != true).toList();

    double availableBalance = 0;
    for (final r in unpaid) {
      availableBalance +=
          ((r['final_price'] ?? r['estimated_price']) as num?)?.toDouble() ?? 0;
    }

    double totalReceived = 0;
    for (final r in paid) {
      totalReceived +=
          ((r['final_price'] ?? r['estimated_price']) as num?)?.toDouble() ?? 0;
    }

    double daily = 0, weekly = 0, monthly = 0, yearly = 0;
    int dailyCount = 0, weeklyCount = 0, monthlyCount = 0, yearlyCount = 0;
    for (final r in paid) {
      final price =
          ((r['final_price'] ?? r['estimated_price']) as num?)?.toDouble() ?? 0;
      final dateStr = r['service_date'] as String?;
      if (dateStr == null) continue;
      final date = DateTime.parse(dateStr);
      if (!date.isBefore(yearStart)) { yearly += price; yearlyCount++; }
      if (!date.isBefore(monthStart)) { monthly += price; monthlyCount++; }
      if (!date.isBefore(weekStart)) { weekly += price; weeklyCount++; }
      if (!date.isBefore(todayStart)) { daily += price; dailyCount++; }
    }

    double currentMonthAll = 0, prevMonthAll = 0;
    final monthMap = <String, MonthlyEarning>{};
    for (final r in requests) {
      final price =
          ((r['final_price'] ?? r['estimated_price']) as num?)?.toDouble() ?? 0;
      final dateStr = r['service_date'] as String?;
      if (dateStr == null) continue;
      final date = DateTime.parse(dateStr);

      if (!date.isBefore(monthStart)) currentMonthAll += price;
      if (!date.isBefore(prevMonthStart) && date.isBefore(monthStart)) {
        prevMonthAll += price;
      }

      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final existing = monthMap[key];
      monthMap[key] = MonthlyEarning(
        month: date.month,
        year: date.year,
        total: (existing?.total ?? 0) + price,
        trips: (existing?.trips ?? 0) + 1,
      );
    }

    final history = monthMap.values.toList()
      ..sort((a, b) =>
          DateTime(a.year, a.month).compareTo(DateTime(b.year, b.month)));

    final entries = requests.take(10).map((r) {
      final price =
          ((r['final_price'] ?? r['estimated_price']) as num?)?.toDouble() ?? 0;
      final dateStr = (r['service_date'] ?? '') as String;
      final date =
          dateStr.isNotEmpty ? DateTime.parse(dateStr) : DateTime.now();
      return EarningEntry(
        id: r['id'] as String? ?? '',
        description: 'Serviço',
        amount: price,
        date: date,
        type: EarningType.trip,
        isPaid: r['is_paid'] == true,
      );
    }).toList();

    return EarningsData(
      availableBalance: availableBalance,
      totalReceived: totalReceived,
      currentMonthTotal: currentMonthAll,
      previousMonthTotal: prevMonthAll,
      dailyEarning: PeriodEarning(total: daily, trips: dailyCount),
      weeklyEarning: PeriodEarning(total: weekly, trips: weeklyCount),
      monthlyEarning: PeriodEarning(total: monthly, trips: monthlyCount),
      yearlyEarning: PeriodEarning(total: yearly, trips: yearlyCount),
      monthlyHistory: history,
      recentEntries: entries,
      totalTrips: requests.length,
    );
  }
}
