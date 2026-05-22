import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Reproduz instruções de navegação usando os arquivos de voz OsmAnd (pt-br).
/// Os arquivos .ogg ficam em assets/audio/voice/pt-br/
class NavigationAudioService {
  static final NavigationAudioService _instance = NavigationAudioService._();
  factory NavigationAudioService() => _instance;
  NavigationAudioService._();

  final AudioPlayer _player = AudioPlayer();
  bool _muted = false;
  int _playToken = 0;

  bool get isMuted => _muted;

  // Mapeamento de manobras do Google Directions → chave OsmAnd
  static const Map<String, String> _googleToOsmand = {
    'turn-left': 'left',
    'turn-right': 'right',
    'turn-slight-left': 'left_sl',
    'turn-slight-right': 'right_sl',
    'turn-sharp-left': 'left_sh',
    'turn-sharp-right': 'right_sh',
    'keep-left': 'left_keep',
    'keep-right': 'right_keep',
    'straight': 'go_ahead',
    'uturn-left': 'make_uturn',
    'uturn-right': 'make_uturn',
    'roundabout-left': 'roundabout',
    'roundabout-right': 'roundabout',
    'fork-left': 'left_bear',
    'fork-right': 'right_bear',
    'ramp-left': 'left',
    'ramp-right': 'right',
    'merge': 'go_ahead',
    'ferry': 'go_ahead',
    'ferry-train': 'go_ahead',
  };

  // Valores de distância disponíveis em metros (arquivos OsmAnd)
  static const List<int> _meterValues = [
    25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95,
    100, 110, 120, 130, 140, 150, 200, 250, 300, 350, 400, 450,
    500, 550, 600, 650, 700, 750, 800, 850, 900, 950,
  ];

  void toggleMute() {
    _muted = !_muted;
    if (_muted) stop();
  }

  Future<void> stop() async {
    _playToken++;
    try { await _player.stop(); } catch (_) {}
  }

  /// Anuncia uma manobra com prefixo de distância.
  /// Ex: "Em 200 metros, vire à esquerda"
  Future<void> speakManeuver({
    String? maneuver,
    double distanceMeters = 0,
  }) async {
    if (_muted) return;
    final osmKey = _googleToOsmand[maneuver ?? ''] ?? 'go_ahead';
    final files = [
      ..._distanceFiles(distanceMeters),
      '$osmKey.ogg',
    ];
    await _playSequence(files);
  }

  /// Anuncia que o destino foi alcançado.
  Future<void> speakReachedDestination() async {
    if (_muted) return;
    await _playSequence(['reached_destination.ogg']);
  }

  Future<void> _playSequence(List<String> files) async {
    await _player.stop();
    final token = ++_playToken;

    for (final file in files) {
      if (token != _playToken || _muted) return;
      try {
        await _player.play(AssetSource('audio/voice/pt-br/$file'));
        await Future.any([
          _player.onPlayerComplete.first,
          Future.delayed(const Duration(seconds: 10)),
        ]);
      } catch (e) {
        debugPrint('[NAudio] erro ao tocar $file: $e');
      }
    }
  }

  List<String> _distanceFiles(double meters) {
    if (meters < 20) return [];

    if (meters < 1000) {
      final nearest = _meterValues.reduce((a, b) =>
          (a - meters).abs() < (b - meters).abs() ? a : b);
      return ['in.ogg', '$nearest.ogg', 'meters.ogg'];
    }

    // Km — disponíveis: 1-9.ogg
    final km = (meters / 1000).round().clamp(1, 9);
    return ['in.ogg', '$km.ogg', 'kilometers.ogg'];
  }

  // Compatibilidade: speak() genérico (somente se necessário em outras telas)
  Future<void> speak(String text) async {
    if (_muted) return;
    debugPrint('[NAudio] speak() genérico chamado com: $text');
  }
}

/// Calcula o heading da bússola a partir de acelerômetro e magnetômetro.
/// Usa compensação de inclinação para funcionar com o celular em qualquer ângulo.
double computeCompassHeading(List<double> accel, List<double> mag) {
  final ax = accel[0], ay = accel[1], az = accel[2];
  final mx = mag[0], my = mag[1], mz = mag[2];

  // Ângulos de inclinação do dispositivo
  final pitch = math.atan2(ay, math.sqrt(ax * ax + az * az));
  final roll  = math.atan2(-ax, az);

  // Heading compensado para inclinação do dispositivo
  final xh = mx * math.cos(pitch) + mz * math.sin(pitch);
  final yh = mx * math.sin(roll) * math.sin(pitch) +
             my * math.cos(roll) -
             mz * math.sin(roll) * math.cos(pitch);

  double heading = math.atan2(-yh, xh) * 180 / math.pi;
  return (heading + 360) % 360;
}
