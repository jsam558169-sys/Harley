import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Central theme for the whole app. Same "Motor Café" palette as before,
/// but flatter and quieter: white app bars with a hairline divider,
/// 1px borders, consistent corner radii (10 inputs/buttons, 14 cards,
/// 18 dialogs), and the slab-serif font reserved for headings only.
class AppTheme {
  AppTheme._();

  static TextTheme get _textTheme {
    final base = GoogleFonts.nunitoTextTheme();
    return base.copyWith(
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

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.cardBorder, width: 1),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: _textTheme,
      fontFamily: GoogleFonts.nunito().fontFamily,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.brown,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        shape: const Border(bottom: BorderSide(color: AppColors.cardBorder)),
        titleTextStyle: GoogleFonts.alfaSlabOne(fontSize: 18, color: AppColors.brown),
        iconTheme: const IconThemeData(color: AppColors.brown),
        actionsIconTheme: const IconThemeData(color: AppColors.brown),
      ),

      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
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
          disabledForegroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          minimumSize: const Size(0, 46),
          textStyle: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brown,
          side: const BorderSide(color: AppColors.cardBorder),
          textStyle: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.teal,
          textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.brown,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.rust, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.stopRed, width: 1),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.stopRed, width: 1.5),
        ),
        labelStyle: GoogleFonts.nunito(color: AppColors.brown.withValues(alpha: 0.7)),
        hintStyle: GoogleFonts.nunito(color: AppColors.brown.withValues(alpha: 0.45)),
        prefixIconColor: AppColors.brown.withValues(alpha: 0.6),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cream,
        labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.brown),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentTextStyle: GoogleFonts.nunito(fontSize: 14, color: AppColors.brown),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        textStyle: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.brown),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.brown,
        contentTextStyle: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      dividerTheme: const DividerThemeData(color: AppColors.cardBorder, thickness: 1, space: 1),

      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: GoogleFonts.nunito(color: AppColors.brown),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.rust),
    );
  }
}
