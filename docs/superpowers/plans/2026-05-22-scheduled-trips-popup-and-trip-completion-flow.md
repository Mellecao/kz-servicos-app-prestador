# Popup de Corridas Agendadas + Fluxo de Conclusão de Viagem — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar popup carousel de corridas aceitas/agendadas na home com Realtime, tela de cobrança ao finalizar viagem e feedback aprimorado com comentário + botão de relatar problema via WhatsApp.

**Architecture:** `ScheduledTripsService` (ChangeNotifier singleton) centraliza a lista reativa de corridas e subscriptions Realtime; `ScheduledTripsCarousel` consome esse service na `HomePage`; o fluxo de conclusão de viagem ganha `PaymentCollectionPanel` antes do `TripCompletedPanel`.

**Tech Stack:** Flutter, Supabase Realtime (PostgresChanges), `url_launcher: ^6.3.2`, GoRouter, Flutter test.

---

## Mapa de arquivos

| Arquivo | Ação |
|---|---|
| `lib/core/models/trip_data.dart` | Modificar — `candidateStatus`, `clientId`, `statusLabel`, `isAwaitingKzApproval` |
| `lib/core/services/trip_service.dart` | Modificar — incluir `status` e `candidate_status` em `getDriverAcceptedCandidacies` |
| `lib/core/services/scheduled_trips_service.dart` | **Criar** — ChangeNotifier com load + Realtime |
| `lib/core/services/auth_state.dart` | Modificar — campo estático + init/dispose no login/logout |
| `lib/features/home/presentation/widgets/scheduled_trips_carousel.dart` | **Criar** — PageView + dots + _TripCard |
| `lib/features/home/presentation/pages/home_page.dart` | Modificar — listener + carousel no Stack |
| `lib/features/trip/data/models/active_trip_data.dart` | Modificar — `clientId`, `paymentMethod`, `scheduledAt`, getter `paymentMethodLabel` |
| `lib/features/schedules/presentation/pages/schedules_page.dart` | Modificar — passar novos campos em `_startTrip` |
| `lib/features/schedules/presentation/pages/schedule_detail_page.dart` | Modificar — passar novos campos em `_startTrip` |
| `lib/features/trip/presentation/widgets/active_trip_panels.dart` | Modificar — `PaymentCollectionPanel` (novo) + `TripCompletedPanel` aprimorado |
| `lib/features/trip/presentation/pages/active_trip_page.dart` | Modificar — `_paymentConfirmed`, handlers de pagamento/feedback |
| `android/app/src/main/AndroidManifest.xml` | Modificar — bloco `<queries>` para WhatsApp |
| `test/core/models/trip_data_test.dart` | **Criar** |
| `test/core/services/scheduled_trips_service_test.dart` | **Criar** |
| `test/features/home/widgets/scheduled_trips_carousel_test.dart` | **Criar** |

---

## Task 1: TripData — candidateStatus, clientId e statusLabel

**Files:**
- Modify: `lib/core/models/trip_data.dart`
- Create: `test/core/models/trip_data_test.dart`

- [ ] **Step 1: Criar teste falhando para statusLabel**

Criar o arquivo `test/core/models/trip_data_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';

TripData makeTrip({
  required String status,
  String? candidateStatus,
  String? clientId,
}) {
  return TripData(
    tripId: 'trip-1',
    candidateId: 'cand-1',
    clientName: 'João',
    origin: 'Av. Paulista, 1000',
    destination: 'Aeroporto Congonhas',
    originLat: -23.5505,
    originLng: -46.6333,
    destinationLat: -23.6273,
    destinationLng: -46.6566,
    scheduledAt: DateTime(2026, 5, 25, 14, 30),
    passengerCount: 2,
    childrenCount: 0,
    luggageCount: 1,
    status: status,
    candidateStatus: candidateStatus,
    clientId: clientId,
  );
}

void main() {
  group('TripData.statusLabel', () {
    test('searching_drivers com candidateStatus=accepted mostra "Aguardando aprovação da KZ"', () {
      final trip = makeTrip(status: 'searching_drivers', candidateStatus: 'accepted');
      expect(trip.statusLabel, 'Aguardando aprovação da KZ');
    });

    test('searching_drivers sem candidateStatus mantém "Buscando motoristas"', () {
      final trip = makeTrip(status: 'searching_drivers');
      expect(trip.statusLabel, 'Buscando motoristas');
    });

    test('awaiting_client_confirmation mostra "Aguardando passageiro aceitar"', () {
      final trip = makeTrip(status: 'awaiting_client_confirmation');
      expect(trip.statusLabel, 'Aguardando passageiro aceitar');
    });

    test('scheduled mostra "Agendada"', () {
      final trip = makeTrip(status: 'scheduled');
      expect(trip.statusLabel, 'Agendada');
    });
  });

  group('TripData.isAwaitingKzApproval', () {
    test('true quando searching_drivers + candidateStatus=accepted', () {
      final trip = makeTrip(status: 'searching_drivers', candidateStatus: 'accepted');
      expect(trip.isAwaitingKzApproval, isTrue);
    });

    test('false quando searching_drivers sem candidateStatus', () {
      final trip = makeTrip(status: 'searching_drivers');
      expect(trip.isAwaitingKzApproval, isFalse);
    });

    test('false quando scheduled mesmo com candidateStatus', () {
      final trip = makeTrip(status: 'scheduled', candidateStatus: 'accepted');
      expect(trip.isAwaitingKzApproval, isFalse);
    });
  });

  group('TripData.clientId', () {
    test('retorna clientId quando fornecido', () {
      final trip = makeTrip(status: 'scheduled', clientId: 'user-abc');
      expect(trip.clientId, 'user-abc');
    });

    test('retorna null quando não fornecido', () {
      final trip = makeTrip(status: 'scheduled');
      expect(trip.clientId, isNull);
    });
  });
}
```

