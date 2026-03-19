/// Application-wide constants for Whisper.
class AppConstants {
  AppConstants._();

  // API Configuration
  static const String baseUrl = 'http://76.13.213.26/api/v1';
  static const String wsUrl = 'ws://76.13.213.26/ws/chat/';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // Pagination
  static const int messagesPageSize = 30;
  static const int conversationsPageSize = 20;

  // File limits
  static const int maxFileSizeMB = 25;
  static const int maxFileSize = maxFileSizeMB * 1024 * 1024;

  // Auto-delete timer options (in seconds)
  static const Map<int?, String> autoDeleteOptions = {
    null: 'Off',
    1800: '30 minutes',
    3600: '1 hour',
    21600: '6 hours',
    86400: '24 hours',
    604800: '7 days',
  };

  // Secure storage keys
  static const String accessTokenKey = 'whisper_access_token';
  static const String refreshTokenKey = 'whisper_refresh_token';
  static const String userIdKey = 'whisper_user_id';
}
