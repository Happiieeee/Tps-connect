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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBqU7NIBH7_xol4fdI5_uYOQQrlohVDxVQ',
    appId: '1:384559680246:web:bc8a2ca76acade2f5bfad7',
    messagingSenderId: '384559680246',
    projectId: 'tps-aut',
    authDomain: 'tps-aut.firebaseapp.com',
    storageBucket: 'tps-aut.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBp4577qxMgcEU8kO2pqkYoB9RqValqM2Q',
    appId: '1:384559680246:android:c7201b833bdd09d55bfad7',
    messagingSenderId: '384559680246',
    projectId: 'tps-aut',
    storageBucket: 'tps-aut.firebasestorage.app',
  );
}
