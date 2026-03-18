import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../config/theme.dart';

/// Voice recording overlay with waveform visualization.
class VoiceRecorder extends StatefulWidget {
  final Function(String filePath) onRecordingComplete;
  final VoidCallback onCancel;

  const VoiceRecorder({
    super.key,
    required this.onRecordingComplete,
    required this.onCancel,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  Duration _duration = Duration.zero;
  Timer? _timer;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      widget.onCancel();
      return;
    }

    final dir = await getTemporaryDirectory();
    _filePath =
        '${dir.path}/whisper_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _filePath!,
    );

    setState(() => _isRecording = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _duration += const Duration(seconds: 1));
      }
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (path != null) {
      widget.onRecordingComplete(path);
    } else {
      widget.onCancel();
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    await _recorder.stop();
    widget.onCancel();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WhisperColors.surfacePrimary,
      padding: EdgeInsets.only(
        left: WhisperSpacing.lg,
        right: WhisperSpacing.lg,
        top: WhisperSpacing.md,
        bottom: MediaQuery.of(context).padding.bottom + WhisperSpacing.md,
      ),
      child: Row(
        children: [
          // Cancel button
          IconButton(
            onPressed: _cancelRecording,
            icon: const Icon(
              LucideIcons.trash2,
              color: WhisperColors.destructive,
              size: 22,
            ),
          ),

          const SizedBox(width: WhisperSpacing.md),

          // Recording indicator and timer
          Expanded(
            child: Row(
              children: [
                // Pulsing red dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? WhisperColors.destructive
                        : WhisperColors.textTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: WhisperSpacing.sm),
                Text(
                  _formatDuration(_duration),
                  style: WhisperTypography.bodyLarge.copyWith(
                    color: WhisperColors.textPrimary,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: WhisperSpacing.md),
                // Simple waveform bars
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      24,
                      (i) => Container(
                        width: 3,
                        height: (4 + (i % 7) * 3 + (_isRecording ? 2 : 0))
                            .toDouble(),
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: WhisperColors.accent.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: WhisperSpacing.md),

          // Send button
          IconButton(
            onPressed: _stopRecording,
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
          ),
        ],
      ),
    );
  }
}