- [ ] **Step 2: Rodar teste para confirmar falha**

```
flutter test test/core/models/trip_data_test.dart
```

Esperado: FAIL — `candidateStatus`, `clientId`, `isAwaitingKzApproval` não existem.

- [ ] **Step 3: Atualizar `lib/core/models/trip_data.dart`**

Adicionar campos e atualizar getters. Substituir a classe `TripData` completa:

```dart
class TripData {
  final String tripId;
  final String candidateId;
  final String? clientId;          // NEW — trips.client_id (FK → users)
  final String? candidateStatus;   // NEW — trip_driver_candidates.status
  final String clientName;
  final String? clientPhone;
  final String origin;
  final String destination;
  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;
  final DateTime scheduledAt;
  final int passengerCount;
  final int childrenCount;
  final int luggageCount;
  final String? observations;
  final String? driverObservations;
  final double? estimatedPrice;
  final double? finalPrice;
  final String? paymentMethod;
  final String status;
  final DateTime? finishedAt;
  final double? rating;
  final List<TripChild> children;
  final List<TripLuggage> luggage;

  const TripData({
    required this.tripId,
    required this.candidateId,
    this.clientId,
    this.candidateStatus,
    required this.clientName,
    this.clientPhone,
    required this.origin,
    required this.destination,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.scheduledAt,
    required this.passengerCount,
    required this.childrenCount,
    required this.luggageCount,
    this.observations,
    this.driverObservations,
    this.estimatedPrice,
    this.finalPrice,
    this.paymentMethod,
    required this.status,
    this.finishedAt,
    this.rating,
    this.children = const [],
    this.luggage = const [],
  });

  double get price => finalPrice ?? estimatedPrice ?? 0;
  bool get hasChildren => childrenCount > 0;
  bool get hasLuggage => luggageCount > 0;
  bool get isAwaitingKzApproval =>
      status == 'searching_drivers' && candidateStatus == 'accepted';

  bool get canDriverRespond =>
      status == 'searching_drivers' || status == 'awaiting_driver_confirmation';

  String get statusLabel {
    if (isAwaitingKzApproval) return 'Aguardando aprovação da KZ';
    return switch (status) {
      'open' => 'Aberta',
      'under_review' => 'Em análise',
      'searching_drivers' => 'Buscando motoristas',
      'awaiting_driver_confirmation' => 'Aguardando confirmação',
      'awaiting_client_confirmation' => 'Aguardando passageiro aceitar',
      'scheduled' => 'Agendada',
      'started' => 'Em andamento',
      'finished' => 'Finalizado',
      'cancelled' => 'Cancelado',
      _ => status,
    };
  }

  String get paymentMethodLabel => switch (paymentMethod) {
        'pix' => 'PIX',
        'debit' => 'Débito',
        'credit' => 'Crédito',
        'cash' => 'Dinheiro',
        'billing' => 'Faturamento',
        _ => paymentMethod ?? '-',
      };

  factory TripData.fromMap(Map<String, dynamic> map) {
    final pickup = map['pickup_address'] as Map<String, dynamic>? ?? {};
    final dropoff = map['dropoff_address'] as Map<String, dynamic>? ?? {};
    final clientMap = map['client'] as Map<String, dynamic>? ?? {};

    final rawChildren = map['trip_children'];
    final rawLuggage = map['trip_luggage'];

    final children = rawChildren is List
        ? rawChildren
            .map((e) => TripChild.fromMap(e as Map<String, dynamic>))
            .toList()
        : <TripChild>[];

    final luggage = rawLuggage is List
        ? rawLuggage
            .map((e) => TripLuggage.fromMap(e as Map<String, dynamic>))
            .toList()
        : <TripLuggage>[];

    final ratingsRaw = map['ratings'];
    double? rating;
    if (ratingsRaw is List && ratingsRaw.isNotEmpty) {
      rating = (ratingsRaw.first['score'] as num?)?.toDouble();
    } else if (ratingsRaw is Map) {
      rating = (ratingsRaw['score'] as num?)?.toDouble();
    }

    return TripData(
      tripId: map['id'] as String,
      candidateId: map['candidate_id'] as String? ?? '',
      clientId: map['client_id'] as String?,
      candidateStatus: map['candidate_status'] as String?,
      clientName: clientMap['full_name'] as String? ?? 'Cliente',
      clientPhone: clientMap['phone'] as String?,
      origin: pickup['formatted_address'] as String? ?? '',
      destination: dropoff['formatted_address'] as String? ?? '',
      originLat: (pickup['latitude'] as num?)?.toDouble() ?? -23.5505,
      originLng: (pickup['longitude'] as num?)?.toDouble() ?? -46.6333,
      destinationLat: (dropoff['latitude'] as num?)?.toDouble() ?? -23.5505,
      destinationLng: (dropoff['longitude'] as num?)?.toDouble() ?? -46.6333,
      scheduledAt: DateTime.parse(map['scheduled_datetime'] as String),
      passengerCount: (map['passenger_count'] as num?)?.toInt() ?? 1,
      childrenCount: (map['children_count'] as num?)?.toInt() ?? 0,
      luggageCount: (map['luggage_count'] as num?)?.toInt() ?? 0,
      observations: map['observations'] as String?,
      driverObservations: map['driver_observations'] as String?,
      estimatedPrice: (map['estimated_price'] as num?)?.toDouble(),
      finalPrice: (map['final_price'] as num?)?.toDouble(),
      paymentMethod: map['payment_method'] as String?,
      status: map['status'] as String? ?? 'open',
      finishedAt: map['finished_at'] != null
          ? DateTime.parse(map['finished_at'] as String)
          : null,
      rating: rating,
      children: children,
      luggage: luggage,
    );
  }
}
```

