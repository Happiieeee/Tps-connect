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
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final token = await result.user!.getIdToken();
      return await _fetchUserProfile(token!);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Google sign-in failed');
    }
  }

  // ─────────────────────────────────────────
  // Shared: fetch role from backend
  // ─────────────────────────────────────────
  static Future<Map<String, dynamic>?> _fetchUserProfile(String token) async {
    try {
      final data = await ApiService.get('/auth/me');
      return data; // contains role, branch_id, name, etc.
    } catch (e) {
      // User authenticated in Firebase but not in DB
      // This means they're not registered in TPS
      await _auth.signOut();
      throw Exception('Account not found in TPS. Contact your admin.');
    }
  }

  // ─────────────────────────────────────────
  // Session restore on app open
  // ─────────────────────────────────────────
  static Future<Map<String, dynamic>?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final token = await user.getIdToken(true); // refresh token
      return await _fetchUserProfile(token!);
    } catch (e) {
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
