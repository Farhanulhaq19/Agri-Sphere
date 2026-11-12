import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  const ApiResult(this.success, this.message, [this.data]);
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const String baseUrl = 'http://10.0.2.2:5000/api';
  static const String googleWebClientId = '141130945534-413c2ou3jllmatikbuj92dd37un013e7.apps.googleusercontent.com';

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
  }

  Future<ApiResult> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>?;
      if (data != null && data['token'] != null) {
        await _saveToken(data['token'].toString());
      }
      return ApiResult(json['success'] == true, (json['message'] ?? '').toString(), data);
    } on TimeoutException {
      return const ApiResult(false, 'Server took too long to respond');
    } on FormatException {
      return const ApiResult(false, 'Unexpected server response');
    } catch (e) {
      return const ApiResult(false, 'Cannot reach server. Is the backend running?');
    }
  }

  Future<ApiResult> signup({
    required String name,
    required String email,
    required String password,
    required String role,
  }) {
    return _post('/auth/signup', {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    });
  }

  Future<ApiResult> login({required String email, required String password}) {
    return _post('/auth/login', {'email': email, 'password': password});
  }

  Future<ApiResult> sendEmailOtp(String email) {
    return _post('/auth/send-otp', {'email': email});
  }

  Future<ApiResult> verifyEmail({required String email, required String code}) {
    return _post('/auth/verify-email', {'email': email, 'code': code});
  }

  Future<ApiResult> googleSignIn({required bool signup, String role = 'Farmer'}) async {
    if (kIsWeb) {
      return const ApiResult(
        false,
        'Google sign-in works in the Android app. Run it on the emulator or a phone, not Chrome.',
      );
    }
    try {
      final g = GoogleSignIn(scopes: ['email'], serverClientId: googleWebClientId);
      await g.signOut();
      final account = await g.signIn();
      if (account == null) return const ApiResult(false, 'Google sign-in cancelled');
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) return const ApiResult(false, 'Could not get Google token');
      return await _post('/auth/google', {
        'idToken': idToken,
        'role': role,
        'mode': signup ? 'signup' : 'login',
      });
    } catch (e) {
      return ApiResult(false, 'Google sign-in failed: $e');
    }
  }
}