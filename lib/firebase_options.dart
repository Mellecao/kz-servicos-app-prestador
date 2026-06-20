// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase web não configurado para kz-notifica.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('Firebase iOS não configurado para kz-notifica.');
      case TargetPlatform.macOS:
        throw UnsupportedError('Firebase macOS não configurado para kz-notifica.');
      case TargetPlatform.windows:
        throw UnsupportedError('Firebase Windows não configurado para kz-notifica.');
      default:
        throw UnsupportedError('Plataforma não suportada.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCGoTuYhkDEkq_DWXg7_kH2sfyRIPpnf3Y',
    appId: '1:332846119947:android:02998fa1b10d9beefa5b0e',
    messagingSenderId: '332846119947',
    projectId: 'kz-notifica',
    storageBucket: 'kz-notifica.firebasestorage.app',
  );
}