Manter `TripChild` e `TripLuggage` sem alterações.

- [ ] **Step 4: Rodar teste para confirmar aprovação**

```
flutter test test/core/models/trip_data_test.dart
```

Esperado: todos os testes PASS.

- [ ] **Step 5: Verificar análise estática**

```
flutter analyze lib/core/models/trip_data.dart
```

Esperado: sem erros ou warnings novos.

- [ ] **Step 6: Commit**

```
git add lib/core/models/trip_data.dart test/core/models/trip_data_test.dart
git commit -m "feat(model): adiciona candidateStatus, clientId e statusLabel do motorista em TripData"
```

---

## Task 2: TripService — candidate_status no select

**Files:**
- Modify: `lib/core/services/trip_service.dart`

- [ ] **Step 1: Atualizar `getDriverAcceptedCandidacies`**

Localizar o método `getDriverAcceptedCandidacies` em `lib/core/services/trip_service.dart` e substituí-lo integralmente:

```dart
/// Candidaturas aceitas pelo motorista ainda aguardando aprovação — tela agendamentos e carousel.
Future<List<TripData>> getDriverAcceptedCandidacies(String driverProfileId) async {
  try {
    final res = await _client
        .from('trip_driver_candidates')
        .select('status, trip:trips!trip_id($_tripSelect)')
        .eq('driver_profile_id', driverProfileId)
        .eq('status', 'accepted');
    return (res as List)
        .map((c) {
          final cMap = c as Map<String, dynamic>;
          final trip = cMap['trip'] as Map<String, dynamic>?;
          if (trip == null) return null;
          return TripData.fromMap({
            ...trip,
            'candidate_id': cMap['id'] ?? '',
            'candidate_status': cMap['status'],
          });
        })
        .whereType<TripData>()
        .where((trip) =>
            trip.status == 'searching_drivers' ||
            trip.status == 'awaiting_client_confirmation')
        .toList();
  } catch (e) {
    debugPrint('[TripService] getDriverAcceptedCandidacies erro: $e');
    return [];
  }
}
```

- [ ] **Step 2: Verificar análise estática e testes**

```
flutter analyze lib/core/services/trip_service.dart
flutter test test/core/models/trip_data_test.dart
```

Esperado: sem erros. Testes existentes PASS.

- [ ] **Step 3: Commit**

```
git add lib/core/services/trip_service.dart
git commit -m "feat(service): inclui candidate_status no select de candidaturas aceitas"
```

---

## Task 3: ScheduledTripsService — ChangeNotifier com Realtime

**Files:**
- Create: `lib/core/services/scheduled_trips_service.dart`
- Create: `test/core/services/scheduled_trips_service_test.dart`

- [ ] **Step 1: Criar teste falhando para mergeAndSort**

Criar `test/core/services/scheduled_trips_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';
import 'package:kz_servicos_prestador/core/services/scheduled_trips_service.dart';

TripData makeTrip(String id, DateTime scheduledAt) => TripData(
      tripId: id,
      candidateId: '',
      clientName: 'Cliente',
      origin: 'A',
      destination: 'B',
      originLat: 0, originLng: 0, destinationLat: 0, destinationLng: 0,
      scheduledAt: scheduledAt,
      passengerCount: 1,
      childrenCount: 0,
      luggageCount: 0,
      status: 'scheduled',
    );

void main() {
  group('ScheduledTripsService.mergeAndSort', () {
    test('deduplica por tripId mantendo primeira ocorrência', () {
      final t1 = makeTrip('a', DateTime(2026, 5, 26));
      final t2 = makeTrip('b', DateTime(2026, 5, 25));
      final t3 = makeTrip('a', DateTime(2026, 5, 26)); // duplicado

      final result = ScheduledTripsService.mergeAndSort([t1, t3], [t2]);

      expect(result.length, 2);
    });

    test('ordena por scheduledAt crescente', () {
      final t1 = makeTrip('a', DateTime(2026, 5, 26));
      final t2 = makeTrip('b', DateTime(2026, 5, 24));
      final t3 = makeTrip('c', DateTime(2026, 5, 25));

      final result = ScheduledTripsService.mergeAndSort([t1], [t2, t3]);

      expect(result.map((t) => t.tripId).toList(), ['b', 'c', 'a']);
    });

    test('retorna lista vazia quando ambas as listas são vazias', () {
      final result = ScheduledTripsService.mergeAndSort([], []);
      expect(result, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Rodar teste para confirmar falha**

```
flutter test test/core/services/scheduled_trips_service_test.dart
```

Esperado: FAIL — `ScheduledTripsService` não existe.

- [ ] **Step 3: Criar `lib/core/services/scheduled_trips_service.dart`**

```dart
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
```

- [ ] **Step 4: Rodar teste para confirmar aprovação**

```
flutter test test/core/services/scheduled_trips_service_test.dart
```

Esperado: PASS em todos os 3 testes.

- [ ] **Step 5: Commit**

```
git add lib/core/services/scheduled_trips_service.dart test/core/services/scheduled_trips_service_test.dart
git commit -m "feat(service): cria ScheduledTripsService com Realtime e mergeAndSort"
```

---

## Task 4: AuthState — ciclo de vida do ScheduledTripsService

**Files:**
- Modify: `lib/core/services/auth_state.dart`

- [ ] **Step 1: Adicionar campo e lifecycle em `auth_state.dart`**

Substituir o conteúdo de `lib/core/services/auth_state.dart`:

```dart
import 'package:kz_servicos_prestador/core/services/scheduled_trips_service.dart';
import 'package:kz_servicos_prestador/features/profile/data/models/mock_provider.dart';

