import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../widgets/avatar.dart';
import '../../conversations/providers/conversation_provider.dart';
import '../providers/chat_provider.dart';
import 'chat_settings_sheet.dart';
import 'group_info_sheet.dart';
import 'widgets/auto_delete_badge.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/message_bubble.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/voice_recorder.dart';

/// Main chat screen for a conversation with real-time messaging.
class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String conversationName;
  final String conversationType;
  final String? otherUserAvatar;
  final bool isOnline;
  final int? autoDeleteTimer;
  final int memberCount;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.conversationName,
    this.conversationType = 'direct',
    this.otherUserAvatar,
    this.isOnline = false,
    this.autoDeleteTimer,
    this.memberCount = 0,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  String? _currentUserId;
  String? _replyToId;
  int? _currentAutoDeleteTimer;
  bool _showScrollToBottom = false;
  bool _isRecordingVoice = false;
  bool _hasMarkedRead = false;

  @override
  void initState() {
    super.initState();
    _currentAutoDeleteTimer = widget.autoDeleteTimer;
    _loadUserId();
    _scrollController.addListener(_onScroll);
    // Mark this conversation as active so unread count doesn't increment
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeConversationIdProvider.notifier).state = widget.conversationId;
    });
  }

  Future<void> _loadUserId() async {
    final userId = await SecureStorage.getUserId();
    if (mounted) setState(() => _currentUserId = userId);
  }

  /// Mark all messages as read and scroll to oldest unread on first load.
  Future<void> _markReadAndScrollToUnread() async {
    if (_hasMarkedRead || _currentUserId == null) return;
    final chatNotifier = ref.read(chatProvider(widget.conversationId).notifier);
    final chatState = ref.read(chatProvider(widget.conversationId));
    if (chatState.messages.isEmpty) return;

    // Find first unread index BEFORE marking all as read
    final unreadIdx = chatNotifier.firstUnreadIndex(_currentUserId!);

    // Mark all as read (async with REST fallback if WS is down)
    await chatNotifier.markAllAsRead(_currentUserId!);
    _hasMarkedRead = true;

    // Also clear unread badge in conversation list
    ref.read(conversationsProvider.notifier).markAsRead(widget.conversationId);

    // Scroll to the oldest unread message if it's not visible
    if (unreadIdx != null && unreadIdx > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // Each message is roughly 70px tall; estimate position
          // Using animateTo with index * estimated height
          final targetOffset = unreadIdx * 72.0;
          final maxScroll = _scrollController.position.maxScrollExtent;
          _scrollController.animateTo(
            targetOffset.clamp(0, maxScroll),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _onScroll() {
    // Load more when near the top (oldest messages)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatProvider(widget.conversationId).notifier).loadMore();
    }
    // Show/hide scroll-to-bottom FAB
    final shouldShow = _scrollController.position.pixels > 300;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    // Clear active conversation so unread count resumes
    ref.read(activeConversationIdProvider.notifier).state = null;
    // Sync server-side unread count back to the conversation list
    ref.read(conversationsProvider.notifier).refresh();
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

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GroupInfoSheet(
        conversationId: widget.conversationId,
        conversationName: widget.conversationName,
      ),
    );
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
                  _showGroupInfo();
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

    // Mark all messages as read and scroll to first unread on initial load
    if (!_hasMarkedRead && chatState.messages.isNotEmpty && _currentUserId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markReadAndScrollToUnread();
      });
    }

    // React to real-time timer updates from WebSocket
    if (chatState.timerUpdated &&
        chatState.autoDeleteTimer != _currentAutoDeleteTimer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _currentAutoDeleteTimer = chatState.autoDeleteTimer);
        }
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            _buildTopBar(),

            // Auto-delete badge
            AutoDeleteBadge(autoDeleteTimer: _currentAutoDeleteTimer),

            // Messages list with scroll-to-bottom FAB
            Expanded(
              child: Stack(
                children: [
                  chatState.isLoading && chatState.messages.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: WhisperColors.accent,
                            strokeWidth: 2,
                          ),
                        )
                      : chatState.error != null && chatState.messages.isEmpty
                          ? _buildErrorState(chatState.error!)
                          : RefreshIndicator(
                              onRefresh: () => ref
                                  .read(chatProvider(widget.conversationId)
                                      .notifier)
                                  .refresh(),
                              color: WhisperColors.accent,
                              backgroundColor: WhisperColors.surfacePrimary,
                              child: _buildMessagesList(chatState),
                            ),
                  // Scroll-to-bottom FAB
                  if (_showScrollToBottom)
                    Positioned(
                      right: WhisperSpacing.lg,
                      bottom: WhisperSpacing.lg,
                      child: GestureDetector(
                        onTap: _scrollToBottom,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: WhisperColors.surfaceElevated,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: WhisperColors.divider,
                              width: 0.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.chevronDown,
                            color: WhisperColors.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Typing indicator
            TypingIndicator(
              typingUserNames: chatState.typingUsers.keys.toList(),
            ),

            // Voice recorder overlay or input bar
            if (_isRecordingVoice)
              VoiceRecorder(
                onRecordingComplete: (filePath) {
                  setState(() => _isRecordingVoice = false);
                  ref
                      .read(chatProvider(widget.conversationId).notifier)
                      .sendFile(filePath);
                },
                onCancel: () {
                  setState(() => _isRecordingVoice = false);
                },
              )
            else
              ChatInputBar(
                onSend: (text) {
                  HapticFeedback.lightImpact();
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
                onVoiceRecord: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _isRecordingVoice = true);
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
                Text(
                  widget.conversationType == 'direct'
                      ? (widget.isOnline ? 'online' : 'offline')
                      : widget.memberCount > 0
                          ? '${widget.memberCount} members'
                          : 'group',
                  style: WhisperTypography.caption.copyWith(
                    color: widget.isOnline && widget.conversationType == 'direct'
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
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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

        return Column(
          children: [
            if (dateSeparator != null) dateSeparator,
            _SwipeToReply(
              onReply: () => setState(() => _replyToId = message.id),
              isSent: isSent,
              child: MessageBubble(
                message: message,
                isSent: isSent,
                showSenderName: widget.conversationType == 'group',
                onLongPress: () => _showMessageOptions(message, isSent),
                onRetry: message.isFailed
                    ? () => ref
                        .read(chatProvider(widget.conversationId).notifier)
                        .retryMessage(message.id)
                    : null,
              ),
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
    HapticFeedback.mediumImpact();
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
            if (message.content != null && message.content!.isNotEmpty)
              ListTile(
                leading: const Icon(LucideIcons.copy,
                    color: WhisperColors.textSecondary, size: 20),
                title: Text('Copy text', style: WhisperTypography.bodyLarge),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content!));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1),
                      backgroundColor: WhisperColors.surfaceElevated,
                    ),
                  );
                },
              ),
            if (isSent)
              ListTile(
                leading: const Icon(LucideIcons.info,
                    color: WhisperColors.textSecondary, size: 20),
                title: Text('Message info', style: WhisperTypography.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _showMessageInfo(message);
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
                  _confirmDeleteMessage(message.id);
                },
              ),
            const SizedBox(height: WhisperSpacing.lg),
          ],
        ),
      ),
    );
  }

  void _showMessageInfo(message) {
    final sentTime = DateFormatter.messageTime(message.createdAt);
    final sentDate = DateFormatter.dateSeparator(message.createdAt);

    showModalBottomSheet(
      context: context,
      backgroundColor: WhisperColors.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WhisperRadius.xl),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WhisperSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: WhisperColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: WhisperSpacing.xl),
              Text('Message Info', style: WhisperTypography.heading3),
              const SizedBox(height: WhisperSpacing.xl),
              // Read status
              Row(
                children: [
                  Icon(
                    message.isRead ? LucideIcons.checkCheck : LucideIcons.check,
                    size: 20,
                    color: message.isRead
                        ? WhisperColors.accent
                        : WhisperColors.textTertiary,
                  ),
                  const SizedBox(width: WhisperSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.isRead ? 'Read' : 'Delivered',
                          style: WhisperTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // TODO: Show actual read timestamp when backend supports it
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: WhisperSpacing.lg),
              const Divider(color: WhisperColors.divider),
              const SizedBox(height: WhisperSpacing.lg),
              // Sent time
              Row(
                children: [
                  const Icon(
                    LucideIcons.send,
                    size: 20,
                    color: WhisperColors.textTertiary,
                  ),
                  const SizedBox(width: WhisperSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sent', style: WhisperTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                        Text(
                          '$sentDate at $sentTime',
                          style: WhisperTypography.caption.copyWith(
                            color: WhisperColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: WhisperSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteMessage(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WhisperColors.surfaceElevated,
        title: Text('Delete message?', style: WhisperTypography.heading3),
        content: Text(
          'This message will be permanently deleted.',
          style: WhisperTypography.bodyMedium.copyWith(
            color: WhisperColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(chatProvider(widget.conversationId).notifier)
                  .deleteMessage(messageId);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: WhisperColors.destructive),
            ),
          ),
        ],
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

/// Swipe-to-reply gesture wrapper for message bubbles.
/// Swipe right on received messages, left on sent messages to trigger reply.
class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool isSent;

  const _SwipeToReply({
    required this.child,
    required this.onReply,
    required this.isSent,
  });

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragOffset = 0;
  static const _threshold = 60.0;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      if (widget.isSent) {
        // Sent messages: swipe left (negative)
        _dragOffset = (_dragOffset + details.delta.dx).clamp(-_threshold * 1.5, 0);
      } else {
        // Received messages: swipe right (positive)
        _dragOffset = (_dragOffset + details.delta.dx).clamp(0, _threshold * 1.5);
      }
    });
    if (_dragOffset.abs() >= _threshold && !_triggered) {
      _triggered = true;
      HapticFeedback.lightImpact();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_triggered) {
      widget.onReply();
    }
    _triggered = false;
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final replyIconOpacity = (_dragOffset.abs() / _threshold).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        alignment: widget.isSent ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          // Reply icon that appears behind the bubble
          if (_dragOffset.abs() > 10)
            Positioned(
              left: widget.isSent ? null : 8,
              right: widget.isSent ? 8 : null,
              child: Opacity(
                opacity: replyIconOpacity,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: WhisperColors.accent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.reply,
                    size: 16,
                    color: WhisperColors.accent,
                  ),
                ),
              ),
            ),
          // The message bubble, offset by drag
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
