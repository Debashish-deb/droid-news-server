/// Application configuration for news sources
class AppConfig {
  // Backend WebSocket server URL
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:3000',
  );

  // Feature flags
  static const bool useWebSocket = bool.fromEnvironment(
    'USE_WEBSOCKET',
    defaultValue: true,
  );

  static const bool useRssFallback = bool.fromEnvironment(
    'USE_RSS_FALLBACK',
    defaultValue: true,
  );

  // Priority: websocket > rss > cache
  static const String newsPriority = String.fromEnvironment(
    'NEWS_PRIORITY',
    defaultValue: 'rss', // Changed to RSS first since backend might not be running
  );
}
