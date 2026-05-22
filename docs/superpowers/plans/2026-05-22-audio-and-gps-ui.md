# Áudio de Corrida + Botões GPS — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar sons de notificação/aceite/pagamento e botões de mudo e re-centralizar câmera na tela de corrida ativa.

**Architecture:** `TripAudioService` (plain class, audioplayers) para sons WAV; `NavigationAudioService` ganha toggle de mudo; `HomePage` toca ringtone em loop enquanto há solicitação; `ActiveTripPage` recebe botões de mudo e re-centro na coluna direita do Stack GPS.

**Tech Stack:** Flutter, audioplayers ^6.0.0, flutter_tts (existing).

---

## Mapa de arquivos

| Arquivo | Ação |
|---|---|
| `pubspec.yaml` | Modificar — adicionar `audioplayers: ^6.0.0` e `- assets/audio/` |
| `lib/core/services/trip_audio_service.dart` | Criar |
| `lib/core/services/navigation_audio_service.dart` | Modificar — mute toggle |
| `lib/features/home/presentation/pages/home_page.dart` | Modificar — ringtone em loop + accept sound |
| `lib/features/trip/presentation/pages/active_trip_page.dart` | Modificar — payment sound + mute button + re-center button |

---

## Task 1: pubspec.yaml — audioplayers + declaração de assets/audio/

**Files:**
- Modify: `pubspec.yaml`

### Contexto

O `pubspec.yaml` atual já tem `flutter_tts: ^4.2.0` e `url_launcher: ^6.3.2` mas **não** tem `audioplayers` e **não** declara `assets/audio/`. Os três arquivos `.wav` já existem em `assets/audio/` mas serão ignorados pelo Flutter em runtime enquanto o bloco `assets` não os incluir.

### Steps

- [ ] **Step 1.1: Adicionar dependência audioplayers**

No bloco `dependencies:` do `pubspec.yaml`, logo após `flutter_tts: ^4.2.0`, adicionar:

```yaml
  audioplayers: ^6.0.0
```

O bloco `dependencies` resultante (trecho relevante) deve ficar:

```yaml
  url_launcher: ^6.3.2
  flutter_tts: ^4.2.0
  audioplayers: ^6.0.0
  supabase_flutter: ^2.8.0
```

- [ ] **Step 1.2: Declarar assets/audio/ no bloco flutter.assets**

No bloco `flutter: > assets:` do `pubspec.yaml`, logo após `- assets/animations/`, adicionar:

```yaml
    - assets/audio/
```

O bloco `flutter.assets` resultante deve ficar:

```yaml
  assets:
    - assets/map_style.json
    - assets/images/
    - assets/images/SVG/
    - assets/animations/
    - assets/audio/
```

- [ ] **Step 1.3: Instalar dependência**

```bash
flutter pub get
```

Verificar que a saída não contém erros. O pacote `audioplayers 6.x` é compatível com Dart SDK `^3.0.0`, portanto satisfaz o `sdk: ^3.11.4` declarado.

