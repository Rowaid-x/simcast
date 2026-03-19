import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Whisper color system — "Dark Luxury Minimal" design language.
class WhisperColors {
  WhisperColors._();

  // Backgrounds
  static const background = Color(0xFF0A0A0C);
  static const surfacePrimary = Color(0xFF141418);
  static const surfaceSecondary = Color(0xFF1C1C22);
  static const surfaceElevated = Color(0xFF222228);

  // Accent
  static const accent = Color(0xFF6C5CE7);
  static const accentLight = Color(0xFF8B7CF6);
  static Color get accentSubtle => const Color(0xFF6C5CE7).withOpacity(0.12);

  // Text
  static const textPrimary = Color(0xFFF2F2F7);
  static const textSecondary = Color(0xFF8E8E93);
  static const textTertiary = Color(0xFF48484A);

  // Semantic
  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFFF9F0A);
  static const destructive = Color(0xFFFF453A);

  // Message bubbles
  static const bubbleSent = Color(0xFF6C5CE7);
  static const bubbleSentText = Color(0xFFFFFFFF);
  static const bubbleReceived = Color(0xFF1C1C22);
  static const bubbleReceivedText = Color(0xFFF2F2F7);

  // Borders & dividers
  static const divider = Color(0xFF2C2C2E);
  static const border = Color(0xFF38383A);
}

/// Whisper typography system using Plus Jakarta Sans.
class WhisperTypography {
  WhisperTypography._();

  static TextStyle get _baseFont => GoogleFonts.plusJakartaSans();

  static TextStyle get heading1 => _baseFont.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
        color: WhisperColors.textPrimary,
      );

  static TextStyle get heading2 => _baseFont.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.3,
        color: WhisperColors.textPrimary,
      );

  static TextStyle get heading3 => _baseFont.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: WhisperColors.textPrimary,
      );

  static TextStyle get bodyLarge => _baseFont.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: WhisperColors.textPrimary,
      );

  static TextStyle get bodyMedium => _baseFont.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: WhisperColors.textPrimary,
      );

  static TextStyle get caption => _baseFont.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.2,
        color: WhisperColors.textSecondary,
      );

  static TextStyle get timestamp => _baseFont.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.2,
        letterSpacing: 0.1,
        color: WhisperColors.textTertiary,
      );
}

/// Spacing constants.
class WhisperSpacing {
  WhisperSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

/// Border radius constants.
class WhisperRadius {
  WhisperRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double full = 999.0;
}

/// Full Material theme for the app.
class WhisperTheme {
  WhisperTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: WhisperColors.background,
      colorScheme: const ColorScheme.dark(
        primary: WhisperColors.accent,
        secondary: WhisperColors.accentLight,
        surface: WhisperColors.surfacePrimary,
        error: WhisperColors.destructive,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: WhisperColors.textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: WhisperColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: WhisperTypography.heading3,
        iconTheme: const IconThemeData(
          color: WhisperColors.textPrimary,
          size: 24,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: WhisperColors.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(WhisperRadius.xl),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WhisperColors.surfaceSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WhisperRadius.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WhisperRadius.lg),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WhisperRadius.lg),
          borderSide: const BorderSide(color: WhisperColors.accent, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: WhisperSpacing.lg,
          vertical: WhisperSpacing.lg,
        ),
        hintStyle: WhisperTypography.bodyLarge.copyWith(
          color: WhisperColors.textTertiary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WhisperColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WhisperRadius.lg),
          ),
          textStyle: WhisperTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: WhisperColors.textSecondary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: WhisperColors.divider,
        thickness: 0.5,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: WhisperColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WhisperRadius.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: WhisperColors.surfaceElevated,
        contentTextStyle: WhisperTypography.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WhisperRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
