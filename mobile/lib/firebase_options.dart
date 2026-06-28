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
    apiKey: 'AIzaSyCNzh2c5b72SM3jUqdFGDbLURERC-uOzgA',
    appId: '1:57492511873:web:19d83a369b3ac1ef062280',
    messagingSenderId: '57492511873',
    projectId: 'tps-connect-bc72b',
    authDomain: 'tps-connect-bc72b.firebaseapp.com',
    storageBucket: 'tps-connect-bc72b.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCa7Vo1QQLb4Os1f2x-ALH_thHS1eTTvCw',
    appId: '1:574925311873:android:f1784c25f7d95af9062280',
    messagingSenderId: '574925311873',
    projectId: 'tps-connect-bc72b',
    storageBucket: 'tps-connect-bc72b.firebasestorage.app',
  );
}
