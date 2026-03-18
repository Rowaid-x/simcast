import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../widgets/avatar.dart';
import '../providers/chat_provider.dart';
import 'chat_settings_sheet.dart';
import 'widgets/auto_delete_badge.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/message_bubble.dart';
import 'widgets/typing_indicator.dart';

/// Main chat screen for a conversation with real-time messaging.
class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String conversationName;
  final String conversationType;
  final String? otherUserAvatar;
  final bool isOnline;
  final int? autoDeleteTimer;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.conversationName,
    this.conversationType = 'direct',
    this.otherUserAvatar,
    this.isOnline = false,
    this.autoDeleteTimer,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  String? _currentUserId;
  String? _replyToId;
  int? _currentAutoDeleteTimer;

  @override
  void initState() {
    super.initState();
    _currentAutoDeleteTimer = widget.autoDeleteTimer;
    _loadUserId();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadUserId() async {
    final userId = await SecureStorage.getUserId();
    if (mounted) setState(() => _currentUserId = userId);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatProvider(widget.conversationId).notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showChatSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ChatSettingsSheet(
        conversationId: widget.conversationId,
        currentTimer: _currentAutoDeleteTimer,
      ),
    ).then((newTimer) {
      if (newTimer != null || newTimer != _currentAutoDeleteTimer) {
        setState(() => _currentAutoDeleteTimer = newTimer);
      }
    });
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhisperColors.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WhisperRadius.xl),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: WhisperSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: WhisperColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: WhisperSpacing.lg),
            ListTile(
              leading: const Icon(LucideIcons.timer,
                  color: WhisperColors.textSecondary, size: 20),
              title: Text('Chat settings',
                  style: WhisperTypography.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                _showChatSettings();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.trash2,
                  color: WhisperColors.textSecondary, size: 20),
              title: Text('Clear chat',
                  style: WhisperTypography.bodyLarge),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            if (widget.conversationType == 'direct')
              ListTile(
                leading: const Icon(LucideIcons.ban,
                    color: WhisperColors.destructive, size: 20),
                title: Text('Block user',
                    style: WhisperTypography.bodyLarge
                        .copyWith(color: WhisperColors.destructive)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            if (widget.conversationType == 'group')
              ListTile(
                leading: const Icon(LucideIcons.users,
                    color: WhisperColors.textSecondary, size: 20),
                title: Text('Group info',
                    style: WhisperTypography.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: WhisperSpacing.lg),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.conversationId));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            _buildTopBar(),

            // Auto-delete badge
            AutoDeleteBadge(autoDeleteTimer: _currentAutoDeleteTimer),

            // Messages list
            Expanded(
              child: chatState.isLoading && chatState.messages.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: WhisperColors.accent,
                        strokeWidth: 2,
                      ),
                    )
                  : chatState.error != null && chatState.messages.isEmpty
                      ? _buildErrorState(chatState.error!)
                      : _buildMessagesList(chatState),
            ),

            // Typing indicator
            TypingIndicator(
              typingUserNames: chatState.typingUsers.keys.toList(),
            ),

            // Input bar
            ChatInputBar(
              onSend: (text) {
                ref
                    .read(chatProvider(widget.conversationId).notifier)
                    .sendMessage(
                      content: text,
                      replyTo: _replyToId,
                    );
                setState(() => _replyToId = null);
              },
              onFileSend: (filePath) {
                ref
                    .read(chatProvider(widget.conversationId).notifier)
                    .sendFile(filePath);
              },
              onTypingChanged: (isTyping) {
                ref
                    .read(chatProvider(widget.conversationId).notifier)
                    .onTypingChanged(isTyping);
              },
              replyingTo: _replyToId != null
                  ? chatState.messages
                      .where((m) => m.id == _replyToId)
                      .firstOrNull
                  : null,
              onCancelReply: () {
                setState(() => _replyToId = null);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: WhisperSpacing.sm,
        vertical: WhisperSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(
              LucideIcons.arrowLeft,
              color: WhisperColors.textPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: WhisperSpacing.xs),
          WhisperAvatar(
            imageUrl: widget.otherUserAvatar,
            name: widget.conversationName,
            size: 36,
            showOnlineIndicator: widget.conversationType == 'direct',
            isOnline: widget.isOnline,
          ),
          const SizedBox(width: WhisperSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.conversationName,
                  style: WhisperTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.conversationType == 'direct')
                  Text(
                    widget.isOnline ? 'online' : 'offline',
                    style: WhisperTypography.caption.copyWith(
                      color: widget.isOnline
                          ? WhisperColors.success
                          : WhisperColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              LucideIcons.phone,
              color: WhisperColors.textSecondary,
              size: 20,
            ),
          ),
          IconButton(
            onPressed: _showMenu,
            icon: const Icon(
              LucideIcons.moreVertical,
              color: WhisperColors.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ChatState chatState) {
    final messages = chatState.messages;
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.messageCircle,
              size: 48,
              color: WhisperColors.textTertiary.withOpacity(0.5),
            ),
            const SizedBox(height: WhisperSpacing.lg),
            Text(
              'No messages yet',
              style: WhisperTypography.bodyLarge.copyWith(
                color: WhisperColors.textSecondary,
              ),
            ),
            const SizedBox(height: WhisperSpacing.xs),
            Text(
              'Send a message to start the conversation',
              style: WhisperTypography.bodyMedium.copyWith(
                color: WhisperColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: WhisperSpacing.sm),
      itemCount: messages.length + (chatState.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Loading indicator at the bottom (oldest messages)
        if (index == messages.length) {
          return const Padding(
            padding: EdgeInsets.all(WhisperSpacing.lg),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: WhisperColors.accent,
                ),
              ),
            ),
          );
        }

        final message = messages[index];
        final isSent = _currentUserId != null &&
            message.isSentBy(_currentUserId!);

        // Date separator logic
        Widget? dateSeparator;
        if (index < messages.length - 1) {
          final nextMessage = messages[index + 1];
          if (!_isSameDay(message.createdAt, nextMessage.createdAt)) {
            dateSeparator = _buildDateSeparator(message.createdAt);
          }
        } else {
          // First message (oldest) always has a date separator
          dateSeparator = _buildDateSeparator(message.createdAt);
        }

        // Mark as read if it's a received message
        if (!isSent && !message.isRead) {
          ref
              .read(chatProvider(widget.conversationId).notifier)
              .markAsRead(message.id);
        }

        return Column(
          children: [
            if (dateSeparator != null) dateSeparator,
            MessageBubble(
              message: message,
              isSent: isSent,
              showSenderName: widget.conversationType == 'group',
              onLongPress: () => _showMessageOptions(message, isSent),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WhisperSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: WhisperSpacing.md,
            vertical: WhisperSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: WhisperColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(WhisperRadius.full),
          ),
          child: Text(
            DateFormatter.dateSeparator(date),
            style: WhisperTypography.caption.copyWith(
              color: WhisperColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showMessageOptions(message, bool isSent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhisperColors.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WhisperRadius.xl),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: WhisperSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: WhisperColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: WhisperSpacing.lg),
            ListTile(
              leading: const Icon(LucideIcons.reply,
                  color: WhisperColors.textSecondary, size: 20),
              title: Text('Reply', style: WhisperTypography.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyToId = message.id);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.copy,
                  color: WhisperColors.textSecondary, size: 20),
              title: Text('Copy text', style: WhisperTypography.bodyLarge),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            if (isSent)
              ListTile(
                leading: const Icon(LucideIcons.trash2,
                    color: WhisperColors.destructive, size: 20),
                title: Text('Delete',
                    style: WhisperTypography.bodyLarge
                        .copyWith(color: WhisperColors.destructive)),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(chatProvider(widget.conversationId).notifier)
                      .deleteMessage(message.id);
                },
              ),
            const SizedBox(height: WhisperSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            LucideIcons.alertTriangle,
            size: 48,
            color: WhisperColors.textTertiary,
          ),
          const SizedBox(height: WhisperSpacing.lg),
          Text(
            error,
            style: WhisperTypography.bodyLarge.copyWith(
              color: WhisperColors.textSecondary,
            ),
          ),
          const SizedBox(height: WhisperSpacing.lg),
          ElevatedButton(
            onPressed: () => ref.invalidate(chatProvider(widget.conversationId)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
