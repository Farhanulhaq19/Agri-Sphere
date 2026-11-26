import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:agrisphere/core/services/agri_api.dart';

/// Live connection to the server (Socket.IO). New chat messages and notifications arrive
/// instantly instead of waiting for the next refresh. Safe to call [connect] many times.
class Realtime {
  static io.Socket? _s;
  static String? _token;
  static final _messages = StreamController<Map>.broadcast();
  static final _notes = StreamController<Map>.broadcast();
  static final ValueNotifier<bool> connected = ValueNotifier<bool>(false);

  /// {chatId, message, fromName}
  static Stream<Map> get messages => _messages.stream;

  /// {title, body, type, ref}
  static Stream<Map> get notifications => _notes.stream;

  static Future<void> connect() async {
    final t = await AgriApi.authToken();
    if (t == null || t.isEmpty) return;
    if (_s != null && _token == t) {
      if (!(_s!.connected)) _s!.connect();
      return;
    }
    disconnect();
    _token = t;
    final s = io.io(
      AgriApi.host,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': t})
          .enableReconnection()
          .setReconnectionDelay(2000)
          .disableAutoConnect()
          .build(),
    );
    s.onConnect((_) => connected.value = true);
    s.onDisconnect((_) => connected.value = false);
    s.on('chat:message', (d) {
      if (d is Map) _messages.add(Map<String, dynamic>.from(d));
    });
    s.on('notification', (d) {
      if (d is Map) _notes.add(Map<String, dynamic>.from(d));
    });
    s.connect();
    _s = s;
  }

  static void disconnect() {
    _s?.dispose();
    _s = null;
    _token = null;
    connected.value = false;
  }
}
