import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mobile/core/services/api_service.dart';

class NotificationService {
  static Future<void> init() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
      
      // Get the token
      String? token = await messaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        // Send to backend
        try {
          await ApiService.post('/auth/fcm-token', {'fcm_token': token});
          print('FCM Token registered with backend');
        } catch (e) {
          print('Failed to register FCM token: $e');
        }
      }

      // Handle token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        try {
          await ApiService.post('/auth/fcm-token', {'fcm_token': newToken});
        } catch (e) {
          print('Failed to update refreshed FCM token: $e');
        }
      });

      // Show notifications while in foreground
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } else {
      print('User declined or has not accepted notification permissions');
    }
  }
}
