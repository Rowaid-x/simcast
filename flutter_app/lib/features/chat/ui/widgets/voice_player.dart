import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../config/theme.dart';

/// Inline voice message player with progress bar and duration.
class VoicePlayer extends StatefulWidget {
  final String audioUrl;
  final bool isSent;

  const VoicePlayer({
    super.key,
    required this.audioUrl,
    this.isSent = false,
  });

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  final _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _durationSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _positionSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.audioUrl));
    }
  }

  void _seekToPosition(double dx, BuildContext context) {
    if (_duration.inMilliseconds <= 0) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    // Account for the play button width (~48px) and padding
    final barWidth = box.size.width - 48;
    if (barWidth <= 0) return;
    final adjustedDx = (dx).clamp(0.0, barWidth);
    final fraction = adjustedDx / barWidth;
    final seekPosition = Duration(
      milliseconds: (fraction * _duration.inMilliseconds).round(),
    );
    _player.seek(seekPosition);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    final accentColor = widget.isSent ? Colors.white : WhisperColors.accent;
    final dimColor = widget.isSent
        ? Colors.white.withOpacity(0.4)
        : WhisperColors.accent.withOpacity(0.3);
    final textColor = widget.isSent
        ? Colors.white.withOpacity(0.7)
        : WhisperColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause button
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.isSent
                  ? Colors.white.withOpacity(0.2)
                  : WhisperColors.accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? LucideIcons.pause : LucideIcons.play,
              size: 18,
              color: accentColor,
            ),
          ),
        ),
        const SizedBox(width: WhisperSpacing.sm),

        // Progress bar and duration
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Waveform-style progress bar with seek
              GestureDetector(
                onTapDown: (details) => _seekToPosition(details.localPosition.dx, context),
                onHorizontalDragUpdate: (details) => _seekToPosition(details.localPosition.dx, context),
                child: SizedBox(
                  height: 24,
                  child: Row(
                    children: List.generate(28, (i) {
                      final barProgress = i / 28;
                      final isActive = barProgress <= progress;
                      // Pseudo-random heights based on index
                      final heightFactor = 0.3 + (((i * 7 + 3) % 5) / 5) * 0.7;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          decoration: BoxDecoration(
                            color: isActive ? accentColor : dimColor,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                          height: 24 * heightFactor,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Duration text
              Text(
                isPlaying || _position > Duration.zero
                    ? _formatDuration(_position)
                    : _duration > Duration.zero
                        ? _formatDuration(_duration)
                        : '00:00',
                style: TextStyle(
                  fontSize: 11,
                  color: textColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
