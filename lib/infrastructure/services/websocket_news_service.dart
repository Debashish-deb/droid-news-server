import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../domain/entities/news_article.dart';

/// WebSocket service to connect to the backend server for real-time news updates
class WebSocketNewsService {

  WebSocketNewsService({String? serverUrl}) 
      : _serverUrl = serverUrl ?? 'http://localhost:3000';
  io.Socket? _socket;
  final String _serverUrl;
  final StreamController<NewsArticle> _newsController = StreamController<NewsArticle>.broadcast();
  final List<NewsArticle> _cachedArticles = [];
  bool _isConnected = false;

  /// Stream of incoming news articles
  Stream<NewsArticle> get newsStream => _newsController.stream;

  /// Check if WebSocket is connected
  bool get isConnected => _isConnected;

  /// Get cached articles from WebSocket
  List<NewsArticle> get cachedArticles => List.unmodifiable(_cachedArticles);

  /// Connect to the WebSocket server
  Future<void> connect() async {
    if (_isConnected) {
      debugPrint('👍 WebSocket already connected');
      return;
    }

    try {
      debugPrint('🔌 Connecting to WebSocket at $_serverUrl');
      
      _socket = io.io(
        _serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setTimeout(5000)
            .setReconnectionDelay(2000)
            .setReconnectionAttempts(5)
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('✅ WebSocket connected to $_serverUrl');
        _isConnected = true;
      });

      _socket!.on('news_update', (data) {
        try {
          debugPrint('📰 Received news update: ${data['title']}');
          final article = _parseNewsUpdate(data);
          if (article != null) {
            _cachedArticles.add(article);
            // Keep cache size manageable
            if (_cachedArticles.length > 50) {
              _cachedArticles.removeAt(0);
            }
            _newsController.add(article);
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing news update: $e');
        }
      });

      _socket!.onDisconnect((_) {
        debugPrint('❌ WebSocket disconnected');
        _isConnected = false;
      });

      _socket!.onError((error) {
        debugPrint('❌ WebSocket error: $error');
        _isConnected = false;
      });

      _socket!.connect();
      
      // Wait for connection with timeout
      await Future.delayed(const Duration(seconds: 3));
      
    } catch (e) {
      debugPrint('❌ Failed to connect to WebSocket: $e');
      _isConnected = false;
    }
  }

  /// Parse news update from server
  NewsArticle? _parseNewsUpdate(dynamic data) {
    try {
      final Map<String, dynamic> newsData = data is String 
          ? json.decode(data) 
          : Map<String, dynamic>.from(data);

      return NewsArticle(
        title: newsData['title'] ?? '',
        description: newsData['snippet'] ?? '',
        url: newsData['url'] ?? '',
        source: 'Google News',
        publishedAt: DateTime.now(),
        imageUrl: newsData['imageUrl'] ?? 'https://via.placeholder.com/400x180?text=No+Image',
        fullContent: newsData['snippet'] ?? '',
      );
    } catch (e) {
      debugPrint('⚠️ Error parsing news data: $e');
      return null;
    }
  }

  /// Disconnect from WebSocket server
  Future<void> disconnect() async {
    debugPrint('🔌 Disconnecting WebSocket');
    _socket?.disconnect();
    _socket?.dispose();
    _isConnected = false;
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _newsController.close();
  }
}
