import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../widgets/loading_overlay.dart';

class ApiService {
  /// Global navigator key — register this in MaterialApp so we can
  /// access context from anywhere without passing it around.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static BuildContext? get _ctx => navigatorKey.currentContext;

  static Future<String> _getToken() async {
    final user = FirebaseAuth.instance.currentUser!;
    return await user.getIdToken() ?? '';
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── GET ──────────────────────────────────────────────────────────────────
  static Future<dynamic> get(String endpoint,
      {bool showLoader = true}) async {
    final ctx = _ctx;
    if (showLoader && ctx != null) LoadingOverlay.show(ctx);
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception(
          'GET $endpoint failed: ${response.statusCode} — ${response.body}');
    } finally {
      if (showLoader) LoadingOverlay.hide();
    }
  }

  // ── POST ─────────────────────────────────────────────────────────────────
  static Future<dynamic> post(String endpoint, Map<String, dynamic> body,
      {bool showLoader = true}) async {
    final ctx = _ctx;
    if (showLoader && ctx != null) LoadingOverlay.show(ctx);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: await _headers(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      throw Exception(
          'POST $endpoint failed: ${response.statusCode} — ${response.body}');
    } finally {
      if (showLoader) LoadingOverlay.hide();
    }
  }

  // ── PUT ──────────────────────────────────────────────────────────────────
  static Future<dynamic> put(String endpoint, Map<String, dynamic> body,
      {bool showLoader = true}) async {
    final ctx = _ctx;
    if (showLoader && ctx != null) LoadingOverlay.show(ctx);
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: await _headers(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception(
          'PUT $endpoint failed: ${response.statusCode} — ${response.body}');
    } finally {
      if (showLoader) LoadingOverlay.hide();
    }
  }

  // ── DELETE ───────────────────────────────────────────────────────────────
  static Future<dynamic> delete(String endpoint,
      {bool showLoader = true}) async {
    final ctx = _ctx;
    if (showLoader && ctx != null) LoadingOverlay.show(ctx);
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception(
          'DELETE $endpoint failed: ${response.statusCode} — ${response.body}');
    } finally {
      if (showLoader) LoadingOverlay.hide();
    }
  }

  // ── LOGOUT ───────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
}
