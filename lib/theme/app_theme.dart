import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette — FORGE dark automotive theme with orange accent.
class AppColors {
  static const bg        = Color(0xFF080C10);
  static const panel     = Color(0xFF0C1018);
  static const ink       = Color(0xFF180900);   // dark text on orange buttons

  // Primary accent — orange (replaces the old cyan)
  static const cyan      = Color(0xFFFF6A18);   // "cyan" kept for compat — now orange
  static const cyanBright= Color(0xFFFF7D2E);
  static const cyanDark  = Color(0xFFE05210);

  // Named aliases for new code
  static const orange       = Color(0xFFFF6A18);
  static const orangeBright = Color(0xFFFF7D2E);
  static const orangeDark   = Color(0xFFE05210);

  // Status colours (unchanged)
  static const red     = Color(0xFFFF5470);
  static const redText = Color(0xFFFF7088);
  static const amber   = Color(0xFFFFB02E);
  static const green   = Color(0xFF34E0A6);

  // Text ramp (unchanged)
  static const text     = Color(0xFFEAF2F8);
  static const textSoft = Color(0xFFCDD9E2);
  static const dim      = Color(0xFF8AA0B2);
  static const dimmer   = Color(0xFF6F8597);
  static const muted    = Color(0xFF52606F);
}

/// Typography helpers (google_fonts, loaded at runtime).
class AppText {
  static TextStyle chakra({
    double size = 16,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.text,
    double spacing = 0,
  }) =>
      GoogleFonts.chakraPetch(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        height: 1.1,
      );

  static TextStyle mono({
    double size = 12,
    Color color = AppColors.dimmer,
    double spacing = 0.5,
  }) =>
      GoogleFonts.shareTechMono(
        fontSize: size,
        color: color,
        letterSpacing: spacing,
      );

  static TextStyle sora({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.text,
  }) =>
      GoogleFonts.sora(fontSize: size, fontWeight: weight, color: color);
}
