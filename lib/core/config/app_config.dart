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
  // API Keys
  static const String newsApiKey = String.fromEnvironment(
    'NEWS_API_KEY',
    defaultValue: 'dnGnLhmKJ7ACuHfQ4mvAJOt5OobmoAk5AFFYFNQg',
  );

  static const String newsDataApiKey = String.fromEnvironment(
    'NEWSDATA_API_KEY',
    defaultValue: 'pub_cc270f0996194d54be2c5b997604984d',
  );

  static const String gNewsApiKey = String.fromEnvironment(
    'GNEWS_API_KEY',
    defaultValue: '3606f9bc1ab71f01c110bc6a99a23180',
  );
}