- [ ] **Step 1.4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat(audio): adiciona audioplayers e declara assets/audio/ no pubspec"
```

---

## Task 2: TripAudioService — plain class com loop e one-shot

**Files:**
- Create: `lib/core/services/trip_audio_service.dart`

### Contexto

`audioplayers` expõe a classe `AudioPlayer`. Para reprodução em loop usa-se `player.setReleaseMode(ReleaseMode.loop)` antes de `player.play(...)`. Para one-shot usa-se `ReleaseMode.release`. O path de `AssetSource` **não** inclui o prefixo `assets/` — o Flutter stripa automaticamente ao compilar; portanto `AssetSource('audio/trip_notification.wav')` é correto.

Dois players separados (`_loopPlayer` e `_oneShotPlayer`) garantem que o ringtone de loop e o one-shot de aceite/pagamento nunca se interrompam mutuamente no pior caso de timing, e que `stopNotification()` não aborte um som de aceite já iniciado.

### Steps

- [ ] **Step 2.1: Criar o arquivo**

Criar `lib/core/services/trip_audio_service.dart` com o seguinte conteúdo:

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Serviço de áudio WAV para sons de solicitação de corrida.
///
/// NÃO é singleton — cada widget cria sua própria instância e chama
/// [dispose] no seu `State.dispose()`.
class TripAudioService {
  final AudioPlayer _loopPlayer = AudioPlayer();
  final AudioPlayer _oneShotPlayer = AudioPlayer();

  /// Toca [trip_notification.wav] em loop infinito.
  /// Idempotente: chamar novamente reinicia o loop do início.
  Future<void> playNotificationLoop() async {
    try {
      await _loopPlayer.setReleaseMode(ReleaseMode.loop);
      await _loopPlayer.play(AssetSource('audio/trip_notification.wav'));
    } catch (e) {
      debugPrint('[TripAudio] playNotificationLoop erro: $e');
    }
  }

  /// Para o loop de notificação.
  Future<void> stopNotification() async {
    try {
      await _loopPlayer.stop();
    } catch (e) {
      debugPrint('[TripAudio] stopNotification erro: $e');
    }
  }

  /// Toca [trip_accept_buttom_active.wav] uma vez.
  Future<void> playAccept() async {
    try {
      await _oneShotPlayer.setReleaseMode(ReleaseMode.release);
      await _oneShotPlayer.play(
        AssetSource('audio/trip_accept_buttom_active.wav'),
      );
    } catch (e) {
      debugPrint('[TripAudio] playAccept erro: $e');
    }
  }

  /// Toca [Payment_buttom_active.wav] uma vez.
  Future<void> playPayment() async {
    try {
      await _oneShotPlayer.setReleaseMode(ReleaseMode.release);
      await _oneShotPlayer.play(
        AssetSource('audio/Payment_buttom_active.wav'),
      );
    } catch (e) {
      debugPrint('[TripAudio] playPayment erro: $e');
    }
  }

  /// Libera ambos os players. Deve ser chamado no dispose do widget.
  Future<void> dispose() async {
    await _loopPlayer.dispose();
    await _oneShotPlayer.dispose();
  }
}
```

- [ ] **Step 2.2: Verificar análise estática**

```bash
flutter analyze lib/core/services/trip_audio_service.dart
```

Esperado: sem erros.

- [ ] **Step 2.3: Commit**

```bash
git add lib/core/services/trip_audio_service.dart
git commit -m "feat(audio): cria TripAudioService com loop e one-shot via audioplayers"
```

---

## Task 3: NavigationAudioService — mute toggle

**Files:**
- Modify: `lib/core/services/navigation_audio_service.dart`

### Contexto

O arquivo atual é um singleton com `speak(String)` e `stop()` sem nenhum mecanismo de mudo. Adicionar:
1. Campo privado `bool _muted = false`
2. Getter público `bool get isMuted => _muted`
3. Método `void toggleMute()` — inverte `_muted`; se mutando, chama `stop()` para interromper fala em curso
4. Guard no início de `speak()`: `if (_muted) return`

### Steps

- [ ] **Step 3.1: Substituir conteúdo do arquivo**

