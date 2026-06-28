import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'firebase_options.dart';
import 'core/auth/auth_service.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TpsApp());
}

class TpsApp extends StatelessWidget {
  const TpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TPS Connect',
      theme: TPSTheme.theme,
      navigatorKey: ApiService.navigatorKey,
      home: const SplashRouter(),
      routes: appRoutes,
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});
  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final user = await AuthService.restoreSession();
    if (!mounted) return;

    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Initialize push notifications since we have an active session
    NotificationService.init();

    final role = user['role'];
    switch (role) {
      case 'superadmin':
        Navigator.pushReplacementNamed(context, '/super-admin'); break;
      case 'branchadmin':
        Navigator.pushReplacementNamed(context, '/branch-admin'); break;
      case 'teacher':
        Navigator.pushReplacementNamed(context, '/teacher'); break;
      case 'parent':
        Navigator.pushReplacementNamed(context, '/parent'); break;
      default:
        Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF7FAF4),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF3B6D11)),
      ),
    );
  }
}
