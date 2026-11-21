import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AgriApi {
  static String get host => kIsWeb ? 'http://localhost:5000' : 'http://ort 5000 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue | Out-Null:5000';
  static String get base => host + '/api/agri';
  static String? token;

  static Future<Map<String, String>> _h() async {
    final m = <String, String>{'Content-Type': 'application/json'};
    var t = token;
    if (t == null || t.isEmpty) {
      try {
        final sp = await SharedPreferences.getInstance();
        for (final k in ['token', 'auth_token', 'authToken', 'jwt', 'access_token', 'accessToken']) {
          final v = sp.getString(k);
          if (v != null && v.isNotEmpty) { t = v; break; }
        }
      } catch (_) {}
    }
    if (t != null && t.isNotEmpty) m['Authorization'] = 'Bearer $t';
    return m;
  }

  static dynamic _decode(http.Response r) {
    dynamic b;
    try { b = jsonDecode(r.body); } catch (_) { b = null; }
    if (r.statusCode >= 200 && r.statusCode < 300) return b;
    if (b is Map && b['message'] != null) throw Exception(b['message']);
    throw Exception('Request failed (${r.statusCode})');
  }

  static const _t = Duration(seconds: 15);

  static Future<dynamic> get(String p) async =>
      _decode(await http.get(Uri.parse(base + p), headers: await _h()).timeout(_t));

  static Future<dynamic> post(String p, [Map<String, dynamic>? body]) async =>
      _decode(await http.post(Uri.parse(base + p), headers: await _h(), body: jsonEncode(body ?? {})).timeout(_t));

  static Future<dynamic> patch(String p, [Map<String, dynamic>? body]) async =>
      _decode(await http.patch(Uri.parse(base + p), headers: await _h(), body: jsonEncode(body ?? {})).timeout(_t));

  static Future<dynamic> delete(String p) async =>
      _decode(await http.delete(Uri.parse(base + p), headers: await _h()).timeout(_t));
}