Substituir o conteúdo inteiro de `lib/core/services/navigation_audio_service.dart` por:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class NavigationAudioService {
  static final NavigationAudioService _instance = NavigationAudioService._();
  factory NavigationAudioService() => _instance;
  NavigationAudioService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _muted = false;

  bool get isMuted => _muted;

  Future<void> _init() async {
    if (_initialized) return;
    try {
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _initialized = true;
    } catch (e) {
      debugPrint('[NavigationAudio] init erro: $e');
    }
  }

  /// Liga/desliga o mudo do TTS.
  /// Ao mutar, interrompe imediatamente qualquer fala em curso.
  void toggleMute() {
    _muted = !_muted;
    if (_muted) stop();
  }

  Future<void> speak(String text) async {
    if (_muted) return;
    await _init();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[NavigationAudio] speak erro: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
```

- [ ] **Step 3.2: Verificar análise estática**

```bash
flutter analyze lib/core/services/navigation_audio_service.dart
```

Esperado: sem erros.

- [ ] **Step 3.3: Commit**

```bash
git add lib/core/services/navigation_audio_service.dart
git commit -m "feat(audio): adiciona toggle de mudo ao NavigationAudioService"
```

---

## Task 4: HomePage — ringtone em loop + accept sound

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart`

### Contexto

A `HomePage` já tem:
- `bool _showRequest` — verdadeiro enquanto o `TripRequestCard` está visível
- `_onAccept(double price)` — chamado pelo botão de aceitar
- `_onReject()` — chama `rejectCandidate` e depois `_advanceToNextRequest`
- `_onToggleOnline(bool value)` — ao ficar offline, `_showRequest = false`
- `_advanceToNextRequest()` — seta `_showRequest = false`

Regras de áudio:
- `playNotificationLoop()` → sempre que `_showRequest` passa a `true`
- `stopNotification()` → ao aceitar (imediatamente, antes do await Supabase), ao rejeitar, ao ir offline, no `dispose()`
- `playAccept()` → na entrada de `_onAccept`, **antes** do `await _tripService.acceptCandidate(...)` (feedback imediato ao toque)

### Steps

- [ ] **Step 4.1: Adicionar import**

No topo de `home_page.dart`, após os imports existentes:

```dart
import 'package:kz_servicos_prestador/core/services/trip_audio_service.dart';
```

- [ ] **Step 4.2: Declarar campo no State**

Na classe `_HomePageState`, após `final DirectionsService _directionsService = DirectionsService();`:

```dart
  final TripAudioService _tripAudio = TripAudioService();
```

- [ ] **Step 4.3: Iniciar ringtone nos pontos onde _showRequest → true**

Adicionar `_tripAudio.playNotificationLoop();` imediatamente após cada bloco que seta `_showRequest = true`.

**Ponto A — `_load()`, após o setState que seta `_showRequest = isAvailable`:**

```dart
      setState(() {
        _requests = trips;
        _currentRequestIndex = 0;
        _showRequest = isAvailable;
      });
      if (isAvailable) {
        _fetchRouteForCurrentRequest();
        _tripAudio.playNotificationLoop();   // ADD
      }
```

**Ponto B — `_showNextRequest()`, após `setState(() => _showRequest = true)`:**

```dart
  void _showNextRequest() {
    if (!mounted || !_isOnline || _requests.isEmpty) return;
    setState(() => _showRequest = true);
    _fetchRouteForCurrentRequest();
    _tripAudio.playNotificationLoop();       // ADD
  }
```

- [ ] **Step 4.4: Parar ringtone e tocar accept em _onAccept**

Localizar o início do método `_onAccept`:

```dart
  Future<void> _onAccept(double price) async {
    final driverProfileId = AuthState.driverProfileId;
    if (driverProfileId == null) return;
    final request = _requests[_currentRequestIndex];
    final ok = await _tripService.acceptCandidate(
```

Modificar para:

```dart
  Future<void> _onAccept(double price) async {
    final driverProfileId = AuthState.driverProfileId;
    if (driverProfileId == null) return;
    _tripAudio.stopNotification();           // ADD — para imediatamente
    unawaited(_tripAudio.playAccept());      // ADD — toca accept sem aguardar
    final request = _requests[_currentRequestIndex];
    final ok = await _tripService.acceptCandidate(
```

`unawaited` está disponível via `dart:async` (import já presente na linha 1 do arquivo).

- [ ] **Step 4.5: Parar ringtone em _onReject**

Localizar:

```dart
  Future<void> _onReject() async {
    final observation = await _showRejectDialog();
    if (observation == null) return;
    final driverProfileId = AuthState.driverProfileId;
```

Modificar para:

```dart
  Future<void> _onReject() async {
    final observation = await _showRejectDialog();
    if (observation == null) return;
    _tripAudio.stopNotification();           // ADD
    final driverProfileId = AuthState.driverProfileId;
```

- [ ] **Step 4.6: Parar ringtone ao ir offline**

No método `_onToggleOnline`, logo após o `setState` que seta `_showRequest = false`:

```dart
    setState(() {
      _isOnline = value;
      _currentRequestIndex = 0;
      _showRequest = false;
      _polylines = {};
      _markers = {};
    });
    _tripAudio.stopNotification();           // ADD
```

- [ ] **Step 4.7: Dispose do serviço**

No `dispose()` da `_HomePageState`, após `_invitationsChannel?.unsubscribe();`:

```dart
  @override
  void dispose() {
    _stopPulseAnimation();
    _requestTimer?.cancel();
    _invitationsChannel?.unsubscribe();
    _tripAudio.stopNotification();           // ADD
    unawaited(_tripAudio.dispose());         // ADD
    AuthState.scheduledTrips?.removeListener(_onScheduledTripsChanged);
    super.dispose();
  }
```

- [ ] **Step 4.8: Verificar análise estática**

```bash
flutter analyze lib/features/home/presentation/pages/home_page.dart
```

Esperado: sem erros.

- [ ] **Step 4.9: Commit**

```bash
git add lib/features/home/presentation/pages/home_page.dart
git commit -m "feat(audio): ringtone em loop ao receber solicitação e som de aceite ao confirmar"
```

---

## Task 5: ActiveTripPage — payment sound + mute button + re-center button

**Files:**
- Modify: `lib/features/trip/presentation/pages/active_trip_page.dart`

### Contexto

O `build()` atual tem um `Stack` com botão de navegação externa em `right: 16, bottom: 220`. Adicionar:
- `right: 16, bottom: 332` — botão de mudo (sempre visível em GPS mode)
- `right: 16, bottom: 276` — botão de re-centro (visível apenas quando `_cameraFollowing == false`)

O botão de re-centro requer detectar quando o usuário move a câmera manualmente. Estratégia:
- `_isCameraAnimating = true` antes de qualquer `animateCamera()`
- `onCameraIdle` → `_isCameraAnimating = false`
- `onCameraMoveStarted` → se `!_isCameraAnimating && _phase.isGpsMode` → `_cameraFollowing = false`

`_updateCamera()` guarda com `!_cameraFollowing` para suspender auto-follow.

### Steps

- [ ] **Step 5.1: Adicionar import de TripAudioService**

No topo de `active_trip_page.dart`, após os imports existentes:

```dart
import 'package:kz_servicos_prestador/core/services/trip_audio_service.dart';
```

- [ ] **Step 5.2: Declarar campos de estado**

Na classe `_ActiveTripPageState`, após `bool _isFinishing = false;`:

```dart
  // Câmera GPS
  bool _cameraFollowing = true;
  bool _isCameraAnimating = false;

  // Áudio WAV
  final TripAudioService _tripAudio = TripAudioService();
```

- [ ] **Step 5.3: Atualizar dispose**

No `dispose()` existente, antes de `super.dispose()`:

```dart
  @override
  void dispose() {
    _audioService.stop();
    _positionStream?.cancel();
    _gpsPublishTimer?.cancel();
    _pulseAnimator?.dispose();
    unawaited(_tripAudio.dispose());         // ADD
    super.dispose();
  }
```

`unawaited` está disponível via `dart:async` (import já presente).

- [ ] **Step 5.4: Modificar _updateCamera para respeitar _cameraFollowing**

```dart
  void _updateCamera() {
    if (_mapController == null || !_phase.isGpsMode || !_cameraFollowing) return;
    _isCameraAnimating = true;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(
        target: _currentLocation,
        zoom: 17.5,
        tilt: 65,
        bearing: _currentHeading,
      )),
    );
  }
```

- [ ] **Step 5.5: Adicionar _recenterCamera**

Logo após `_updateCamera()`:

```dart
  void _recenterCamera() {
    setState(() => _cameraFollowing = true);
    _updateCamera();
  }
```

- [ ] **Step 5.6: Setar _isCameraAnimating nos outros animateCamera**

Procurar todas as ocorrências de `_mapController?.animateCamera` ou `_mapController!.animateCamera` fora de `_updateCamera()` (geralmente em `_advancePhase`). Antes de cada uma, adicionar:

```dart
_isCameraAnimating = true;
_mapController?.animateCamera(...);
```

- [ ] **Step 5.7: Adicionar onCameraMoveStarted e onCameraIdle ao GoogleMap**

No `build()`, localizar o widget `GoogleMap(...)`. Adicionar após `zoomControlsEnabled: false,`:

```dart
            onCameraMoveStarted: () {
              if (!_isCameraAnimating && _phase.isGpsMode) {
                setState(() => _cameraFollowing = false);
              }
            },
            onCameraIdle: () {
              _isCameraAnimating = false;
            },
```

- [ ] **Step 5.8: Adicionar payment sound em _onPaymentConfirmed**

No `_onPaymentConfirmed()`, logo após o `update` do Supabase ter sucesso e antes do `setState`:

```dart
      await _supabase
          .from('trips')
          .update({'is_driver_paied': true})
          .eq('id', widget.trip.id);
      unawaited(_tripAudio.playPayment());   // ADD
      if (mounted) setState(() => _paymentConfirmed = true);
```

- [ ] **Step 5.9: Adicionar botões de mudo e re-centro ao Stack**

No `build()`, localizar o bloco do botão de navegação externa existente:

```dart
          if (_phase.isActive)
            Positioned(
              right: 16,
              bottom: 220,
              child: CircleButton(
                icon: Icons.open_in_new_rounded,
                onTap: () => showExternalNavSheet(context, _navTarget),
              ),
            ),
```

Adicionar **antes** desse bloco os dois novos botões:

```dart
          // Botão mudo — só em GPS mode
          if (_phase.isGpsMode)
            Positioned(
              right: 16,
              bottom: 332,
              child: CircleButton(
                icon: _audioService.isMuted
                    ? Icons.volume_off
                    : Icons.volume_up,
                onTap: () {
                  _audioService.toggleMute();
                  setState(() {});
                },
              ),
            ),
          // Botão re-centro — só em GPS mode quando câmera perdeu o follow
          if (_phase.isGpsMode && !_cameraFollowing)
            Positioned(
              right: 16,
              bottom: 276,
              child: CircleButton(
                icon: Icons.my_location,
                onTap: _recenterCamera,
              ),
            ),
          // Botão navegação externa (existente)
          if (_phase.isActive)
            Positioned(
              right: 16,
              bottom: 220,
              child: CircleButton(
                icon: Icons.open_in_new_rounded,
                onTap: () => showExternalNavSheet(context, _navTarget),
              ),
            ),
```

- [ ] **Step 5.10: Verificar análise estática e testes**

```bash
flutter analyze lib/features/trip/presentation/pages/active_trip_page.dart
flutter test
```

Esperado: sem erros de análise. 35 testes de projeto passam; `widget_test.dart` (counter) falha como antes (pré-existente, irrelevante).

- [ ] **Step 5.11: Commit**

```bash
git add lib/features/trip/presentation/pages/active_trip_page.dart
git commit -m "feat(trip): som de pagamento, botão mudo e botão re-centro câmera na corrida ativa"
```

---

## Notas de implementação

### Por que TripAudioService é plain class, não singleton

`HomePage` e `ActiveTripPage` são páginas completamente independentes no GoRouter. Se fosse singleton, o `dispose()` de uma página liberaria os players da outra. Com instâncias separadas, cada página tem controle total sobre seu ciclo de vida de áudio.

### unawaited em playAccept, playPayment e dispose

Os métodos `playAccept()`, `playPayment()` e `dispose()` são `Future<void>`. Como não precisamos aguardar o término, usamos `unawaited()` para explicitar o fire-and-forget e satisfazer o lint `unawaited_futures`.

### Posicionamento dos botões (coluna direita GPS)

```
bottom: 332  →  mudo (sempre visível em GPS mode)
bottom: 276  →  re-centro (condicional: só quando !_cameraFollowing)
bottom: 220  →  navegação externa (existente)
```

Gap de 56 px entre cada botão = 42 px de altura do `CircleButton` + 14 px de espaço visual.

### _isCameraAnimating e condition race

`_isCameraAnimating` é `bool` simples sem `setState` — é flag interna de controle que não dispara rebuild. `onCameraIdle` sempre o limpa, garantindo que mesmo em cenário de erro de animação o estado não fique travado.
