import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../config/theme.dart';
import '../../../../core/utils/date_formatter.dart';

/// Thin banner displayed below the chat top bar when auto-delete is active.
class AutoDeleteBadge extends StatelessWidget {
  final int? autoDeleteTimer;

  const AutoDeleteBadge({super.key, this.autoDeleteTimer});

  @override
  Widget build(BuildContext context) {
    if (autoDeleteTimer == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: WhisperSpacing.lg,
        vertical: WhisperSpacing.sm,
      ),
      color: WhisperColors.surfaceSecondary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            LucideIcons.timer,
            size: 14,
            color: WhisperColors.warning,
          ),
          const SizedBox(width: WhisperSpacing.xs),
          Text(
            'Messages auto-delete in ${DateFormatter.autoDeleteTimer(autoDeleteTimer)}',
            style: WhisperTypography.caption.copyWith(
              color: WhisperColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}
