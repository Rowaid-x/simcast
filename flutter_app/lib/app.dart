import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'config/routes.dart';

/// Root application widget for Whisper.
class WhisperApp extends ConsumerWidget {
  const WhisperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Whisper',
      debugShowCheckedModeBanner: false,
      theme: WhisperTheme.darkTheme,
      routerConfig: router,
    );
  }
}
