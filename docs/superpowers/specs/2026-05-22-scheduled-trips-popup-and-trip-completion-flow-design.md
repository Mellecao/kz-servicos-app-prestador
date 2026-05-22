# Design: Popup de Corridas Agendadas + Fluxo de Conclusão de Viagem

**Data:** 2026-05-22  
**Status:** Aprovado

---

## Contexto

Conjunto de melhorias no app do motorista envolvendo:
1. Popup carousel de corridas aceitas/agendadas na home (acima do menu inferior)
2. Atualizações em tempo real de status sem trocar de tela
3. Tela de cobrança ao finalizar corrida (antes do feedback)
4. Feedback aprimorado com comentário + botão de relatar problema via WhatsApp

---

## 1. Modelo de Dados — `TripData`

### Mudanças
- Adicionar campo `final String? candidateStatus`
- Atualizar `TripData.fromMap()` para ler `candidate_status` do mapa quando disponível
- Atualizar getter `statusLabel` com lógica de perspectiva do motorista:

| trip.status | candidateStatus | Label exibido |
|---|---|---|
| `searching_drivers` | `accepted` | "Aguardando aprovação da KZ" |
| `awaiting_client_confirmation` | qualquer | "Aguardando passageiro aceitar" |
| `scheduled` | qualquer | "Agendada" |
| outros | — | labels existentes |

### `TripService.getDriverAcceptedCandidacies()`
- Incluir `status` da linha de candidato no select para popular `candidateStatus` no `TripData` retornado

---

## 2. `ScheduledTripsService`

**Arquivo:** `lib/core/services/scheduled_trips_service.dart`  
**Tipo:** `ChangeNotifier` singleton

### Estado
```dart
List<TripData> trips = [];
bool loading = false;
RealtimeChannel? _candidatesChannel;
RealtimeChannel? _tripsChannel;
```

### Métodos
- `Future<void> load()` — busca em paralelo:
  - `TripService.getDriverAcceptedCandidacies(driverProfileId)` — candidaturas aceitas aguardando KZ/cliente
  - `TripService.getDriverScheduledTrips(driverProfileId)` — trips com status `scheduled`
  - Merge com deduplicação por `tripId` (uma trip pode aparecer nas duas queries), ordena por `scheduledAt`, chama `notifyListeners()`
- `void subscribe()` — dois canais Realtime:
  - Canal `trip_driver_candidates` filtrado por `driver_profile_id` → `PostgresChangeEvent.all` → `load()`
  - Canal `trips` filtrado por `driver_profile_id` → `PostgresChangeEvent.update` → `load()`
- `void unsubscribe()` — cancela os dois canais
- `@override void dispose()` — chama `unsubscribe()`

### Ciclo de vida
- Campo estático em `AuthState`: `static ScheduledTripsService? scheduledTrips`
- Instanciado em `AuthState.login()` quando `providerType == ProviderType.driver`
- Descartado e nullado em `AuthState.logout()`
- `HomePage` consome via `ListenableBuilder`

---

## 3. `ScheduledTripsCarousel` widget

**Arquivo:** `lib/features/home/presentation/widgets/scheduled_trips_carousel.dart`

### Props
```dart
final List<TripData> trips;
final void Function(TripData) onTap;
```

### Estrutura
- `ConstrainedBox(maxHeight: MediaQuery.of(context).size.height * 0.45)`
- `Container` com `borderRadius: BorderRadius.vertical(top: Radius.circular(14))` e sombra superior
- `PageController` interno com `PageView(physics: BouncingScrollPhysics())`
- Listener no `PageController` para atualizar dot ativo
- Dots de paginação:
  - Ativo: pílula `width: 18, height: 5, color: AppColors.highlight`
  - Inativo: círculo `6x6, color: Colors.grey.shade300`
  - Animados com `AnimatedContainer`