class AuthState {
  static bool _isAuthenticated = false;
  static ProviderType? _providerType;
  static String? _userId;
  static String? _userName;
  static String? _userEmail;
  static String? _providerProfileId;
  static String? _driverProfileId;
  static ScheduledTripsService? _scheduledTrips;

  static bool get isAuthenticated => _isAuthenticated;
  static ProviderType? get providerType => _providerType;
  static String? get userId => _userId;
  static String? get userName => _userName;
  static String? get userEmail => _userEmail;
  static String? get providerProfileId => _providerProfileId;
  static String? get driverProfileId => _driverProfileId;
  static ScheduledTripsService? get scheduledTrips => _scheduledTrips;

  static void login({
    required ProviderType providerType,
    required String userId,
    required String name,
    required String email,
    required String providerProfileId,
    String? driverProfileId,
  }) {
    _isAuthenticated = true;
    _providerType = providerType;
    _userId = userId;
    _userName = name;
    _userEmail = email;
    _providerProfileId = providerProfileId;
    _driverProfileId = driverProfileId;

    if (providerType == ProviderType.driver && driverProfileId != null) {
      _scheduledTrips?.dispose();
      _scheduledTrips = ScheduledTripsService(driverProfileId);
    }
  }

  static void logout() {
    _scheduledTrips?.dispose();
    _scheduledTrips = null;
    _isAuthenticated = false;
    _providerType = null;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _providerProfileId = null;
    _driverProfileId = null;
  }

  static bool get isDriver => _providerType == ProviderType.driver;
  static bool get isServiceProvider => _providerType == ProviderType.serviceProvider;
}
```

- [ ] **Step 2: Verificar análise estática**

```
flutter analyze lib/core/services/auth_state.dart lib/core/services/scheduled_trips_service.dart
```

Esperado: sem erros.

- [ ] **Step 3: Commit**

```
git add lib/core/services/auth_state.dart
git commit -m "feat(auth): inicializa e descarta ScheduledTripsService no login/logout do motorista"
```

---

## Task 5: ScheduledTripsCarousel widget

**Files:**
- Create: `lib/features/home/presentation/widgets/scheduled_trips_carousel.dart`
- Create: `test/features/home/widgets/scheduled_trips_carousel_test.dart`

- [ ] **Step 1: Criar teste de widget falhando**

Criar `test/features/home/widgets/scheduled_trips_carousel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';
import 'package:kz_servicos_prestador/features/home/presentation/widgets/scheduled_trips_carousel.dart';

TripData makeTrip(String id, String status, {String? candidateStatus}) => TripData(
      tripId: id,
      candidateId: '',
      clientName: 'João Silva',
      origin: 'Av. Paulista, 1000',
      destination: 'Aeroporto Congonhas',
      originLat: -23.5505,
      originLng: -46.6333,
      destinationLat: -23.6273,
      destinationLng: -46.6566,
      scheduledAt: DateTime(2026, 5, 25, 14, 30),
      passengerCount: 2,
      childrenCount: 0,
      luggageCount: 1,
      status: status,
      candidateStatus: candidateStatus,
      paymentMethod: 'pix',
    );

