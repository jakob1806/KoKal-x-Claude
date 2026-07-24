import 'package:flutter/material.dart';

/// Design tokens aus docs/04-design-system.md.
/// Zwei komplette Paletten (Light/Dark) statt automatischer Invertierung,
/// damit Kontrast und Stimmung in beiden Modi bewusst gestaltet sind.
class AppColors {
  const AppColors._();

  static const light = AppColorPalette(
    backgroundPrimary: Color(0xFFFAFAF8),
    backgroundSecondary: Color(0xFFFFFFFF),
    backgroundElevated: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF6E6E73),
    // War #A1A1A6 (2.46-2.57:1 gegen die Hintergründe) — Barrierefreiheits-
    // Audit fand das als real genutzte Fließtextfarbe (Datum/Adresse/Meta-
    // Text an ~15 Stellen), nicht nur als dekorative Tönung, und damit WCAG
    // AA-pflichtig (4.5:1). Bei so hellen Hintergründen bleibt praktisch kein
    // Spielraum für einen dritten, sichtbar helleren Grauton, der noch
    // besteht — die Hierarchie zu textSecondary kommt jetzt primär über
    // Schriftgröße/-gewicht, nicht mehr über Kontrast.
    textTertiary: Color(0xFF727277),
    accentPrimary: Color(0xFF8B2635),
    accentSecondary: Color(0xFFC9A961),
    separator: Color(0xFFE5E5EA),
    success: Color(0xFF2E7D46),
    warning: Color(0xFFA9700A),
    error: Color(0xFFB23A3A),
    glass: Color(0xB8FAFAF8),
  );

  static const dark = AppColorPalette(
    backgroundPrimary: Color(0xFF0C0C0E),
    backgroundSecondary: Color(0xFF1A1A1D),
    backgroundElevated: Color(0xFF232326),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFF98989D),
    // War #636366 (3.26:1 gegen den Hintergrund, reicht nur für UI-Komponenten
    // (3:1), nicht für den echten Fließtext, als der es verwendet wird) —
    // siehe Kommentar bei AppColors.light.textTertiary.
    textTertiary: Color(0xFF7D7D82),
    accentPrimary: Color(0xFFC4566B),
    accentSecondary: Color(0xFFD9BC7F),
    separator: Color(0xFF38383A),
    success: Color(0xFF4FBE71),
    warning: Color(0xFFE8A33D),
    error: Color(0xFFE3685F),
    glass: Color(0xB80C0C0E),
  );
}

class AppColorPalette {
  const AppColorPalette({
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    required this.backgroundElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.separator,
    required this.success,
    required this.warning,
    required this.error,
    required this.glass,
  });

  final Color backgroundPrimary;
  final Color backgroundSecondary;
  final Color backgroundElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accentPrimary;
  final Color accentSecondary;
  final Color separator;
  final Color success;
  final Color warning;
  final Color error;
  final Color glass;
}

/// ThemeExtension, damit die vollen Design-Tokens (nicht nur die von
/// Material's ColorScheme abgedeckten Rollen) per `Theme.of(context)` erreichbar sind.
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension(this.palette);

  final AppColorPalette palette;

  @override
  AppColorsExtension copyWith() => this;

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return t < 0.5 ? this : other;
  }

  Color get backgroundPrimary => palette.backgroundPrimary;
  Color get backgroundSecondary => palette.backgroundSecondary;
  Color get backgroundElevated => palette.backgroundElevated;
  Color get textPrimary => palette.textPrimary;
  Color get textSecondary => palette.textSecondary;
  Color get textTertiary => palette.textTertiary;
  Color get accentPrimary => palette.accentPrimary;
  Color get accentSecondary => palette.accentSecondary;
  Color get separator => palette.separator;
  Color get success => palette.success;
  Color get warning => palette.warning;
  Color get error => palette.error;
  Color get glass => palette.glass;
}

extension AppThemeContext on BuildContext {
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}
