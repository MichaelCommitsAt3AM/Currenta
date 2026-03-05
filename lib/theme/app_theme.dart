// lib/core/theme/app_theme.dart
// Dark-first premium design system for Currenta.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Palette ────────────────────────────────────────────────────
  static const Color _bgDeep = Color(0xFF0A0C14);
  static const Color _bgSurface = Color(0xFF12151F);
  static const Color _bgCard = Color(0xFF1A1E2E);
  static const Color _accent = Color(0xFF6C63FF); // electric violet
  static const Color _accentAlt = Color(0xFF00D2FF); // cyan glow
  static const Color _textPrimary = Color(0xFFF0F2FF);
  static const Color _textSecondary = Color(0xFF8890B5);
  static const Color _border = Color(0xFF262A3E);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bgDeep,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          secondary: _accentAlt,
          surface: _bgSurface,
          onPrimary: Colors.white,
          onSurface: _textPrimary,
        ),
        textTheme:
            GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
          displayLarge: GoogleFonts.inter(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 28,
          ),
          titleLarge: GoogleFonts.inter(
            color: _textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            height: 1.3,
          ),
          bodyMedium: GoogleFonts.inter(
            color: _textSecondary,
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.6,
          ),
          labelSmall: GoogleFonts.inter(
            color: _textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
        cardTheme: CardThemeData(
          color: _bgCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _border, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerColor: _border,
        appBarTheme: AppBarTheme(
          backgroundColor: _bgDeep,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: GoogleFonts.inter(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
          iconTheme: const IconThemeData(color: _textPrimary),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _bgSurface,
          selectedColor: _accent.withValues(alpha: 0.2),
          labelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
            side: const BorderSide(color: _border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        ),
      );

  // ── Category Colors ────────────────────────────────────────────
  static const Map<String, Color> categoryColors = {
    'politics': Color(0xFFFF6B6B),
    'tech': Color(0xFF6C63FF),
    'science': Color(0xFF48BB78),
    'business': Color(0xFFED8936),
    'sports': Color(0xFF4299E1),
    'entertainment': Color(0xFFED64A6),
    'health': Color(0xFF38B2AC),
    'world': Color(0xFF9F7AEA),
    'environment': Color(0xFF22C55E),
  };

  static Color categoryColor(String category) =>
      categoryColors[category] ?? _accent;
}
