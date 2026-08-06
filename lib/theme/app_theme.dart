// lib/theme/app_theme.dart
//
// StudyFlow AI — Material 3 ThemeData for light + dark.
// Wires every token from app_colors / app_text_styles / app_radius / etc.
// into the Material 3 surface so default widgets (AppBar, ListTile,
// TextField, ElevatedButton, FilledButton, NavigationBar, Card, …) all
// pick up the brand without per-widget overrides.
//
//   MaterialApp(
//     theme:      AppTheme.light,
//     darkTheme:  AppTheme.dark,
//     themeMode:  ThemeMode.system,
//   );

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';
import 'sf_colors.dart';

class AppTheme {
  const AppTheme._();

  // ────────────────────────────────────────────────────────────────────────
  // Light
  // ────────────────────────────────────────────────────────────────────────
  static final ThemeData light = _build(Brightness.light);

  // ────────────────────────────────────────────────────────────────────────
  // Dark
  // ────────────────────────────────────────────────────────────────────────
  static final ThemeData dark = _build(Brightness.dark);

  // ────────────────────────────────────────────────────────────────────────
  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // ── Color scheme ────────────────────────────────────────────────────
    final scheme = isDark
        ? const ColorScheme.dark(
            brightness: Brightness.dark,
            primary: AppColors.indigoDark,
            onPrimary: AppColors.textOnPrimary,
            primaryContainer: AppColors.indigoDeep,
            onPrimaryContainer: AppColors.lavenderSoft,
            secondary: AppColors.lavender,
            onSecondary: AppColors.indigoDeep,
            secondaryContainer: Color(0xFF2A2A6E),
            onSecondaryContainer: AppColors.lavenderSoft,
            tertiary: AppColors.successDark,
            onTertiary: Color(0xFF00271A),
            error: AppColors.errorDark,
            onError: AppColors.textOnPrimary,
            surface: AppColors.surfaceDark,
            onSurface: AppColors.textPrimaryDark,
            surfaceContainerLowest: AppColors.backgroundDark,
            surfaceContainerLow: AppColors.surfaceDark,
            surfaceContainer: AppColors.surfaceDark,
            surfaceContainerHigh: AppColors.surfaceAltDark,
            surfaceContainerHighest: AppColors.surfaceAltDark,
            onSurfaceVariant: AppColors.textSecondaryDark,
            outline: AppColors.borderDark,
            outlineVariant: AppColors.borderStrongDark,
            shadow: Color(0xFF000000),
            inverseSurface: AppColors.surface,
            onInverseSurface: AppColors.textPrimary,
          )
        : const ColorScheme.light(
            brightness: Brightness.light,
            primary: AppColors.indigo,
            onPrimary: AppColors.textOnPrimary,
            primaryContainer: AppColors.indigoSoft,
            onPrimaryContainer: AppColors.indigoDeep,
            secondary: AppColors.lavender,
            onSecondary: AppColors.indigoDeep,
            secondaryContainer: AppColors.lavenderSoft,
            onSecondaryContainer: AppColors.indigoDeep,
            tertiary: AppColors.success,
            onTertiary: AppColors.textOnPrimary,
            error: AppColors.error,
            onError: AppColors.textOnPrimary,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
            surfaceContainerLowest: AppColors.surface,
            surfaceContainerLow: AppColors.background,
            surfaceContainer: AppColors.background,
            surfaceContainerHigh: AppColors.surfaceAlt,
            surfaceContainerHighest: AppColors.surfaceAlt,
            onSurfaceVariant: AppColors.textSecondary,
            outline: AppColors.border,
            outlineVariant: AppColors.borderStrong,
            shadow: Color(0xFF0F0F1E),
            inverseSurface: AppColors.surfaceInverse,
            onInverseSurface: AppColors.surface,
          );

    final textTheme = AppTextStyles.textThemeFor(brightness);

    // The app background sits *behind* cards, so it must differ from
    // `surface`. In dark mode `surfaceContainerLow` is mapped to surfaceDark
    // (the card color), so name the background token explicitly instead.
    final canvas = isDark ? AppColors.backgroundDark : AppColors.background;

    // ── ThemeData ───────────────────────────────────────────────────────
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: scheme.surface,
      dividerColor: scheme.outline,
      splashFactory: InkSparkle.splashFactory,

      extensions: <ThemeExtension<dynamic>>[
        isDark ? SfColors.dark : SfColors.light,
      ],

      fontFamily: AppTextStyles.fontUi,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // App bar
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      // Cards
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brLg,
          side: BorderSide(color: scheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: textTheme.labelMedium,
        border: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),

      // Filled (primary) button
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: AppTextStyles.button,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        ),
      ),

      // Elevated → primary alias
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          elevation: 0,
          textStyle: AppTextStyles.button,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        ),
      ),

      // Outlined / secondary button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: AppTextStyles.button.copyWith(color: scheme.onSurface),
          side: BorderSide(color: scheme.outline),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        ),
      ),

      // Text / ghost button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: AppTextStyles.button.copyWith(color: scheme.primary),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        ),
      ),

      // Floating action button (Flow orb)
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brLg),
      ),

      // Bottom navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        height: 70,
        indicatorColor: scheme.primaryContainer,
        indicatorShape:
            const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTextStyles.caption.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),

      // Bottom sheets
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSheetTop),
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXl),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        side: BorderSide(color: scheme.outline),
        labelStyle: AppTextStyles.label.copyWith(color: scheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brPill),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: 1,
        space: 1,
      ),

      // List tiles
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurface,
        textColor: scheme.onSurface,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.surfaceContainerHigh),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Progress indicators
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.primary,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: AppRadius.brSm,
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: scheme.onInverseSurface),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}
