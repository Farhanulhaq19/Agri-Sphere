import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrisphere/core/services/agri_api.dart';

class ApiResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  const ApiResult(this.success, this.message, [this.data]);
}

/// What the app remembers about the signed-in person.
class AuthSession {
  final String name;
  final String email;
  final String phone;
  final String role; // active role, e.g. Farmer
  final List<String> roles; // everything the person owns
  const AuthSession({
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.roles,
  });
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  /// Real phone: flutter run --dart-define=API_HOST=http://YOUR_PC_IP:5000
  static const String _hostOverride = String.fromEnvironment('API_HOST');
  static String get baseUrl => _hostOverride.isNotEmpty
      ? '$_hostOverride/api'
      : (kIsWeb ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api');
  static const String googleWebClientId =
      '141130945534-413c2ou3jllmatikbuj92dd37un013e7.apps.googleusercontent.com';

  static const _kToken = 'token';
  static const _kRemember = 'remember_me';

  // ------------------------------------------------------------ session storage
  Future<void> _saveSession(Map<String, dynamic> d) async {
    final prefs = await SharedPreferences.getInstance();
    if (d['token'] != null) {
      final t = d['token'].toString();
      await prefs.setString(_kToken, t);
      AgriApi.token = t;
    }
    if (d['name'] != null) await prefs.setString('user_name', '${d['name']}');
    if (d['email'] != null) await prefs.setString('user_email', '${d['email']}');
    if (d['phone'] != null) await prefs.setString('user_phone', '${d['phone']}');
    if (d['role'] != null) await prefs.setString('user_role', '${d['role']}');
    if (d['roles'] is List) {
      await prefs.setStringList(
        'user_roles',
        (d['roles'] as List).map((e) => '$e').toList(),
      );
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  Future<AuthSession?> session() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString(_kToken) ?? '').isEmpty) return null;
    final role = prefs.getString('user_role') ?? 'Farmer';
    final roles = prefs.getStringList('user_roles') ?? [role];
    return AuthSession(
      name: prefs.getString('user_name') ?? 'User',
      email: prefs.getString('user_email') ?? '',
      phone: prefs.getString('user_phone') ?? '',
      role: role,
      roles: roles.isEmpty ? [role] : roles,
    );
  }

  Future<void> setRemember(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRemember, v);
  }

  Future<bool> remembered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kRemember) ?? true;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      _kToken,
      'auth_token',
      'authToken',
      'jwt',
      'access_token',
      'accessToken',
      'user_name',
      'user_email',
      'user_phone',
      'user_role',
      'user_roles',
    ]) {
      await prefs.remove(k);
    }
    AgriApi.token = null;
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------ http
  Future<ApiResult> _send(
    String method,
    String path,
    Map<String, dynamic>? body, {
    bool auth = false,
  }) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (auth) {
        final t = await getToken();
        if (t != null && t.isNotEmpty) headers['Authorization'] = 'Bearer $t';
      }
      final uri = Uri.parse('$baseUrl$path');
      late http.Response res;
      if (method == 'GET') {
        res = await http.get(uri, headers: headers);
      } else if (method == 'PUT') {
        res = await http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
      } else {
        res = await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>?;
      final okFlag = json['success'] == true;
      if (okFlag && data != null && (data['token'] != null || data['roles'] != null)) {
        await _saveSession(data);
      }
      return ApiResult(okFlag, (json['message'] ?? '').toString(), data);
    } on TimeoutException {
      return const ApiResult(false, 'Server took too long to respond');
    } on FormatException {
      return const ApiResult(false, 'Unexpected server response');
    } catch (e) {
      return const ApiResult(
        false,
        'Cannot reach server. Is the backend running?',
      );
    }
  }

  Future<ApiResult> _post(String path, Map<String, dynamic> body,
          {bool auth = false}) =>
      _send('POST', path, body, auth: auth).timeout(
        const Duration(seconds: 25),
        onTimeout: () => const ApiResult(false, 'Server took too long to respond'),
      );

  // ------------------------------------------------------------ sign up / in
  Future<ApiResult> signup({
    required String name,
    required String email,
    required String password,
    required List<String> roles,
    String phone = '',
  }) {
    return _post('/auth/signup', {
      'name': name,
      'email': email,
      'password': password,
      'roles': roles,
      'phone': phone,
    });
  }

  Future<ApiResult> login({
    required String email,
    required String password,
    String? role,
  }) {
    return _post('/auth/login', {
      'email': email,
      'password': password,
      if (role != null) 'role': role,
    });
  }

  Future<ApiResult> sendEmailOtp(String email) {
    return _post('/auth/send-otp', {'email': email});
  }

  Future<ApiResult> verifyEmail({required String email, required String code}) {
    return _post('/auth/verify-email', {'email': email, 'code': code});
  }

  // ------------------------------------------------------------ password
  Future<ApiResult> forgotPassword(String email) {
    return _post('/auth/forgot-password', {'email': email});
  }

  Future<ApiResult> resetPassword({
    required String email,
    required String code,
    required String password,
  }) {
    return _post('/auth/reset-password', {
      'email': email,
      'code': code,
      'password': password,
    });
  }

  Future<ApiResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _post('/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    }, auth: true);
  }

  // ------------------------------------------------------------ roles / account
  Future<ApiResult> switchRole(String role) =>
      _post('/auth/switch-role', {'role': role}, auth: true);

  Future<ApiResult> addRoles(List<String> roles, {bool makeActive = false}) =>
      _post('/auth/add-role', {'roles': roles, 'makeActive': makeActive},
          auth: true);

  Future<ApiResult> removeRole(String role) =>
      _post('/auth/remove-role', {'role': role}, auth: true);

  Future<ApiResult> me() => _send('GET', '/auth/me', null, auth: true);

  Future<ApiResult> updateAccount({String? name, String? phone}) => _send(
    'PUT',
    '/auth/account',
    {if (name != null) 'name': name, if (phone != null) 'phone': phone},
    auth: true,
  );

  // ------------------------------------------------------------ google
  Future<ApiResult> googleSignIn({
    required bool signup,
    List<String> roles = const ['Farmer'],
  }) async {
    if (kIsWeb) {
      return const ApiResult(
        false,
        'Google sign-in works in the Android app. Run it on the emulator or a phone, not Chrome.',
      );
    }
    try {
      final g = GoogleSignIn(
        scopes: ['email'],
        serverClientId: googleWebClientId,
      );
      await g.signOut();
      final account = await g.signIn();
      if (account == null) {
        return const ApiResult(false, 'Google sign-in cancelled');
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        return const ApiResult(false, 'Could not get Google token');
      }
      return await _post('/auth/google', {
        'idToken': idToken,
        'roles': roles,
        'mode': signup ? 'signup' : 'login',
      });
    } catch (e) {
      return ApiResult(false, 'Google sign-in failed: $e');
    }
  }
}
