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
