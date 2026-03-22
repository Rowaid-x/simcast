import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'config/theme.dart';
import 'config/routes.dart';
import 'features/conversations/providers/conversation_provider.dart';

/// Root application widget for Whisper.
class WhisperApp extends ConsumerStatefulWidget {
  const WhisperApp({super.key});

  @override
  ConsumerState<WhisperApp> createState() => _WhisperAppState();
}

class _WhisperAppState extends ConsumerState<WhisperApp> {
  StreamSubscription<InAppNotification>? _bannerSub;
  OverlayEntry? _bannerEntry;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _bannerSub = inAppNotificationStream.stream.listen(_showBanner);
  }

  @override
  void dispose() {
    _bannerSub?.cancel();
    _bannerTimer?.cancel();
    _bannerEntry?.remove();
    super.dispose();
  }

  void _showBanner(InAppNotification notification) {
    _dismissBanner();

    final GoRouter router = ref.read(routerProvider);
    final overlayState =
        router.routerDelegate.navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _bannerEntry = OverlayEntry(
      builder: (_) => _InAppBanner(
        notification: notification,
        onTap: () {
          _dismissBanner();
          router.push('/chat/${notification.conversationId}', extra: {
            'name': notification.conversationName,
            'type': 'direct',
          });
        },
        onDismiss: _dismissBanner,
      ),
    );

    overlayState.insert(_bannerEntry!);
    _bannerTimer = Timer(const Duration(seconds: 4), _dismissBanner);
  }

  void _dismissBanner() {
    _bannerTimer?.cancel();
    _bannerEntry?.remove();
    _bannerEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Whisper',
      debugShowCheckedModeBanner: false,
      theme: WhisperTheme.darkTheme,
      routerConfig: router,
    );
  }
}

/// Slide-in banner shown at the top of the screen for incoming messages.
class _InAppBanner extends StatefulWidget {
  final InAppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InAppBanner({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_InAppBanner> createState() => _InAppBannerState();
}

class _InAppBannerState extends State<_InAppBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;

    return Positioned(
      top: safeTop + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: WhisperColors.surfaceElevated,
                borderRadius: BorderRadius.circular(WhisperRadius.lg),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: WhisperColors.accent.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.notification.conversationName.isNotEmpty
                            ? widget.notification.conversationName[0]
                                .toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: WhisperColors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.notification.senderName ??
                              widget.notification.conversationName,
                          style: WhisperTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.notification.messagePreview,
                          style: WhisperTypography.bodyMedium.copyWith(
                            color: WhisperColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onDismiss,
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: WhisperColors.textTertiary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
