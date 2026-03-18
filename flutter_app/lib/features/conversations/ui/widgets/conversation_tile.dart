import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../config/theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../models/conversation.dart';
import '../../../../widgets/avatar.dart';

/// A single conversation tile in the conversations list.
class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(
          horizontal: WhisperSpacing.lg,
        ),
        child: Row(
          children: [
            // Avatar
            WhisperAvatar(
              imageUrl: conversation.displayAvatar,
              name: conversation.displayName,
              size: 48,
              showOnlineIndicator: conversation.type == 'direct',
              isOnline: conversation.isOtherUserOnline,
            ),
            const SizedBox(width: WhisperSpacing.md),

            // Name and last message
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.displayName,
                    style: WhisperTypography.bodyLarge.copyWith(
                      fontWeight: conversation.unreadCount > 0
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getLastMessagePreview(),
                    style: WhisperTypography.bodyMedium.copyWith(
                      color: conversation.unreadCount > 0
                          ? WhisperColors.textPrimary
                          : WhisperColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: WhisperSpacing.sm),

            // Timestamp and badges
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (conversation.autoDeleteTimer != null) ...[
                      const Icon(
                        LucideIcons.timer,
                        size: 12,
                        color: WhisperColors.warning,
                      ),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      _getTimestamp(),
                      style: WhisperTypography.timestamp.copyWith(
                        color: conversation.unreadCount > 0
                            ? WhisperColors.accent
                            : WhisperColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (conversation.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    constraints: const BoxConstraints(minWidth: 20),
                    decoration: BoxDecoration(
                      color: WhisperColors.accent,
                      borderRadius: BorderRadius.circular(WhisperRadius.full),
                    ),
                    child: Text(
                      conversation.unreadCount > 99
                          ? '99+'
                          : '${conversation.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getLastMessagePreview() {
    final msg = conversation.lastMessage;
    if (msg == null) return 'No messages yet';
    if (msg.isDeleted) return 'Message deleted';

    switch (msg.messageType) {
      case 'image':
        return '📷 Photo';
      case 'voice':
        return '🎤 Voice message';
      case 'file':
        return '📎 ${msg.fileName ?? "File"}';
      default:
        return msg.content ?? '';
    }
  }

  String _getTimestamp() {
    final msg = conversation.lastMessage;
    if (msg != null) {
      return DateFormatter.conversationTime(msg.createdAt);
    }
    return DateFormatter.conversationTime(conversation.updatedAt);
  }
}
