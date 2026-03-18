import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Reusable avatar widget with cached network image and fallback initials.
class WhisperAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool showOnlineIndicator;
  final bool isOnline;

  const WhisperAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 48,
    this.showOnlineIndicator = false,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: WhisperColors.surfaceSecondary,
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  placeholder: (context, url) => _buildInitials(),
                  errorWidget: (context, url, error) => _buildInitials(),
                )
              : _buildInitials(),
        ),
        if (showOnlineIndicator && isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.22,
              height: size * 0.22,
              decoration: BoxDecoration(
                color: WhisperColors.success,
                shape: BoxShape.circle,
                border: Border.all(
                  color: WhisperColors.background,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitials() {
    final initials = _getInitials(name);
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: WhisperColors.accent,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return '?';
  }
}
