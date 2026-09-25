import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Central theme for the whole app. Because most screens use plain
/// Material widgets (AppBar, Card, ElevatedButton, TextField, ListTile),
/// setting these component themes once here restyles the entire app
/// consistently without needing to touch every screen individually.
class AppTheme {
  AppTheme._();

  static TextTheme get _textTheme {
    final base = GoogleFonts.nunitoTextTheme();
    return base.copyWith(
      // Big display/heading text uses the slab-serif "signage" font.
      displayLarge: GoogleFonts.alfaSlabOne(fontSize: 40, color: AppColors.brown, height: 1.1),
      displayMedium: GoogleFonts.alfaSlabOne(fontSize: 30, color: AppColors.brown, height: 1.15),
      headlineLarge: GoogleFonts.alfaSlabOne(fontSize: 24, color: AppColors.brown),
      headlineMedium: GoogleFonts.alfaSlabOne(fontSize: 20, color: AppColors.brown),
      titleLarge: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.brown),
      titleMedium: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.brown),
      bodyLarge: GoogleFonts.nunito(fontSize: 16, color: AppColors.brown),
      bodyMedium: GoogleFonts.nunito(fontSize: 14, color: AppColors.brown),
      labelLarge: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.white),
    );
  }

  static ThemeData get themeData {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.rust,
      primary: AppColors.rust,
      secondary: AppColors.teal,
      tertiary: AppColors.gold,
      error: AppColors.stopRed,
      surface: AppColors.cream,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: _textTheme,
      fontFamily: GoogleFonts.nunito().fontFamily,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.brown,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.alfaSlabOne(fontSize: 20, color: AppColors.white),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),

      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: AppColors.rust,
        textColor: AppColors.brown,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.rust,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.rust.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)), // pill
          elevation: 0,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.teal,
          textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.brown,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.rust, width: 2),
        ),
        labelStyle: GoogleFonts.nunito(color: AppColors.brown.withValues(alpha: 0.7)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cream,
        labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.brown),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
      ),

      dividerTheme: const DividerThemeData(color: AppColors.cardBorder, thickness: 1),

      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: GoogleFonts.nunito(color: AppColors.brown),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.rust),
    );
  }
}
