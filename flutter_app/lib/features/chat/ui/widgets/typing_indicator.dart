import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../config/theme.dart';

/// Animated typing indicator showing three pulsing dots.
class TypingIndicator extends StatelessWidget {
  final List<String> typingUserNames;

  const TypingIndicator({
    super.key,
    required this.typingUserNames,
  });

  @override
  Widget build(BuildContext context) {
    if (typingUserNames.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(
        left: WhisperSpacing.lg,
        bottom: WhisperSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: WhisperSpacing.md,
              vertical: WhisperSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: WhisperColors.bubbleReceived,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(WhisperRadius.lg),
                topRight: Radius.circular(WhisperRadius.lg),
                bottomLeft: Radius.circular(WhisperRadius.sm),
                bottomRight: Radius.circular(WhisperRadius.lg),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 3),
                _buildDot(1),
                const SizedBox(width: 3),
                _buildDot(2),
              ],
            ),
          ),
          const SizedBox(width: WhisperSpacing.sm),
          Text(
            _buildTypingText(),
            style: WhisperTypography.caption.copyWith(
              color: WhisperColors.textTertiary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildDot(int index) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: WhisperColors.textTertiary,
        shape: BoxShape.circle,
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(reverse: true),
        )
        .scale(
          begin: const Offset(0.6, 0.6),
          end: const Offset(1.0, 1.0),
          duration: 600.ms,
          delay: Duration(milliseconds: index * 150),
          curve: Curves.easeInOut,
        );
  }

  String _buildTypingText() {
    if (typingUserNames.length == 1) {
      return '${typingUserNames.first} is typing';
    }
    if (typingUserNames.length == 2) {
      return '${typingUserNames[0]} and ${typingUserNames[1]} are typing';
    }
    return 'Several people are typing';
  }
}
