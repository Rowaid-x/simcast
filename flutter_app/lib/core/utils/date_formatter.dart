import 'package:intl/intl.dart';

/// Date and time formatting utilities for the chat UI.
class DateFormatter {
  DateFormatter._();

  /// Format a timestamp for conversation list (e.g., "2:30 PM", "Yesterday", "Mon", "12/25").
  static String conversationTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(messageDate).inDays;

    if (diff == 0) {
      return DateFormat('h:mm a').format(dateTime);
    } else if (diff == 1) {
      return 'Yesterday';
    } else if (diff < 7) {
      return DateFormat('EEE').format(dateTime);
    } else {
      return DateFormat('M/d/yy').format(dateTime);
    }
  }

  /// Format a timestamp for message bubbles (e.g., "2:30 PM").
  static String messageTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  /// Format a date separator in the chat (e.g., "Today", "Yesterday", "March 15, 2026").
  static String dateSeparator(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(messageDate).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (dateTime.year == now.year) {
      return DateFormat('MMMM d').format(dateTime);
    }
    return DateFormat('MMMM d, y').format(dateTime);
  }

  /// Format last seen time (e.g., "last seen just now", "last seen 5 min ago").
  static String lastSeen(DateTime? dateTime) {
    if (dateTime == null) return 'offline';
    final diff = DateTime.now().difference(dateTime);

    if (diff.inMinutes < 1) return 'last seen just now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'last seen ${diff.inHours}h ago';
    return 'last seen ${DateFormat('M/d').format(dateTime)}';
  }

  /// Format auto-delete timer value to human-readable string.
  static String autoDeleteTimer(int? seconds) {
    if (seconds == null) return 'Off';
    if (seconds == 1800) return '30 minutes';
    if (seconds == 3600) return '1 hour';
    if (seconds == 21600) return '6 hours';
    if (seconds == 86400) return '24 hours';
    if (seconds == 604800) return '7 days';
    return '${seconds}s';
  }

  /// Format file size (e.g., "1.5 MB", "256 KB").
  static String fileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
