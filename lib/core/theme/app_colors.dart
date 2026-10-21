import 'package:flutter/material.dart';

/// Design Tokens — دايت كنج POS
/// اللوحة اللونية الكاملة للنظام (Dark Theme)
abstract final class AppColors {
  // ── Backgrounds & Surfaces ──────────────────────────────────────────────────
  static const Color background = Color(0xFF101319);
  static const Color surface = Color(0xFF101319);
  static const Color surfaceContainerLowest = Color(0xFF0B0E14);
  static const Color surfaceContainerLow = Color(0xFF191C22);
  static const Color surfaceContainer = Color(0xFF1D2026);
  static const Color surfaceContainerHigh = Color(0xFF272A31);
  static const Color surfaceContainerHighest = Color(0xFF32353B);

  // ── Primary ─────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFFFFC880);
  static const Color primaryContainer = Color(0xFFF5A623);
  static const Color primaryFixedDim = Color(0xFFFFB955);
  static const Color onPrimary = Color(0xFF452B00);
  static const Color onPrimaryContainer = Color(0xFF644000);

  // ── Secondary ───────────────────────────────────────────────────────────────
  static const Color secondary = Color(0xFFFFBA43);
  static const Color secondaryContainer = Color(0xFFDA9600);

  // ── On-Surface ───────────────────────────────────────────────────────────────
  static const Color onSurface = Color(0xFFE1E2EB);
  static const Color onSurfaceVariant = Color(0xFFD7C3AE);
  static const Color outline = Color(0xFF9F8E7A);
  static const Color outlineVariant = Color(0xFF524534);

  // ── Tertiary ─────────────────────────────────────────────────────────────────
  static const Color tertiary = Color(0xFF5BEAAD);
  static const Color tertiaryContainer = Color(0xFF38CD93);

  // ── Error & Status ───────────────────────────────────────────────────────────
  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);
  static const Color statusGreen = Color(0xFF34D399);
  static const Color statusRed = Color(0xFFF87171);

  // ── Gradient helpers ─────────────────────────────────────────────────────────
  static const LinearGradient primaryButtonGradient = LinearGradient(
    colors: [primaryContainer, primaryFixedDim, primary],
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
  );

  static const LinearGradient topBarGradient = LinearGradient(
    colors: [Color(0x00F5A623), Color(0x66F5A623), Color(0x00F5A623)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
