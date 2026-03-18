import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../config/theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../models/message.dart';
import 'voice_player.dart';

/// A single message bubble with support for text, image, voice, and file types.
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isSent;
  final bool showSenderName;
  final VoidCallback? onLongPress;
  final VoidCallback? onReply;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isSent,
    this.showSenderName = false,
    this.onLongPress,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return _buildDeletedBubble();
    }

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: EdgeInsets.only(
            left: isSent ? 48 : WhisperSpacing.lg,
            right: isSent ? WhisperSpacing.lg : 48,
            bottom: WhisperSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment:
                isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Sender name (groups)
              if (showSenderName && !isSent && message.sender != null)
                Padding(
                  padding: const EdgeInsets.only(
                    left: WhisperSpacing.md,
                    bottom: 2,
                  ),
                  child: Text(
                    message.sender!.displayName,
                    style: WhisperTypography.caption.copyWith(
                      color: WhisperColors.accent,
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
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, duration: 200.ms);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (message.fileUrl != null)
          CachedNetworkImage(
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
    return Padding(
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
                Text(
                  DateFormatter.fileSize(message.fileSize),
                  style: TextStyle(
                    fontSize: 12,
                    color: isSent
                        ? WhisperColors.bubbleSentText.withOpacity(0.7)
                        : WhisperColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                _buildTimestamp(),
              ],
            ),
          ),
        ],
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
