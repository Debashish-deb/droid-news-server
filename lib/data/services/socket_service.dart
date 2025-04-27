// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/material.dart';

class SocketService with ChangeNotifier {
  factory SocketService() => _instance;

  SocketService._internal();
  static final SocketService _instance = SocketService._internal();

  late IO.Socket socket;
  bool _connected = false;
  bool get connected => _connected;

  static const String serverUrl = 'https://droid-news-server.onrender.com'; // 🌐 Your deployed server

  void connect(Function(dynamic) onNewsReceived) {
    debugPrint('🚀 Attempting to connect to $serverUrl');

    socket = IO.io(
      serverUrl,
      <String, dynamic>{
        'transports': <String>['websocket', 'polling'], // Allow websocket + fallback
        'autoConnect': false,
        'reconnection': true,
        'reconnectionAttempts': 5,
        'reconnectionDelay': 2000, // 2 seconds
        'timeout': 5000, // 5 seconds timeout
      },
    );

    socket.connect();

    socket.onConnect((_) {
      _connected = true;
      notifyListeners();
      debugPrint('✅ Connected to Droid server!');
    });

    socket.on('news_update', (data) {
      debugPrint('📰 News received: $data');
      onNewsReceived(data);
    });

    socket.onDisconnect((reason) {
      _connected = false;
      notifyListeners();
      debugPrint('❌ Disconnected: $reason');
      reconnect(); // 💥 Auto Reconnect on disconnect
    });

    socket.onConnectError((err) {
      _connected = false;
      notifyListeners();
      debugPrint('⚠️ Connect Error: $err');
    });

    socket.onError((error) {
      debugPrint('🚨 General Socket Error: $error');
    });

    socket.onReconnectAttempt((attempt) {
      debugPrint('🔄 Attempting to reconnect... (Attempt #$attempt)');
    });

    socket.onReconnect((_) {
      _connected = true;
      notifyListeners();
      debugPrint('🔗 Successfully reconnected to server!');
    });

    socket.onReconnectFailed((_) {
      _connected = false;
      notifyListeners();
      debugPrint('🚫 Failed to reconnect after multiple attempts.');
    });
  }

  void disconnect() {
    if (socket.connected) {
      socket.disconnect();
      debugPrint('🔌 Manually disconnected from server.');
    }
    _connected = false;
    notifyListeners();
  }

  void reconnect() {
    if (!_connected) {
      debugPrint('♻️ Auto-reconnecting...');
      socket.connect();
    }
  }
}
