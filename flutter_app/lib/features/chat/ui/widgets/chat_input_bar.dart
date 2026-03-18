import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../config/theme.dart';
import '../../../../models/message.dart';

/// Sticky bottom input bar for composing and sending messages.
class ChatInputBar extends StatefulWidget {
  final Function(String text) onSend;
  final Function(String filePath) onFileSend;
  final Function(bool isTyping) onTypingChanged;
  final Message? replyingTo;
  final VoidCallback? onCancelReply;

  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.onFileSend,
    required this.onTypingChanged,
    this.replyingTo,
    this.onCancelReply,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
      widget.onTypingChanged(hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhisperColors.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WhisperRadius.xl),
        ),
      ),
      builder: (context) => _AttachmentSheet(
        onImageFromCamera: () async {
          Navigator.pop(context);
          final picker = ImagePicker();
          final image = await picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1920,
            maxHeight: 1920,
            imageQuality: 85,
          );
          if (image != null) widget.onFileSend(image.path);
        },
        onImageFromGallery: () async {
          Navigator.pop(context);
          final picker = ImagePicker();
          final image = await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1920,
            maxHeight: 1920,
            imageQuality: 85,
          );
          if (image != null) widget.onFileSend(image.path);
        },
        onFile: () async {
          Navigator.pop(context);
          final result = await FilePicker.platform.pickFiles(
            allowMultiple: false,
            type: FileType.any,
          );
          if (result != null && result.files.single.path != null) {
            widget.onFileSend(result.files.single.path!);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WhisperColors.surfacePrimary,
      padding: EdgeInsets.only(
        left: WhisperSpacing.md,
        right: WhisperSpacing.md,
        top: WhisperSpacing.sm,
        bottom: MediaQuery.of(context).padding.bottom + WhisperSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply preview bar
          if (widget.replyingTo != null) _buildReplyBar(),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attachment button
              IconButton(
                onPressed: _showAttachmentSheet,
                icon: const Icon(
                  LucideIcons.plus,
                  color: WhisperColors.textSecondary,
                  size: 24,
                ),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: WhisperSpacing.xs),

              // Text input
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 5,
                    minLines: 1,
                    style: WhisperTypography.bodyLarge,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: WhisperSpacing.lg,
                        vertical: WhisperSpacing.md,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(WhisperRadius.xl),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: WhisperColors.surfaceSecondary,
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
              ),
              const SizedBox(width: WhisperSpacing.xs),

              // Send / Mic button
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: _hasText
                    ? IconButton(
                        key: const ValueKey('send'),
                        onPressed: _handleSend,
                        icon: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: WhisperColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.arrowUp,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    : IconButton(
                        key: const ValueKey('mic'),
                        onPressed: () {
                          // Voice recording — placeholder for now
                        },
                        icon: const Icon(
                          LucideIcons.mic,
                          color: WhisperColors.textSecondary,
                          size: 24,
                        ),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBar() {
    final reply = widget.replyingTo!;
    return Container(
      margin: const EdgeInsets.only(bottom: WhisperSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: WhisperSpacing.md,
        vertical: WhisperSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: WhisperColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(WhisperRadius.md),
        border: Border(
          left: BorderSide(color: WhisperColors.accent, width: 2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reply.sender?.displayName ?? 'Message',
                  style: WhisperTypography.caption.copyWith(
                    color: WhisperColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  reply.content ?? 'Attachment',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WhisperTypography.caption.copyWith(
                    color: WhisperColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onCancelReply,
            icon: const Icon(
              LucideIcons.x,
              size: 16,
              color: WhisperColors.textTertiary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// Attachment options bottom sheet with a 2x2 grid.
class _AttachmentSheet extends StatelessWidget {
  final VoidCallback onImageFromCamera;
  final VoidCallback onImageFromGallery;
  final VoidCallback onFile;

  const _AttachmentSheet({
    required this.onImageFromCamera,
    required this.onImageFromGallery,
    required this.onFile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachmentOption(
                icon: LucideIcons.camera,
                label: 'Camera',
                onTap: onImageFromCamera,
              ),
              _AttachmentOption(
                icon: LucideIcons.image,
                label: 'Gallery',
                onTap: onImageFromGallery,
              ),
              _AttachmentOption(
                icon: LucideIcons.file,
                label: 'File',
                onTap: onFile,
              ),
              _AttachmentOption(
                icon: LucideIcons.mic,
                label: 'Voice',
                onTap: () {
                  Navigator.pop(context);
                  // Voice recording handled separately
                },
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + WhisperSpacing.lg),
        ],
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: WhisperColors.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(WhisperRadius.lg),
            ),
            child: Icon(
              icon,
              color: WhisperColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(height: WhisperSpacing.sm),
          Text(
            label,
            style: WhisperTypography.caption,
          ),
        ],
      ),
    );
  }
}
