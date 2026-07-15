import 'package:flutter/material.dart';

/// Typografische Skala aus docs/04-design-system.md.
///
/// Nutzt vorerst die Plattform-Systemschrift (SF Pro/Roboto) statt einer
/// gebündelten Inter-Schriftdatei. TODO: `Inter` als Asset unter
/// `assets/fonts/` einbinden und hier via `fontFamily: 'Inter'` referenzieren,
/// sobald die Lizenzdateien im Repo liegen (siehe docs/04-design-system.md, §2).
class AppTypography {
  const AppTypography._();

  static const display = TextStyle(
    fontSize: 34,
    height: 40 / 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );
  static const title1 = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );
  static const title2 = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );
  static const title3 = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w400,
  );
  static const callout = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w400,
  );
  static const footnote = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
  );
  static const caption = TextStyle(
    fontSize: 11,
    height: 13 / 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
    displayMedium: display.copyWith(color: primary),
    headlineLarge: title1.copyWith(color: primary),
    headlineMedium: title2.copyWith(color: primary),
    headlineSmall: title3.copyWith(color: primary),
    bodyLarge: body.copyWith(color: primary),
    bodyMedium: callout.copyWith(color: secondary),
    bodySmall: footnote.copyWith(color: secondary),
    labelSmall: caption.copyWith(color: secondary),
  );
}
