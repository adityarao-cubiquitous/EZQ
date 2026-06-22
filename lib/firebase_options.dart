import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD6Arqm1ECATHxiA0aUTFNgCe_WHlU5N-4',
    appId: '1:1066151489638:web:00f3d35f2363fc4c8c7da7',
    messagingSenderId: '1066151489638',
    projectId: 'ezq-dev-cubiquitous',
    authDomain: 'ezq-dev-cubiquitous.firebaseapp.com',
    storageBucket: 'ezq-dev-cubiquitous.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAD7IVeF2oAwDcTVkiWad4qZ4qj3nAp2sg',
    appId: '1:1066151489638:android:fe06ef713f4c93ea8c7da7',
    messagingSenderId: '1066151489638',
    projectId: 'ezq-dev-cubiquitous',
    storageBucket: 'ezq-dev-cubiquitous.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCO3RL0jN6ASKw0BJ24GgtrGNz-1wqv9tg',
    appId: '1:1066151489638:ios:e60fbb1a804d4d258c7da7',
    messagingSenderId: '1066151489638',
    projectId: 'ezq-dev-cubiquitous',
    iosBundleId: 'com.example.ezq',
    storageBucket: 'ezq-dev-cubiquitous.firebasestorage.app',
  );
}
