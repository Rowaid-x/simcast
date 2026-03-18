import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../config/theme.dart';
import '../../../../core/utils/date_formatter.dart';

/// Displays a file attachment preview inside a message or as a standalone widget.
class FileAttachment extends StatelessWidget {
  final String fileName;
  final int? fileSize;
  final String? mimeType;
  final VoidCallback? onTap;
  final bool isDownloading;

  const FileAttachment({
    super.key,
    required this.fileName,
    this.fileSize,
    this.mimeType,
    this.onTap,
    this.isDownloading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(WhisperSpacing.md),
        decoration: BoxDecoration(
          color: WhisperColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(WhisperRadius.md),
          border: Border.all(color: WhisperColors.border, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: WhisperColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(WhisperRadius.sm),
              ),
              child: isDownloading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: WhisperColors.accent,
                      ),
                    )
                  : Icon(
                      _getFileIcon(),
                      color: WhisperColors.accent,
                      size: 22,
                    ),
            ),
            const SizedBox(width: WhisperSpacing.md),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: WhisperTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (fileSize != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      DateFormatter.fileSize(fileSize),
                      style: WhisperTypography.caption.copyWith(
                        color: WhisperColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: WhisperSpacing.sm),
            Icon(
              LucideIcons.download,
              color: WhisperColors.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon() {
    if (mimeType == null) return LucideIcons.file;
    if (mimeType!.startsWith('image/')) return LucideIcons.image;
    if (mimeType!.startsWith('audio/')) return LucideIcons.music;
    if (mimeType!.startsWith('video/')) return LucideIcons.video;
    if (mimeType!.contains('pdf')) return LucideIcons.fileText;
    if (mimeType!.contains('zip') || mimeType!.contains('rar')) {
      return LucideIcons.fileArchive;
    }
    return LucideIcons.file;
  }
}
