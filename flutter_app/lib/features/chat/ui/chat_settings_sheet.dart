import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../conversations/providers/conversation_provider.dart';

/// Bottom sheet for configuring auto-delete timer and other chat settings.
class ChatSettingsSheet extends ConsumerStatefulWidget {
  final String conversationId;
  final int? currentTimer;

  const ChatSettingsSheet({
    super.key,
    required this.conversationId,
    this.currentTimer,
  });

  @override
  ConsumerState<ChatSettingsSheet> createState() => _ChatSettingsSheetState();
}

class _ChatSettingsSheetState extends ConsumerState<ChatSettingsSheet> {
  late int? _selectedTimer;
  bool _isSaving = false;

  static const List<int?> _timerOptions = [
    null,
    1800,
    3600,
    21600,
    86400,
    604800,
  ];

  @override
  void initState() {
    super.initState();
    _selectedTimer = widget.currentTimer;
  }

  Future<void> _applyTimer() async {
    if (_selectedTimer == widget.currentTimer) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(conversationRepositoryProvider);
      await repo.updateConversation(
        widget.conversationId,
        autoDeleteTimer: _selectedTimer,
      );
      // Refresh conversations list
      ref.read(conversationsProvider.notifier).refresh();
      if (mounted) {
        Navigator.pop(context, _selectedTimer);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update timer: $e'),
            backgroundColor: WhisperColors.surfaceElevated,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + WhisperSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: WhisperColors.surfacePrimary,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WhisperRadius.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: WhisperSpacing.sm),
          // Handle bar
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: WhisperColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: WhisperSpacing.xl),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WhisperSpacing.xl),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: WhisperColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(WhisperRadius.md),
                  ),
                  child: const Icon(
                    LucideIcons.timer,
                    color: WhisperColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: WhisperSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disappearing Messages',
                      style: WhisperTypography.heading3,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: WhisperSpacing.sm),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WhisperSpacing.xl),
            child: Text(
              'When enabled, new messages will be automatically deleted after the selected time.',
              style: WhisperTypography.bodyMedium.copyWith(
                color: WhisperColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: WhisperSpacing.xl),

          // Timer options
          ...List.generate(_timerOptions.length, (index) {
            final timer = _timerOptions[index];
            final isSelected = _selectedTimer == timer;
            return _buildTimerOption(timer, isSelected);
          }),

          const SizedBox(height: WhisperSpacing.xl),

          // Apply button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WhisperSpacing.xl),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _applyTimer,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Apply'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerOption(int? timer, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedTimer = timer),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: WhisperSpacing.xl,
          vertical: WhisperSpacing.xs,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: WhisperSpacing.lg,
          vertical: WhisperSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? WhisperColors.accentSubtle
              : WhisperColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(WhisperRadius.md),
          border: Border.all(
            color: isSelected ? WhisperColors.accent : WhisperColors.border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              timer == null ? LucideIcons.timerOff : LucideIcons.timer,
              size: 18,
              color: isSelected
                  ? WhisperColors.accent
                  : WhisperColors.textSecondary,
            ),
            const SizedBox(width: WhisperSpacing.md),
            Text(
              DateFormatter.autoDeleteTimer(timer),
              style: WhisperTypography.bodyLarge.copyWith(
                color: isSelected
                    ? WhisperColors.accent
                    : WhisperColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(
                LucideIcons.check,
                size: 18,
                color: WhisperColors.accent,
              ),
          ],
        ),
      ),
    );
  }
}