### Conteúdo de cada card (`_ScheduledTripCard`)
```
Row: [Nome cliente]                    [Badge status]
     [DD/MM · HH:mm · N pax]          [R$ valor]

RouteColumn: ● Origem (ellipsis)
             | 
             ● Destino (ellipsis)

Row: 💳 [método pagamento]  |  👜 N mala(s)   (se houver)

Dots paginação (centralizados)
```

### Cores do badge por status
| Status | Texto | Fundo |
|---|---|---|
| "Aguardando aprovação da KZ" | `#E65100` | `#FFF3E0` |
| "Aguardando passageiro aceitar" | `AppColors.secondary` | secondary 10% |
| "Agendada" | `Color(0xFF27AE60)` | verde 10% |

### Posicionamento na `HomePage`
```dart
// No Stack, entre mapa e bottom nav:
if (scheduledTrips.isNotEmpty)
  Positioned(
    bottom: bottomPadding + 72,
    left: 0,
    right: 0,
    child: ScheduledTripsCarousel(
      trips: scheduledTrips,
      onTap: (trip) => context.push('/schedule-detail', extra: trip),
    ),
  ),
```

O `TripRequestCard` de convites pendentes continua existindo. Quando ambos estão visíveis, o carousel sobe proporcionalmente (ajustar `bottom` do location FAB).

---

## 4. Integração na `HomePage`

- Remover lógica de subscriptions de corridas agendadas (se houver duplicação)
- Adicionar `ListenableBuilder` consuming `ScheduledTripsService`
- O `_onAccept()` existente já funciona — após aceitar, a subscription do service detecta a mudança e o popup aparece automaticamente via `notifyListeners()`

---

## 5. Fluxo de Conclusão da Viagem — `ActiveTripPage`

### Novo estado em `_ActiveTripPageState`
```dart
bool _paymentConfirmed = false;
int _clientRating = 0;
String _feedbackComment = '';
```

### Lógica de exibição quando `_phase == TripPhase.tripCompleted`
```dart
_paymentConfirmed == false
  → PaymentCollectionPanel(...)
  
_paymentConfirmed == true
  → TripCompletedPanel(...)
```

### `_onPaymentConfirmed()`
```dart
Future<void> _onPaymentConfirmed() async {
  await _supabase
    .from('trips')
    .update({'is_driver_paied': true})
    .eq('id', widget.trip.id);
  if (mounted) setState(() => _paymentConfirmed = true);
}
```

---

## 6. `PaymentCollectionPanel` (novo widget)

**Arquivo:** `lib/features/trip/presentation/widgets/active_trip_panels.dart` (adicionar ao existente)

### Props
```dart
final double price;
final String clientName;
final String paymentMethod; // label já formatado
final VoidCallback onConfirm;
```

### Layout
```
✅ ícone check_circle (verde, 48px)

"Viagem finalizada!"  (OutfitBlack, 20px)

"Cobre"
"R$ 85,00"           (OutfitBlack, 28px, verde)
"de João Silva"      (14px, textSecondary)
"pelo PIX"           (14px, textSecondary)

[ Pagamento efetuado ]  (verde, altura 52, largura total)
```

---

## 7. `TripCompletedPanel` aprimorado

**Modificações no widget existente:**

### Novas props
```dart
final ValueChanged<String> onCommentChanged;
final VoidCallback onReportProblem;
```

### Adições ao layout (após as estrelas)
1. `TextField` com hint "Observação sobre o passageiro (opcional)", `maxLines: 3`, fundo `#F7F7F8`
2. `TextButton` "Relatar um problema" (vermelho, ícone `Icons.flag_outlined`)
3. Botão "Finalizar" (amarelo `AppColors.highlight`) — substitui "Voltar ao início"

### URL do WhatsApp
```
https://wa.me/5511985889577?text=Olá%2C+tive+um+problema+com+o+passageiro+[Nome]+na+corrida+de+[DD%2FMM]+às+[HH%3Amm]%2C+de+[Origem]+para+[Destino].
```
Aberto via `url_launcher` → `launchUrl(uri, mode: LaunchMode.externalApplication)`.

