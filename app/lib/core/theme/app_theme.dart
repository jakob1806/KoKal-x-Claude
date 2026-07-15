import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light = _build(AppColors.light, Brightness.light);
  static ThemeData dark = _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColorPalette palette, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.accentPrimary,
      onPrimary: brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF1C1C1E),
      secondary: palette.accentSecondary,
      onSecondary: const Color(0xFF1C1C1E),
      surface: palette.backgroundSecondary,
      onSurface: palette.textPrimary,
      error: palette.error,
      onError: Colors.white,
      outline: palette.separator,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.backgroundPrimary,
      canvasColor: palette.backgroundPrimary,
      dividerColor: palette.separator,
      textTheme: AppTypography.textTheme(
        palette.textPrimary,
        palette.textSecondary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.backgroundPrimary,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.title2.copyWith(
          color: palette.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.backgroundSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.backgroundSecondary,
        selectedColor: palette.accentPrimary,
        labelStyle: AppTypography.footnote.copyWith(
          color: palette.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: palette.separator),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accentPrimary,
          foregroundColor: brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF1C1C1E),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: AppTypography.callout.copyWith(
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.backgroundElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.bottomSheet),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.glass,
        indicatorColor: palette.accentPrimary.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return AppTypography.caption.copyWith(
            color: active ? palette.accentPrimary : palette.textTertiary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: [AppColorsExtension(palette)],
    );
  }
}
