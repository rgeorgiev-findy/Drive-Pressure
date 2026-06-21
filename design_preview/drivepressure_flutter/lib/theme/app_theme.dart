import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette — AURA liquid-glass background + APEX cockpit accents.
class AppColors {
  static const bg = Color(0xFF08111C);
  static const panel = Color(0xFF0A1420);
  static const cyan = Color(0xFF34E3FF);
  static const cyanBright = Color(0xFF3DE7FF);
  static const cyanDark = Color(0xFF13B9DC);
  static const red = Color(0xFFFF5470);
  static const redText = Color(0xFFFF7088);
  static const amber = Color(0xFFFFB02E);
  static const green = Color(0xFF34E0A6);
  static const text = Color(0xFFEAF2F8);
  static const textSoft = Color(0xFFCDD9E2);
  static const dim = Color(0xFF8AA0B2);
  static const dimmer = Color(0xFF6F8597);
  static const muted = Color(0xFF52606F);
  static const ink = Color(0xFF03141A);
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