### `_onFinish()` em `ActiveTripPage`
```dart
// Salva rating + comentário
if (_clientRating > 0) {
  await _supabase.from('ratings').insert({
    'trip_id': widget.trip.id,
    'score': _clientRating,
    'comment': _feedbackComment.isEmpty ? null : _feedbackComment,
    'rated_by': 'driver',
  });
}
context.go('/home');
```

---

## 8. `ActiveTripData` — novos campos

Adicionar ao model para suportar tela de cobrança, rating e mensagem WhatsApp:

```dart
final String? clientId;        // rated_id no insert de ratings
final String? paymentMethod;   // ex: 'pix', 'cash', 'credit'
final DateTime? scheduledAt;   // para mensagem WhatsApp
```

Getter computado:
```dart
String get paymentMethodLabel => switch (paymentMethod) {
  'pix' => 'PIX', 'debit' => 'Débito', 'credit' => 'Crédito',
  'cash' => 'Dinheiro', 'billing' => 'Faturamento', _ => paymentMethod ?? '-',
};
```

Passar esses campos na construção do `ActiveTripData` a partir de `TripData` (em `SchedulesPage._startTrip()` e `ScheduleDetailPage._startTrip()`).

---

## 9. Insert de rating corrigido

Schema confirmado da tabela `ratings`: `trip_id`, `rater_id`, `rated_id`, `rating` (DECIMAL 1-5), `comment`.

```dart
if (_clientRating > 0) {
  await _supabase.from('ratings').insert({
    'trip_id': widget.trip.id,
    'rater_id': AuthState.userId,          // motorista
    'rated_id': widget.trip.clientId,      // passageiro
    'rating': _clientRating.toDouble(),
    if (_feedbackComment.isNotEmpty) 'comment': _feedbackComment,
  });
}
```

---

## 10. Dependências

- `url_launcher: ^6.3.2` — **já presente** no `pubspec.yaml`
- Permissão Android: adicionar bloco `<queries>` no `AndroidManifest.xml` para WhatsApp.

---

## Arquivos a criar/modificar

| Arquivo | Ação |
|---|---|
| `lib/core/models/trip_data.dart` | Modificar — adicionar `candidateStatus`, atualizar `statusLabel` |
| `lib/core/services/trip_service.dart` | Modificar — incluir `candidate_status` no select de `getDriverAcceptedCandidacies` |
| `lib/core/services/scheduled_trips_service.dart` | **Criar** |
| `lib/features/home/presentation/widgets/scheduled_trips_carousel.dart` | **Criar** |
| `lib/features/home/presentation/pages/home_page.dart` | Modificar — integrar carousel via `ListenableBuilder` |
| `lib/features/trip/presentation/widgets/active_trip_panels.dart` | Modificar — adicionar `PaymentCollectionPanel`, aprimorar `TripCompletedPanel` |
| `lib/features/trip/presentation/pages/active_trip_page.dart` | Modificar — `_paymentConfirmed`, `_onPaymentConfirmed()`, `_onFinish()` |
| `lib/features/trip/data/models/active_trip_data.dart` | Modificar — adicionar `clientId`, `paymentMethod`, `scheduledAt` |
| `lib/features/schedules/presentation/pages/schedules_page.dart` | Modificar — passar novos campos ao construir `ActiveTripData` |
| `lib/features/schedules/presentation/pages/schedule_detail_page.dart` | Modificar — passar novos campos ao construir `ActiveTripData` |
| `lib/core/services/auth_state.dart` | Modificar — campo estático `scheduledTrips`, init/dispose no login/logout |
| `pubspec.yaml` | Sem mudança — `url_launcher` já presente |
| `android/app/src/main/AndroidManifest.xml` | Modificar — adicionar `<queries>` para WhatsApp |
