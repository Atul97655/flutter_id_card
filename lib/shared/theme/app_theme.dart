import 'package:flutter/material.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';

/// Application chrome.
///
/// Deliberately separate from card colours: the ID card's red/blue are printed
/// artwork configured per school, whereas this is the operator-facing UI. The
/// two must never share constants or a school colour override would repaint the
/// whole app.
final class AppTheme {
  const AppTheme._();

  static const Color seed = AppColors.navy;

  /// Kept under the old name because several screens still read it. It is now
  /// the redesign's canvas colour; screens paint a gradient over it.
  static const Color surfaceTint = AppColors.canvas;

  static const double cornerRadius = AppRadius.field;
  static const double gutter = AppSpacing.gutter;

  /// Minimum touch target. Operators use this app for hours at a time on cheap
  /// Android tablets, often standing up - small targets cost real throughput.
  static const double minTapTarget = AppSpacing.minTap;

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(seedColor: seed);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surfaceTint,
      visualDensity: VisualDensity.standard,
      // Transparent by default. Redesigned screens paint their own header
      // over a page gradient, and an opaque bar would draw a hard edge
      // across the middle of it. A screen that still wants a solid bar sets
      // its own background, as the chat and admin headers do.
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.title,
      ),
      // Translucent, hairlined and lifted, so that any screen still built
      // from plain Material Cards reads as glass on the page gradient without
      // being rewritten. This is what carries the redesign through the
      // thousands of lines of admin screens that were never touched by hand.
      cardTheme: CardThemeData(
        elevation: 3,
        color: AppColors.glassFillStrong,
        shadowColor: AppColors.navy.withValues(alpha: 0.10),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardR,
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.royal,
        titleTextStyle: AppTypography.section,
        subtitleTextStyle: AppTypography.support,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.fieldR),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.mist,
        side: BorderSide(color: AppColors.glassBorder),
        labelStyle: AppTypography.badge,
        shape: StadiumBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: AppColors.navy.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.panelR),
        titleTextStyle: AppTypography.title,
        contentTextStyle: AppTypography.body,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.fieldR),
        textStyle: AppTypography.body,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.royal,
        unselectedLabelColor: AppColors.inkMuted,
        labelStyle: AppTypography.badge,
        unselectedLabelStyle: AppTypography.badge,
        indicatorColor: AppColors.royal,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.royal,
        foregroundColor: AppColors.onDark,
        elevation: 4,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.royal,
        linearTrackColor: AppColors.mist,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            AppTypography.badge,
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: AppRadius.fieldR),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.fieldR,
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.fieldR,
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.fieldR,
          borderSide: const BorderSide(color: AppColors.royal, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.fieldR,
          borderSide: const BorderSide(color: AppColors.rejected),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.fieldR,
          borderSide: const BorderSide(color: AppColors.rejected, width: 1.8),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: AppTypography.label,
        hintStyle: AppTypography.placeholder,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.royal,
          foregroundColor: AppColors.onDark,
          minimumSize: const Size.fromHeight(minTapTarget),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.fieldR),
          textStyle: AppTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.royal,
          minimumSize: const Size(64, minTapTarget),
          side: const BorderSide(color: AppColors.royal, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.fieldR),
          textStyle: AppTypography.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.royal),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.fieldR),
      ),
      dividerTheme: const DividerThemeData(
        space: 1,
        thickness: 1,
        color: AppColors.hairline,
      ),
      textTheme: const TextTheme(
        headlineSmall: AppTypography.display,
        titleLarge: AppTypography.title,
        titleMedium: AppTypography.section,
        bodyMedium: AppTypography.body,
        bodySmall: AppTypography.support,
        labelLarge: AppTypography.label,
      ),
    );
  }
}

/// Status colours for the sync indicator. Chosen to stay distinguishable for
/// red-green colour blindness by pairing each with a distinct icon at the call
/// site rather than relying on hue alone.
final class StatusColors {
  const StatusColors._();

  static const Color pending = Color(0xFFF57C00);
  static const Color syncing = Color(0xFF0288D1);
  static const Color synced = Color(0xFF2E7D32);
  static const Color failed = Color(0xFFC62828);

  /// A card that has been through a print run. Indigo rather than another
  /// green so "approved" and "printed" stay tellable apart at a glance - they
  /// are adjacent states an operator asks the office about by name.
  static const Color printed = Color(0xFF4527A0);
}
