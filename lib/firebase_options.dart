// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError('Plataforma não suportada.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDrcWCbFgo529ZSe6r1-M83mS6LQ3o7klo',
    appId: '1:273099983865:android:999159b4587abcfaad0b28',
    messagingSenderId: '273099983865',
    projectId: 'kz-app-511e0',
    storageBucket: 'kz-app-511e0.firebasestorage.app',
  );
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBDwWU4OECDpueaj84fACSHKttY9wBHeyk',
    appId: '1:273099983865:web:88e50d96ace9bec6ad0b28',
    messagingSenderId: '273099983865',
    projectId: 'kz-app-511e0',
    authDomain: 'kz-app-511e0.firebaseapp.com',
    storageBucket: 'kz-app-511e0.firebasestorage.app',
    measurementId: 'G-0TR18ZHPW7',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBTtMkllFZmvxm7mDghxnao8S306eKjDUY',
    appId: '1:273099983865:ios:de6fd0029084852aad0b28',
    messagingSenderId: '273099983865',
    projectId: 'kz-app-511e0',
    storageBucket: 'kz-app-511e0.firebasestorage.app',
    iosBundleId: 'com.kzservicos.kzServicosPrestador',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBTtMkllFZmvxm7mDghxnao8S306eKjDUY',
    appId: '1:273099983865:ios:de6fd0029084852aad0b28',
    messagingSenderId: '273099983865',
    projectId: 'kz-app-511e0',
    storageBucket: 'kz-app-511e0.firebasestorage.app',
    iosBundleId: 'com.kzservicos.kzServicosPrestador',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBDwWU4OECDpueaj84fACSHKttY9wBHeyk',
    appId: '1:273099983865:web:653b993d05760bcaad0b28',
    messagingSenderId: '273099983865',
    projectId: 'kz-app-511e0',
    authDomain: 'kz-app-511e0.firebaseapp.com',
    storageBucket: 'kz-app-511e0.firebasestorage.app',
    measurementId: 'G-G9YS95D2KT',
  );
}
