import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../config/theme.dart';

/// Shimmer loading placeholder for conversations and messages.
class ShimmerLoading extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const ShimmerLoading({
    super.key,
    this.itemCount = 8,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: WhisperColors.surfaceSecondary,
      highlightColor: WhisperColors.surfaceElevated,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }

  /// Predefined shimmer for conversation list tiles.
  static Widget conversationList() {
    return ShimmerLoading(
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WhisperSpacing.lg,
            vertical: WhisperSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: WhisperSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 200,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
