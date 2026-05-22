import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class TripAudioService {
  final AudioPlayer _loopPlayer = AudioPlayer();
  final AudioPlayer _oneShotPlayer = AudioPlayer();

  Future<void> playNotificationLoop() async {
    try {
      await _loopPlayer.setReleaseMode(ReleaseMode.loop);
      await _loopPlayer.play(AssetSource('audio/trip_notification.wav'));
    } catch (e) {
      debugPrint('[TripAudio] playNotificationLoop erro: $e');
    }
  }

  Future<void> stopNotification() async {
    try {
      await _loopPlayer.stop();
    } catch (e) {
      debugPrint('[TripAudio] stopNotification erro: $e');
    }
  }

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

  Future<void> dispose() async {
    await _loopPlayer.dispose();
    await _oneShotPlayer.dispose();
  }
}
