import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../models/message.dart';
import '../../../../widgets/avatar.dart';
import 'voice_player.dart';

/// A single message bubble with support for text, image, voice, and file types.
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isSent;
  final bool showSenderName;
  final VoidCallback? onLongPress;
  final VoidCallback? onReply;
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isSent,
    this.showSenderName = false,
    this.onLongPress,
    this.onReply,
    this.onRetry,
  });

  // Consistent color for each sender based on their user ID
  static final List<Color> _senderColors = [
    const Color(0xFF6C5CE7),
    const Color(0xFFE17055),
    const Color(0xFF00B894),
    const Color(0xFFFDAA5D),
    const Color(0xFFE84393),
    const Color(0xFF0984E3),
    const Color(0xFF00CEC9),
    const Color(0xFFA29BFE),
  ];

  Color _senderColor() {
    if (message.sender == null) return WhisperColors.accent;
    final hash = message.sender!.id.hashCode.abs();
    return _senderColors[hash % _senderColors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return _buildDeletedBubble();
    }

    final showAvatar = showSenderName && !isSent;

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: EdgeInsets.only(
            left: isSent ? 48 : (showAvatar ? WhisperSpacing.sm : WhisperSpacing.lg),
            right: isSent ? WhisperSpacing.lg : 48,
            bottom: WhisperSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Small avatar for group received messages
              if (showAvatar && message.sender != null)
                Padding(
                  padding: const EdgeInsets.only(right: WhisperSpacing.xs, bottom: 2),
                  child: WhisperAvatar(
                    imageUrl: message.sender!.avatarUrl,
                    name: message.sender!.displayName,
                    size: 28,
                  ),
                ),
              // Failed indicator (appears to the left of the bubble)
              if (isSent && message.isFailed) _buildFailedIndicator(),
              Flexible(
                child: Column(
                  crossAxisAlignment:
                      isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Sender name (groups) with unique color
                    if (showSenderName && !isSent && message.sender != null)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: WhisperSpacing.md,
                          bottom: 2,
                        ),
                        child: Text(
                          message.sender!.displayName,
                          style: WhisperTypography.caption.copyWith(
                            color: _senderColor(),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // Message content container
                    Container(
                decoration: BoxDecoration(
                  color: isSent
                      ? WhisperColors.bubbleSent
                      : WhisperColors.bubbleReceived,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(WhisperRadius.lg),
                    topRight: const Radius.circular(WhisperRadius.lg),
                    bottomLeft: Radius.circular(
                        isSent ? WhisperRadius.lg : WhisperRadius.sm),
                    bottomRight: Radius.circular(
                        isSent ? WhisperRadius.sm : WhisperRadius.lg),
                  ),
                  // Colored left border for group received messages
                  border: (showSenderName && !isSent && message.sender != null)
                      ? Border(
                          left: BorderSide(
                            color: _senderColor(),
                            width: 3,
                          ),
                        )
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(WhisperRadius.lg),
                    topRight: const Radius.circular(WhisperRadius.lg),
                    bottomLeft: Radius.circular(
                        isSent ? WhisperRadius.lg : WhisperRadius.sm),
                    bottomRight: Radius.circular(
                        isSent ? WhisperRadius.sm : WhisperRadius.lg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reply preview
                      if (message.replyToPreview != null)
                        _buildReplyPreview(),

                      // Message body
                      _buildMessageBody(),
                    ],
                  ),
                ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, duration: 200.ms);
  }

  Widget _buildFailedIndicator() {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: onRetry,
        child: const Tooltip(
          message: 'Tap to retry',
          child: Icon(
            LucideIcons.alertCircle,
            color: Color(0xFFFF6B6B),
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    final reply = message.replyToPreview!;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        WhisperSpacing.md,
        WhisperSpacing.sm,
        WhisperSpacing.md,
        WhisperSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: WhisperColors.accent,
            width: 2,
          ),
        ),
        color: isSent
            ? Colors.white.withOpacity(0.08)
            : WhisperColors.surfaceElevated.withOpacity(0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reply.senderName != null)
            Text(
              reply.senderName!,
              style: WhisperTypography.caption.copyWith(
                color: WhisperColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          Text(
            reply.content ?? _typeLabel(reply.messageType),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: WhisperTypography.caption.copyWith(
              color: isSent
                  ? WhisperColors.bubbleSentText.withOpacity(0.7)
                  : WhisperColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBody() {
    switch (message.messageType) {
      case 'image':
        return _buildImageMessage();
      case 'voice':
        return _buildVoiceMessage();
      case 'file':
        return _buildFileMessage();
      default:
        return _buildTextMessage();
    }
  }

  Widget _buildTextMessage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WhisperSpacing.md,
        WhisperSpacing.sm,
        WhisperSpacing.md,
        WhisperSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message.content ?? '',
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: isSent
                  ? WhisperColors.bubbleSentText
                  : WhisperColors.bubbleReceivedText,
            ),
          ),
          const SizedBox(height: 2),
          _buildTimestamp(),
        ],
      ),
    );
  }

  Widget _buildImageMessage() {
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (message.fileUrl != null)
            GestureDetector(
              onTap: () => _openImageViewer(context, message.fileUrl!),
              child: CachedNetworkImage(
                imageUrl: message.fileUrl!,
                width: 240,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 240,
                  height: 180,
                  color: WhisperColors.surfaceSecondary,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: WhisperColors.accent,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 240,
                  height: 180,
                  color: WhisperColors.surfaceSecondary,
                  child: const Icon(
                    LucideIcons.imageOff,
                    color: WhisperColors.textTertiary,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WhisperSpacing.sm,
              WhisperSpacing.xs,
              WhisperSpacing.sm,
              WhisperSpacing.xs,
            ),
            child: _buildTimestamp(),
          ),
        ],
      ),
    );
  }

  void _openImageViewer(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(LucideIcons.x, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: PhotoView(
            imageProvider: CachedNetworkImageProvider(imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceMessage() {
    return Padding(
      padding: const EdgeInsets.all(WhisperSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (message.fileUrl != null)
            VoicePlayer(
              audioUrl: message.fileUrl!,
              isSent: isSent,
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.mic,
                  size: 18,
                  color: isSent ? Colors.white : WhisperColors.accent,
                ),
                const SizedBox(width: WhisperSpacing.sm),
                Text(
                  'Voice message',
                  style: TextStyle(
                    fontSize: 14,
                    color: isSent
                        ? WhisperColors.bubbleSentText
                        : WhisperColors.bubbleReceivedText,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 2),
          _buildTimestamp(),
        ],
      ),
    );
  }

  Widget _buildFileMessage() {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          if (message.fileUrl != null) {
            launchUrl(Uri.parse(message.fileUrl!),
                mode: LaunchMode.externalApplication);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(WhisperSpacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSent
                      ? Colors.white.withOpacity(0.15)
                      : WhisperColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(WhisperRadius.sm),
                ),
                child: Icon(
                  LucideIcons.file,
                  size: 20,
                  color: isSent ? Colors.white : WhisperColors.accent,
                ),
              ),
              const SizedBox(width: WhisperSpacing.sm),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.fileName ?? 'File',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSent
                            ? WhisperColors.bubbleSentText
                            : WhisperColors.bubbleReceivedText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormatter.fileSize(message.fileSize),
                          style: TextStyle(
                            fontSize: 12,
                            color: isSent
                                ? WhisperColors.bubbleSentText.withOpacity(0.7)
                                : WhisperColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          LucideIcons.download,
                          size: 12,
                          color: isSent
                              ? WhisperColors.bubbleSentText.withOpacity(0.7)
                              : WhisperColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    _buildTimestamp(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimestamp() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormatter.messageTime(message.createdAt),
          style: TextStyle(
            fontSize: 11,
            color: isSent
                ? WhisperColors.bubbleSentText.withOpacity(0.6)
                : WhisperColors.textTertiary,
          ),
        ),
        if (isSent) ...[
          const SizedBox(width: 3),
          Icon(
            message.isRead ? LucideIcons.checkCheck : LucideIcons.check,
            size: 14,
            color: message.isRead
                ? (isSent ? WhisperColors.bubbleSentText.withOpacity(0.8) : WhisperColors.accent)
                : (isSent
                    ? WhisperColors.bubbleSentText.withOpacity(0.5)
                    : WhisperColors.textTertiary),
          ),
        ],
      ],
    );
  }

  Widget _buildDeletedBubble() {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isSent ? 48 : WhisperSpacing.lg,
          right: isSent ? WhisperSpacing.lg : 48,
          bottom: WhisperSpacing.xs,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: WhisperSpacing.md,
          vertical: WhisperSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: WhisperColors.surfaceSecondary.withOpacity(0.5),
          borderRadius: BorderRadius.circular(WhisperRadius.lg),
          border: Border.all(
            color: WhisperColors.divider,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.ban,
              size: 14,
              color: WhisperColors.textTertiary,
            ),
            const SizedBox(width: WhisperSpacing.xs),
            Text(
              'This message was deleted',
              style: WhisperTypography.bodyMedium.copyWith(
                color: WhisperColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'image':
        return '📷 Photo';
      case 'voice':
        return '🎤 Voice message';
      case 'file':
        return '📎 File';
      default:
        return 'Message';
    }
  }
}