Widget buildCarousel(List<TripData> trips, {void Function(TripData)? onTap}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          ScheduledTripsCarousel(
            trips: trips,
            onTap: onTap ?? (_) {},
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('ScheduledTripsCarousel', () {
    testWidgets('exibe nome do cliente', (tester) async {
      await tester.pumpWidget(buildCarousel([makeTrip('1', 'scheduled')]));
      expect(find.text('João Silva'), findsOneWidget);
    });

    testWidgets('exibe badge "Aguardando aprovação da KZ" quando candidateStatus=accepted', (tester) async {
      await tester.pumpWidget(buildCarousel([
        makeTrip('1', 'searching_drivers', candidateStatus: 'accepted'),
      ]));
      expect(find.text('Aguardando aprovação da KZ'), findsOneWidget);
    });

    testWidgets('exibe dots de paginação quando há mais de uma corrida', (tester) async {
      await tester.pumpWidget(buildCarousel([
        makeTrip('1', 'scheduled'),
        makeTrip('2', 'scheduled'),
      ]));
      // Dots container deve aparecer
      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    testWidgets('não exibe dots quando há apenas uma corrida', (tester) async {
      await tester.pumpWidget(buildCarousel([makeTrip('1', 'scheduled')]));
      expect(find.byType(AnimatedContainer), findsNothing);
    });

    testWidgets('chama onTap ao tocar no card', (tester) async {
      TripData? tapped;
      final trip = makeTrip('1', 'scheduled');
      await tester.pumpWidget(buildCarousel([trip], onTap: (t) => tapped = t));
      await tester.tap(find.text('João Silva'));
      expect(tapped?.tripId, '1');
    });
  });
}
```

- [ ] **Step 2: Rodar teste para confirmar falha**

```
flutter test test/features/home/widgets/scheduled_trips_carousel_test.dart
```

Esperado: FAIL — `ScheduledTripsCarousel` não existe.

- [ ] **Step 3: Criar `lib/features/home/presentation/widgets/scheduled_trips_carousel.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';

class ScheduledTripsCarousel extends StatefulWidget {
  final List<TripData> trips;
  final void Function(TripData) onTap;

  const ScheduledTripsCarousel({
    super.key,
    required this.trips,
    required this.onTap,
  });

  @override
  State<ScheduledTripsCarousel> createState() => _ScheduledTripsCarouselState();
}

class _ScheduledTripsCarouselState extends State<ScheduledTripsCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) setState(() => _currentPage = page);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.45),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.trips.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => widget.onTap(widget.trips[i]),
                  child: _TripCard(trip: widget.trips[i]),
                ),
              ),
            ),
            if (widget.trips.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DotsIndicator(
                  count: widget.trips.length,
                  current: _currentPage,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _DotsIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.highlight : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripData trip;

  const _TripCard({required this.trip});

  Color get _statusColor {
    if (trip.isAwaitingKzApproval) return const Color(0xFFE65100);
    return switch (trip.status) {
      'awaiting_client_confirmation' => AppColors.secondary,
      'scheduled' => const Color(0xFF27AE60),
      _ => AppColors.textSecondary,
    };
  }

  Color get _statusBg {
    if (trip.isAwaitingKzApproval) return const Color(0xFFFFF3E0);
    return switch (trip.status) {
      'awaiting_client_confirmation' =>
        AppColors.secondary.withValues(alpha: 0.1),
      'scheduled' => const Color(0xFF27AE60).withValues(alpha: 0.1),
      _ => Colors.grey.shade100,
    };
  }

  @override
  Widget build(BuildContext context) {
    final date = trip.scheduledAt;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha do cabeçalho
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.clientName,
                      style: const TextStyle(
                        fontFamily: 'OutfitBlack',
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateStr · $timeStr · ${trip.passengerCount} pax',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      trip.statusLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'R\$ ${trip.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontFamily: 'OutfitBlack',
                      fontSize: 13,
                      color: Color(0xFF27AE60),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Linha de rota
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF27AE60), width: 2),
                    ),
                  ),
                  Container(
                      width: 1.5, height: 14, color: Colors.grey.shade300),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.red.shade400, width: 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.origin,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      trip.destination,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Linha de pagamento e bagagem
          if (trip.paymentMethod != null || trip.hasLuggage) ...[
            const SizedBox(height: 6),
            const Divider(height: 1, color: Color(0xFFF5F5F5)),
            const SizedBox(height: 5),
            Row(
              children: [
                if (trip.paymentMethod != null)
                  Text(
                    '💳 ${trip.paymentMethodLabel}',
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary),
                  ),
                if (trip.paymentMethod != null && trip.hasLuggage)
                  const Text('  ·  ',
                      style: TextStyle(
                          fontSize: 9, color: AppColors.textSecondary)),
                if (trip.hasLuggage)
                  Text(
                    '👜 ${trip.luggageCount} mala${trip.luggageCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar testes para confirmar aprovação**

```
flutter test test/features/home/widgets/scheduled_trips_carousel_test.dart
```

Esperado: todos PASS.

- [ ] **Step 5: Commit**

```
git add lib/features/home/presentation/widgets/scheduled_trips_carousel.dart test/features/home/widgets/scheduled_trips_carousel_test.dart
git commit -m "feat(widget): cria ScheduledTripsCarousel com PageView e dots animados"
```

---

## Task 6: HomePage — integrar carousel via listener

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart`

- [ ] **Step 1: Adicionar listener ao ScheduledTripsService em `initState`**

Localizar `initState` em `_HomePageState` e adicionar ao final:

```dart
@override
void initState() {
  super.initState();
  _initLocation();
  _initIcons();
  _load().then((_) => _subscribeToInvitations());
  AuthState.scheduledTrips?.addListener(_onScheduledTripsChanged); // ADD
}
```

- [ ] **Step 2: Adicionar handler e remover listener em `dispose`**

Adicionar o método e atualizar `dispose`:

```dart
void _onScheduledTripsChanged() {
  if (mounted) setState(() {});
}

@override
void dispose() {
  AuthState.scheduledTrips?.removeListener(_onScheduledTripsChanged); // ADD
  _stopPulseAnimation();
  _requestTimer?.cancel();
  _invitationsChannel?.unsubscribe();
  super.dispose();
}
```

- [ ] **Step 3: Adicionar import e carousel no Stack do `build`**

Adicionar import no topo do arquivo:

```dart
import 'package:kz_servicos_prestador/features/home/presentation/widgets/scheduled_trips_carousel.dart';
```

No método `build`, localizar o bloco do `TripRequestCard` (que começa em `if (_isOnline && _showRequest && _requests.isNotEmpty)`) e adicionar o carousel **logo abaixo** (antes do location FAB):

```dart
// Carousel de corridas agendadas (só quando não há convite ativo sendo exibido)
if ((_isOnline || true) &&
    (AuthState.scheduledTrips?.trips.isNotEmpty ?? false) &&
    !(_showRequest && _requests.isNotEmpty))
  Positioned(
    bottom: bottomPadding + 72,
    left: 0,
    right: 0,
    child: ScheduledTripsCarousel(
      trips: AuthState.scheduledTrips!.trips,
      onTap: (trip) => context.push('/schedule-detail', extra: trip),
    ),
  ),
```

> **Nota:** O carousel aparece mesmo offline (`|| true`) para não esconder corridas já aceitas quando o motorista desliga o toggle. Ajuste conforme necessidade de negócio.

- [ ] **Step 4: Ajustar posição do FAB de localização**

Localizar o `FloatingActionButton.small` de localização e ajustar o `bottom` para considerar o carousel quando visível:

```dart
// My location button
Positioned(
  right: 16,
  bottom: bottomPadding +
      ((_showRequest && _requests.isNotEmpty) ? 320 : 
       (AuthState.scheduledTrips?.trips.isNotEmpty ?? false) ? 260 : 100),
  child: FloatingActionButton.small(
    heroTag: 'myLocation',
    backgroundColor: Colors.white,
    onPressed: () {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation, 15),
      );
    },
    child: const Icon(Icons.my_location, color: AppColors.textPrimary),
  ),
),
```

- [ ] **Step 5: Verificar análise e rodar testes**

```
flutter analyze lib/features/home/presentation/pages/home_page.dart
flutter test
```

Esperado: sem erros. Testes existentes PASS.

- [ ] **Step 6: Commit**

```
git add lib/features/home/presentation/pages/home_page.dart
git commit -m "feat(home): integra ScheduledTripsCarousel com listener em tempo real"
```

---

## Task 7: ActiveTripData — novos campos + construction sites

**Files:**
- Modify: `lib/features/trip/data/models/active_trip_data.dart`
- Modify: `lib/features/schedules/presentation/pages/schedules_page.dart`
- Modify: `lib/features/schedules/presentation/pages/schedule_detail_page.dart`

- [ ] **Step 1: Atualizar `lib/features/trip/data/models/active_trip_data.dart`**

Substituir a classe `ActiveTripData` completa:

```dart
class ActiveTripData {
  final String id;
  final String candidateId;
  final String clientName;
  final String? clientId;
  final String pickupAddress;
  final String destinationAddress;
  final double pickupLat;
  final double pickupLng;
  final double destinationLat;
  final double destinationLng;
  final int passengerCount;
  final double offeredPrice;
  final String? paymentMethod;
  final DateTime? scheduledAt;

  const ActiveTripData({
    required this.id,
    required this.candidateId,
    required this.clientName,
    this.clientId,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.passengerCount,
    required this.offeredPrice,
    this.paymentMethod,
    this.scheduledAt,
  });

  String get paymentMethodLabel => switch (paymentMethod) {
        'pix' => 'PIX',
        'debit' => 'Débito',
        'credit' => 'Crédito',
        'cash' => 'Dinheiro',
        'billing' => 'Faturamento',
        _ => paymentMethod ?? '-',
      };

  factory ActiveTripData.fromSupabase(
    Map<String, dynamic> trip,
    String candidateId,
    double offeredPrice,
  ) {
    final pickup = trip['pickup_address'] as Map<String, dynamic>;
    final dropoff = trip['dropoff_address'] as Map<String, dynamic>;
    final clientUser = trip['users'] as Map<String, dynamic>?;

    String shortAddress(Map<String, dynamic> addr) {
      final street = addr['street'] as String? ?? '';
      final number = addr['number'] as String? ?? '';
      final neighborhood = addr['neighborhood'] as String? ?? '';
      return '$street, $number - $neighborhood';
    }

    return ActiveTripData(
      id: trip['id'] as String,
      candidateId: candidateId,
      clientName: clientUser?['full_name'] as String? ?? 'Cliente',
      clientId: trip['client_id'] as String?,
      pickupAddress: shortAddress(pickup),
      destinationAddress: shortAddress(dropoff),
      pickupLat: double.parse('${pickup['latitude']}'),
      pickupLng: double.parse('${pickup['longitude']}'),
      destinationLat: double.parse('${dropoff['latitude']}'),
      destinationLng: double.parse('${dropoff['longitude']}'),
      passengerCount: trip['passenger_count'] as int? ?? 1,
      offeredPrice: offeredPrice,
      paymentMethod: trip['payment_method'] as String?,
      scheduledAt: trip['scheduled_datetime'] != null
          ? DateTime.parse(trip['scheduled_datetime'] as String)
          : null,
    );
  }
}
```

- [ ] **Step 2: Atualizar `_startTrip` em `schedules_page.dart`**

Localizar o método `_startTrip` em `lib/features/schedules/presentation/pages/schedules_page.dart` e substituir a construção do `ActiveTripData`:

```dart
final activeTripData = ActiveTripData(
  id: trip.tripId,
  candidateId: '',
  clientName: trip.clientName,
  clientId: trip.clientId,
  pickupAddress: trip.origin,
  destinationAddress: trip.destination,
  pickupLat: trip.originLat,
  pickupLng: trip.originLng,
  destinationLat: trip.destinationLat,
  destinationLng: trip.destinationLng,
  passengerCount: trip.passengerCount,
  offeredPrice: trip.price,
  paymentMethod: trip.paymentMethod,
  scheduledAt: trip.scheduledAt,
);
```

- [ ] **Step 3: Atualizar `_startTrip` em `schedule_detail_page.dart`**

Localizar o método `_startTrip` em `lib/features/schedules/presentation/pages/schedule_detail_page.dart` e substituir a construção do `ActiveTripData` da mesma forma que no step 2.

- [ ] **Step 4: Atualizar `_statusColor` em `_ScheduleCard` dentro de `schedules_page.dart`**

Localizar o getter `_statusColor` na classe `_ScheduleCard` em `lib/features/schedules/presentation/pages/schedules_page.dart` e substituir:

```dart
Color get _statusColor {
  if (trip.isAwaitingKzApproval) return const Color(0xFFE65100);
  return switch (trip.status) {
    'awaiting_client_confirmation' => AppColors.secondary,
    'awaiting_driver_confirmation' => AppColors.secondary,
    'searching_drivers' => AppColors.secondary,
    'scheduled' => const Color(0xFF2ECC71),
    _ => AppColors.textSecondary,
  };
}
```

- [ ] **Step 5: Verificar análise estática**

```
flutter analyze lib/features/trip/data/models/active_trip_data.dart lib/features/schedules/presentation/pages/schedules_page.dart lib/features/schedules/presentation/pages/schedule_detail_page.dart
```

Esperado: sem erros.

- [ ] **Step 6: Commit**

```
git add lib/features/trip/data/models/active_trip_data.dart lib/features/schedules/presentation/pages/schedules_page.dart lib/features/schedules/presentation/pages/schedule_detail_page.dart
git commit -m "feat(model): adiciona clientId, paymentMethod e scheduledAt em ActiveTripData; corrige cor de status KZ em ScheduleCard"
```

---

## Task 8: PaymentCollectionPanel

**Files:**
- Modify: `lib/features/trip/presentation/widgets/active_trip_panels.dart`
- Create: `test/features/trip/widgets/payment_collection_panel_test.dart`

- [ ] **Step 1: Criar teste falhando**

Criar `test/features/trip/widgets/payment_collection_panel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/active_trip_panels.dart';

void main() {
  group('PaymentCollectionPanel', () {
    Widget build({VoidCallback? onConfirm}) => MaterialApp(
          home: Scaffold(
            body: PaymentCollectionPanel(
              price: 85.0,
              clientName: 'João Silva',
              paymentMethodLabel: 'PIX',
              onConfirm: onConfirm ?? () {},
            ),
          ),
        );

    testWidgets('exibe valor formatado', (tester) async {
      await tester.pumpWidget(build());
      expect(find.text('R\$ 85,00'), findsAtLeastNWidgets(1));
    });

    testWidgets('exibe nome do cliente', (tester) async {
      await tester.pumpWidget(build());
      expect(find.text('de João Silva'), findsOneWidget);
    });

    testWidgets('exibe método de pagamento', (tester) async {
      await tester.pumpWidget(build());
      expect(find.text('pelo PIX'), findsOneWidget);
    });

    testWidgets('chama onConfirm ao tocar no botão', (tester) async {
      var called = false;
      await tester.pumpWidget(build(onConfirm: () => called = true));
      await tester.tap(find.text('Pagamento efetuado'));
      expect(called, isTrue);
    });
  });
}
```

- [ ] **Step 2: Rodar teste para confirmar falha**

```
flutter test test/features/trip/widgets/payment_collection_panel_test.dart
```

Esperado: FAIL — `PaymentCollectionPanel` não existe.

- [ ] **Step 3: Adicionar `PaymentCollectionPanel` em `active_trip_panels.dart`**

Adicionar após o final da classe `ArrivedAtClientPanel` (linha ~334), antes de `_ArrivedDetailRow`:

```dart
class PaymentCollectionPanel extends StatelessWidget {
  final double price;
  final String clientName;
  final String paymentMethodLabel;
  final VoidCallback onConfirm;

  const PaymentCollectionPanel({
    super.key,
    required this.price,
    required this.clientName,
    required this.paymentMethodLabel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding + 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF2ECC71),
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Viagem finalizada!',
            style: TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Cobre',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          Text(
            'R\$ ${price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 28,
              color: Color(0xFF2ECC71),
            ),
          ),
          Text(
            'de $clientName',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          Text(
            'pelo $paymentMethodLabel',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Pagamento efetuado',
                style: TextStyle(fontFamily: 'OutfitBlack', fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar testes**

```
flutter test test/features/trip/widgets/payment_collection_panel_test.dart
```

Esperado: todos PASS.

- [ ] **Step 5: Commit**

```
git add lib/features/trip/presentation/widgets/active_trip_panels.dart test/features/trip/widgets/payment_collection_panel_test.dart
git commit -m "feat(widget): adiciona PaymentCollectionPanel para cobrança ao finalizar viagem"
```

---

## Task 9: TripCompletedPanel aprimorado + AndroidManifest

**Files:**
- Modify: `lib/features/trip/presentation/widgets/active_trip_panels.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Adicionar bloco `<queries>` no AndroidManifest**

Em `android/app/src/main/AndroidManifest.xml`, adicionar logo antes de `<application`:

```xml
<queries>
    <package android:name="com.whatsapp" />
    <package android:name="com.whatsapp.w4b" />
</queries>
```

- [ ] **Step 2: Converter `TripCompletedPanel` para `StatefulWidget` e adicionar novos campos**

Substituir a classe `TripCompletedPanel` inteira em `active_trip_panels.dart`:

```dart
class TripCompletedPanel extends StatefulWidget {
  final double price;
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final ValueChanged<String> onCommentChanged;
  final VoidCallback onReportProblem;
  final VoidCallback onFinish;

  const TripCompletedPanel({
    super.key,
    required this.price,
    required this.rating,
    required this.onRatingChanged,
    required this.onCommentChanged,
    required this.onReportProblem,
    required this.onFinish,
  });

  @override
  State<TripCompletedPanel> createState() => _TripCompletedPanelState();
}

class _TripCompletedPanelState extends State<TripCompletedPanel> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding + 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Avalie o passageiro',
            style: TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => widget.onRatingChanged(i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < widget.rating ? Icons.star : Icons.star_border,
                    color: AppColors.highlight,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 3,
            onChanged: widget.onCommentChanged,
            decoration: InputDecoration(
              hintText: 'Observação sobre o passageiro (opcional)',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF7F7F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.highlight, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: widget.onReportProblem,
            icon: Icon(Icons.flag_outlined, color: Colors.red.shade400, size: 18),
            label: Text(
              'Relatar um problema',
              style: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.highlight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Finalizar',
                style: TextStyle(fontFamily: 'OutfitBlack', fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verificar análise estática**

```
flutter analyze lib/features/trip/presentation/widgets/active_trip_panels.dart
```

Esperado: sem erros.

- [ ] **Step 4: Commit**

```
git add lib/features/trip/presentation/widgets/active_trip_panels.dart android/app/src/main/AndroidManifest.xml
git commit -m "feat(widget): aprimora TripCompletedPanel com comentário e botão de relatar problema"
```

---

## Task 10: ActiveTripPage — fluxo pagamento → feedback

**Files:**
- Modify: `lib/features/trip/presentation/pages/active_trip_page.dart`

- [ ] **Step 1: Adicionar import de `url_launcher`**

No topo de `lib/features/trip/presentation/pages/active_trip_page.dart`, adicionar:

```dart
import 'package:url_launcher/url_launcher.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
```

- [ ] **Step 2: Adicionar campos de estado**

Na classe `_ActiveTripPageState`, adicionar após `bool _isAdvancing = false;`:

```dart
bool _paymentConfirmed = false;
bool _isMarkingPaid = false;
String _feedbackComment = '';
```

- [ ] **Step 3: Adicionar `_onPaymentConfirmed`**

Adicionar método após `_advancePhase`:

```dart
Future<void> _onPaymentConfirmed() async {
  if (_isMarkingPaid) return;
  _isMarkingPaid = true;
  try {
    await _supabase
        .from('trips')
        .update({'is_driver_paied': true})
        .eq('id', widget.trip.id);
    if (mounted) setState(() => _paymentConfirmed = true);
  } catch (e) {
    debugPrint('[KZ-P] _onPaymentConfirmed erro: $e');
  } finally {
    _isMarkingPaid = false;
  }
}
```

- [ ] **Step 4: Adicionar `_onReportProblem`**

```dart
void _onReportProblem() {
  final trip = widget.trip;
  final scheduledAt = trip.scheduledAt;
  final dateStr = scheduledAt != null
      ? '${scheduledAt.day.toString().padLeft(2, '0')}/${scheduledAt.month.toString().padLeft(2, '0')}'
      : '';
  final timeStr = scheduledAt != null
      ? '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}'
      : '';
  final msg = Uri.encodeComponent(
    'Olá, tive um problema com o passageiro ${trip.clientName} na corrida de $dateStr às $timeStr, de ${trip.pickupAddress} para ${trip.destinationAddress}.',
  );
  launchUrl(
    Uri.parse('https://wa.me/5511985889577?text=$msg'),
    mode: LaunchMode.externalApplication,
  );
}
```

- [ ] **Step 5: Adicionar `_onFinish`**

```dart
Future<void> _onFinish() async {
  if (_clientRating > 0 && widget.trip.clientId != null) {
    try {
      await _supabase.from('ratings').insert({
        'trip_id': widget.trip.id,
        'rater_id': _supabase.auth.currentUser!.id,
        'rated_id': widget.trip.clientId,
        'rating': _clientRating.toDouble(),
        if (_feedbackComment.isNotEmpty) 'comment': _feedbackComment,
      });
    } catch (e) {
      debugPrint('[KZ-P] rating insert erro: $e');
    }
  }
  if (mounted) context.go('/home');
}
```

- [ ] **Step 6: Atualizar `build` — bloco da fase `tripCompleted`**

Localizar o bloco que renderiza `TripCompletedPanel` no método `build` (dentro do `else` do `_showArrivedPopup`). Substituir:

```dart
_phase == TripPhase.tripCompleted
    ? TripCompletedPanel(
        price: widget.trip.offeredPrice,
        rating: _clientRating,
        onRatingChanged: (r) => setState(() => _clientRating = r),
        onFinish: () => context.go('/home'),
      )
```

Por:

```dart
_phase == TripPhase.tripCompleted
    ? !_paymentConfirmed
        ? PaymentCollectionPanel(
            price: widget.trip.offeredPrice,
            clientName: widget.trip.clientName,
            paymentMethodLabel: widget.trip.paymentMethodLabel,
            onConfirm: _onPaymentConfirmed,
          )
        : TripCompletedPanel(
            price: widget.trip.offeredPrice,
            rating: _clientRating,
            onRatingChanged: (r) => setState(() => _clientRating = r),
            onCommentChanged: (c) => _feedbackComment = c,
            onReportProblem: _onReportProblem,
            onFinish: _onFinish,
          )
```

Adicionar o import do `PaymentCollectionPanel` caso não esteja já incluído no import de `active_trip_panels.dart`.

- [ ] **Step 7: Verificar análise estática e rodar todos os testes**

```
flutter analyze lib/features/trip/presentation/pages/active_trip_page.dart
flutter test
```

Esperado: sem erros. Todos os testes PASS.

- [ ] **Step 8: Commit final**

```
git add lib/features/trip/presentation/pages/active_trip_page.dart
git commit -m "feat(trip): adiciona tela de cobrança e feedback aprimorado ao finalizar viagem"
```

---

## Verificação final

Após completar todos os tasks, rodar:

```
flutter analyze
flutter test
```

E verificar manualmente no dispositivo/emulador:
1. Aceitar uma solicitação → popup carousel aparece na home imediatamente com status "Aguardando aprovação da KZ"
2. Mudar status no painel admin → popup atualiza para "Aguardando passageiro aceitar" sem trocar de tela
3. Cliente aceitar → popup atualiza para "Agendada"
4. Finalizar viagem → tela de cobrança aparece com valor, nome e método de pagamento
5. Tocar "Pagamento efetuado" → Supabase marca `is_driver_paied = true` → tela de feedback aparece
6. Tocar "Relatar um problema" → WhatsApp abre com mensagem pré-preenchida
7. Tocar "Finalizar" → rating salvo → navega para home
