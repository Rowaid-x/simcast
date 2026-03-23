import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../../config/theme.dart';
import '../../../../models/message.dart';

/// Sticky bottom input bar for composing and sending messages.
class ChatInputBar extends StatefulWidget {
  final Function(String text) onSend;
  final Function(String filePath) onFileSend;
  final Function(bool isTyping) onTypingChanged;
  final Message? replyingTo;
  final VoidCallback? onCancelReply;
  final VoidCallback? onVoiceRecord;

  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.onFileSend,
    required this.onTypingChanged,
    this.replyingTo,
    this.onCancelReply,
    this.onVoiceRecord,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
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

  /// Pick image and re-encode as JPEG to fix iOS green tint.
  ///
  /// The green tint happens because iOS camera outputs BGRA / Display P3 color
  /// space. image_picker's built-in re-encode doesn't always strip the P3 ICC
  /// profile. Decoding with the `image` package and re-encoding as JPEG forces
  /// correct sRGB channel order, eliminating the tint.
  Future<String?> _pickImageFixed(ImageSource source) async {
    final xfile = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      requestFullMetadata: false,
    );
    if (xfile == null) return null;

    // Decode → re-encode as JPEG to force sRGB and fix BGRA channel swap
    final bytes = await File(xfile.path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return xfile.path;

    final jpegBytes = img.encodeJpg(decoded, quality: 85);
    final tmpDir = await getTemporaryDirectory();
    final dest =
        '${tmpDir.path}/${path.basenameWithoutExtension(xfile.path)}_fixed.jpg';
    await File(dest).writeAsBytes(jpegBytes);
    return dest;
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
      builder: (ctx) => _AttachmentSheet(
        onVoiceRecord: widget.onVoiceRecord,
        onImageFromCamera: () async {
          Navigator.pop(ctx);
          final p = await _pickImageFixed(ImageSource.camera);
          if (p != null) widget.onFileSend(p);
        },
        onImageFromGallery: () async {
          Navigator.pop(ctx);
          final p = await _pickImageFixed(ImageSource.gallery);
          if (p != null) widget.onFileSend(p);
        },
        onVideoFromGallery: () async {
          Navigator.pop(ctx);
          final xfile = await _picker.pickVideo(source: ImageSource.gallery);
          if (xfile != null) widget.onFileSend(xfile.path);
        },
        onVideoFromCamera: () async {
          Navigator.pop(ctx);
          final xfile = await _picker.pickVideo(source: ImageSource.camera);
          if (xfile != null) widget.onFileSend(xfile.path);
        },
        onFile: () async {
          Navigator.pop(ctx);
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
          if (widget.replyingTo != null) _buildReplyBar(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
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
                        onPressed: widget.onVoiceRecord,
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
                  style: WhisperTypography.caption
                      .copyWith(color: WhisperColors.textSecondary),
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

/// Attachment options bottom sheet.
class _AttachmentSheet extends StatelessWidget {
  final VoidCallback onImageFromCamera;
  final VoidCallback onImageFromGallery;
  final VoidCallback onVideoFromGallery;
  final VoidCallback onVideoFromCamera;
  final VoidCallback onFile;
  final VoidCallback? onVoiceRecord;

  const _AttachmentSheet({
    required this.onImageFromCamera,
    required this.onImageFromGallery,
    required this.onVideoFromGallery,
    required this.onVideoFromCamera,
    required this.onFile,
    this.onVoiceRecord,
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
                label: 'Photo',
                onTap: onImageFromGallery,
              ),
              _AttachmentOption(
                icon: LucideIcons.video,
                label: 'Video',
                onTap: onVideoFromGallery,
              ),
            ],
          ),
          const SizedBox(height: WhisperSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachmentOption(
                icon: LucideIcons.clapperboard,
                label: 'Record',
                onTap: onVideoFromCamera,
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
                  onVoiceRecord?.call();
                },
              ),
            ],
          ),
          SizedBox(
            height:
                MediaQuery.of(context).padding.bottom + WhisperSpacing.lg,
          ),
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
            child: Icon(icon, color: WhisperColors.accent, size: 24),
          ),
          const SizedBox(height: WhisperSpacing.sm),
          Text(label, style: WhisperTypography.caption),
        ],
      ),
    );
  }
}
