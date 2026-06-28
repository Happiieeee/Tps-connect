import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

Future<Map<String, dynamic>> getUserRole() async {
  final user = await AuthService.restoreSession();
  if (user != null) return user;
  throw Exception('Failed to fetch user role');
}

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn();

  // ─────────────────────────────────────────
  // PARENT — Phone OTP
  // ─────────────────────────────────────────

  // Step 1: Send OTP
  static Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber, // e.g. +919876543210
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verified on Android (SMS auto-read)
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // Step 2: Verify OTP
  static Future<Map<String, dynamic>?> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      final result = await _auth.signInWithCredential(credential);
      final token = await result.user!.getIdToken();
      return await _fetchUserProfile(token!);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Invalid OTP');
    }
  }

  // ─────────────────────────────────────────
  // STAFF — Google Sign-In
  // ─────────────────────────────────────────
  static Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      debugPrint('AuthService: Starting Google Sign-In');
      // Force account picker by disconnecting first
      try {
        await _googleSignIn.disconnect();
      } catch (_) {
        // Ignore if not already signed in
      }
      
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('AuthService: Google Sign-In cancelled by user');
        return null;
      }

      debugPrint('AuthService: Google user: ${googleUser.email}');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final token = await result.user!.getIdToken();
      debugPrint('AuthService: Firebase UID: ${result.user?.uid}');
      
      return await _fetchUserProfile(token!);
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService: FirebaseAuthException: ${e.message}');
      throw Exception(e.message ?? 'Google sign-in failed');
    } catch (e) {
      debugPrint('AuthService: Unexpected error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────
  // Shared: fetch role from backend
  // ─────────────────────────────────────────
  static Future<Map<String, dynamic>?> _fetchUserProfile(String token) async {
    try {
      debugPrint('AuthService: Fetching profile from backend...');
      final data = await ApiService.get('/auth/me');
      debugPrint('AuthService: Profile fetched successfully. Role: ${data['role']}');
      return data; // contains role, branch_id, name, etc.
    } catch (e) {
      debugPrint('AuthService: Profile fetch failed: $e');
      // Only sign out if it's a 404 (Account not found)
      // If it's a 500 or other error, it might be a temporary DB issue
      if (e.toString().contains('404')) {
        await _googleSignIn.signOut();
        await _auth.signOut();
        throw Exception('Account not found in TPS. Contact your admin.');
      }
      throw Exception('Server Error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  // ─────────────────────────────────────────
  // Session restore on app open
  // ─────────────────────────────────────────
  static Future<Map<String, dynamic>?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('AuthService: No current user found (session is null)');
      return null;
    }

    debugPrint('AuthService: Session found for user: ${user.email ?? user.phoneNumber}');
    try {
      final token = await user.getIdToken(true); // refresh token
      return await _fetchUserProfile(token!);
    } catch (e) {
      debugPrint('AuthService: Session restoration failed: $e');
      return null; // session invalid, show login
    }
  }

  // ─────────────────────────────────────────
  // Sign out
  // ─────────────────────────────────────────
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
