import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AgriApi {
  /// Real phone / release build:
  ///   flutter run --dart-define=API_HOST=http://YOUR_PC_IP:5000
  static const String _hostOverride = String.fromEnvironment('API_HOST');
  static String get host => _hostOverride.isNotEmpty
      ? _hostOverride
      : (kIsWeb ? 'http://localhost:5000' : 'http://10.0.2.2:5000');
  static String get base => '$host/api/agri';

  /// Set after login so requests belong to the logged-in user.
  static String? token;

  /// true while the last request failed because there is no connection (an offline banner listens to it).
  static final ValueNotifier<bool> offline = ValueNotifier<bool>(false);

  /// The login token (null for guests) - used by the live connection.
  static Future<String?> authToken() async {
    final a = (await _h())['Authorization'];
    return a?.replaceFirst('Bearer ', '');
  }

  /// Short id of the logged-in session, so one user's saved (offline) data is never shown to another.
  static Future<String> _who() async {
    final a = (await _h())['Authorization'] ?? 'guest';
    return a.length > 12 ? a.substring(a.length - 12) : a;
  }

  /// Removes all saved offline data (called on logout / session expiry).
  static Future<void> clearCache() async {
    try {
      final sp = await SharedPreferences.getInstance();
      for (final k in sp.getKeys().where((k) => k.startsWith('cache:')).toList()) {
        await sp.remove(k);
      }
    } catch (_) {}
  }

  /// Downloads a private file (e.g. a payment receipt) with the login header.
  static Future<List<int>> bytes(String p) async {
    final r = await http.get(Uri.parse(base + p), headers: await _h()).timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) {
      if (r.statusCode == 401) onSessionExpired?.call();
      throw Exception(r.statusCode == 403 ? 'You cannot view this receipt' : 'Could not load the receipt');
    }
    return r.bodyBytes;
  }

  static Future<Map<String, String>> _h() async {
    final m = <String, String>{'Content-Type': 'application/json'};
    var t = token;
    if (t == null || t.isEmpty) {
      try {
        final sp = await SharedPreferences.getInstance();
        for (final k in [
          'token',
          'auth_token',
          'authToken',
          'jwt',
          'access_token',
          'accessToken',
        ]) {
          final v = sp.getString(k);
          if (v != null && v.isNotEmpty) {
            t = v;
            break;
          }
        }
      } catch (_) {}
    }
    if (t != null && t.isNotEmpty) m['Authorization'] = 'Bearer $t';
    return m;
  }

  static dynamic _decode(http.Response r) {
    dynamic b;
    try {
      b = jsonDecode(r.body);
    } catch (_) {
      b = null;
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return b;
    if (r.statusCode == 401) {
      // token expired / user logged out elsewhere: send the user back to login once
      onSessionExpired?.call();
      throw Exception((b is Map && b['message'] != null) ? b['message'] : 'Session expired. Please log in again.');
    }
    if (b is Map && b['message'] != null) throw Exception(b['message']);
    if (r.statusCode >= 500) throw Exception('Server problem. Please try again in a moment.');
    throw Exception('Request failed (${r.statusCode})');
  }

  /// Set in main.dart: what to do when the server says the login is no longer valid.
  static void Function()? onSessionExpired;

  static const _t = Duration(seconds: 15);

  /// GET with an offline fallback: successful answers are saved on the phone,
  /// and when the network is down the last saved answer is returned instead.
  static Future<dynamic> get(String p) async {
    final key = 'cache:${await _who()}:$p';
    http.Response r;
    try {
      r = await _withRetry(() async => http.get(Uri.parse(base + p), headers: await _h()).timeout(_t));
    } catch (e) {
      try {
        final saved = (await SharedPreferences.getInstance()).getString(key);
        if (saved != null) {
          offline.value = true;
          return jsonDecode(saved);
        }
      } catch (_) {}
      offline.value = true;
      throw Exception('No internet connection. Check your network and try again.');
    }
    offline.value = false;
    final data = _decode(r);
    try {
      // chats poll every few seconds, so they are not cached
      if (r.body.length < 400000 && !p.startsWith('/chats')) await (await SharedPreferences.getInstance()).setString(key, r.body);
    } catch (_) {}
    return data;
  }

  /// Retries once after a short pause (weak mobile signal often fails only the first time).
  static Future<http.Response> _withRetry(Future<http.Response> Function() call) async {
    try {
      return await call();
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return call();
    }
  }

  /// POST / PUT / PATCH / DELETE. Big bodies (photos) get more time. These are never retried
  /// automatically (so an order is never placed twice); offline gives a clear message instead.
  static Future<dynamic> _send(String method, String p, [Map<String, dynamic>? body]) async {
    final payload = body == null ? null : jsonEncode(body);
    final timeout = (payload?.length ?? 0) > 200000 ? const Duration(seconds: 60) : _t;
    final req = http.Request(method, Uri.parse(base + p))..headers.addAll(await _h());
    if (payload != null) req.body = payload;
    http.Response r;
    try {
      r = await http.Response.fromStream(await req.send().timeout(timeout));
    } catch (e) {
      offline.value = true;
      throw Exception('You are offline. This action needs internet, please try again when connected.');
    }
    offline.value = false;
    return _decode(r);
  }

  static Future<dynamic> post(String p, [Map<String, dynamic>? body]) => _send('POST', p, body ?? {});
  static Future<dynamic> put(String p, [Map<String, dynamic>? body]) => _send('PUT', p, body ?? {});
  static Future<dynamic> patch(String p, [Map<String, dynamic>? body]) => _send('PATCH', p, body ?? {});
  static Future<dynamic> delete(String p) => _send('DELETE', p);
}
