import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/agri_api.dart';

/// Phone push notifications (Firebase Cloud Messaging, Android).
/// Works once android/app/google-services.json is added; otherwise it quietly does nothing.
class Push {
  static bool _started = false;
  static String? _token;

  static Future<void> start({GlobalKey<NavigatorState>? navigator}) async {
    if (_started || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _started = true;
    try {
      await Firebase.initializeApp(); // reads google-services.json
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(alert: true, badge: true, sound: true);
      _token = await fm.getToken();
      if (_token != null) await AgriApi.post('/devices', {'token': _token, 'platform': 'android'});
      fm.onTokenRefresh.listen((t) {
        _token = t;
        AgriApi.post('/devices', {'token': t, 'platform': 'android'}).catchError((_) => null);
      });
      // app open: show the message as a banner at the bottom
      FirebaseMessaging.onMessage.listen((m) {
        final ctx = navigator?.currentContext;
        final n = m.notification;
        if (ctx == null || n == null || !ctx.mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('${n.title ?? ''}${n.body == null ? '' : '\n${n.body}'}'),
          backgroundColor: const Color(0xFF0F5F2C),
        ));
      });
    } catch (e) {
      debugPrint('Push not available: $e');
    }
  }

  /// Stop sending pushes to this phone (on logout).
  static Future<void> stop() async {
    final t = _token;
    _started = false;
    _token = null;
    if (t == null) return;
    try {
      await AgriApi.delete('/devices?token=${Uri.encodeQueryComponent(t)}');
    } catch (_) {}
  }
}
