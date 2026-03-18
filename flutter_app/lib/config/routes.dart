import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/register_screen.dart';
import '../features/conversations/ui/conversations_screen.dart';
import '../features/chat/ui/chat_screen.dart';
import '../features/profile/ui/profile_screen.dart';
import '../features/settings/ui/settings_screen.dart';

/// GoRouter provider with auth-based redirect logic.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/conversations',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }
      if (isLoggedIn && isAuthRoute) {
        return '/conversations';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RegisterScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/conversations',
        name: 'conversations',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ConversationsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        name: 'chat',
        pageBuilder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return CustomTransitionPage(
            key: state.pageKey,
            child: ChatScreen(
              conversationId: conversationId,
              conversationName: extra?['name'] ?? 'Chat',
              conversationType: extra?['type'] ?? 'direct',
              otherUserAvatar: extra?['avatar'],
              isOnline: extra?['isOnline'] ?? false,
              autoDeleteTimer: extra?['autoDeleteTimer'],
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              final tween = Tween(begin: begin, end: end)
                  .chain(CurveTween(curve: Curves.easeInOutCubic));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ProfileScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
    ],
  );
});
