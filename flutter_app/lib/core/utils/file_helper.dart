import 'dart:io';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Utility helpers for file operations.
class FileHelper {
  FileHelper._();

  /// Allowed MIME types for upload.
  static const allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'audio/mpeg',
    'audio/wav',
    'audio/ogg',
    'audio/aac',
    'audio/mp4',
    'application/pdf',
    'application/zip',
    'text/plain',
    'text/csv',
    'video/mp4',
    'video/webm',
  };

  /// Max file size in bytes (25 MB).
  static const int maxFileSize = 25 * 1024 * 1024;

  /// Validate a file before upload.
  static FileValidationResult validateFile(File file) {
    if (!file.existsSync()) {
      return FileValidationResult(isValid: false, error: 'File not found.');
    }

    final size = file.lengthSync();
    if (size > maxFileSize) {
      return FileValidationResult(
        isValid: false,
        error: 'File exceeds the 25MB size limit.',
      );
    }

    final mimeType = lookupMimeType(file.path);
    if (mimeType == null || !allowedMimeTypes.contains(mimeType)) {
      return FileValidationResult(
        isValid: false,
        error: 'File type "$mimeType" is not supported.',
      );
    }

    return FileValidationResult(isValid: true, mimeType: mimeType);
  }

  /// Get the app's temporary directory for caching files.
  static Future<Directory> getTempDir() async {
    final dir = await getTemporaryDirectory();
    return dir;
  }

  /// Get a human-readable file size string.
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Determine the message type from a file's MIME type.
  static String messageTypeFromMime(String? mimeType) {
    if (mimeType == null) return 'file';
    if (mimeType.startsWith('image/')) return 'image';
    if (mimeType.startsWith('audio/')) return 'voice';
    if (mimeType.startsWith('video/')) return 'file';
    return 'file';
  }

  /// Get file extension from path.
  static String getExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }
}

/// Result of a file validation check.
class FileValidationResult {
  final bool isValid;
  final String? error;
  final String? mimeType;

  FileValidationResult({required this.isValid, this.error, this.mimeType});
}
