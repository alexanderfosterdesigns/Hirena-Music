import 'package:flutter/material.dart';

/// Design tokens — the Netflix *language* (cinematic black canvas, one red
/// accent, poster-first). Uses original hex values as inspiration; no
/// Netflix trademarks, wordmarks, or the proprietary "Netflix Sans" are used.
abstract final class HColors {
  // Canvas & surfaces
  static const canvas = Color(0xFF000000);
  static const surface = Color(0xFF141414);
  static const surfaceRaised = Color(0xFF161616);
  static const surfaceHover = Color(0xFF232323);
  static const surfacePressed = Color(0xFF2D2D2D);

  // Ink
  static const inkPrimary = Color(0xFFFFFFFF);
  static const inkSecondary = Color(0xB3FFFFFF); // 70%
  static const inkDisabled = Color(0x66FFFFFF); // 40%
  static const hairline = Color(0x29FFFFFF); // 16%

  // Brand (single red accent)
  static const brandRed = Color(0xFFE50914);
  static const brandRedDark = Color(0xFFB20710);

  // Rare functional colors
  static const success = Color(0xFF2AB759);

  /// Vertical scrim gradient for the hero billboard (left-heavy).
  static const heroScrim = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xE6000000), Color(0x66000000), Color(0x00000000)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Bottom fade used on the hero and now-playing bar.
  static const bottomScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0xCC000000)],
  );
}

/// 9-step spacing scale (logical px).
abstract final class HSpacing {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;
  static const double s8 = 64;
  static const double s9 = 96;
}

abstract final class HRadii {
  static const double card = 8;
  static const double chip = 4;
  static const double pill = 999;
}

/// Motion tokens.
abstract final class HMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Curve ease = Curves.easeOutCubic;
  static const double cardHoverScale = 1.06;
}

/// Poster aspect ratios.
abstract final class HAspect {
  static const double poster = 2 / 3;
  static const double landscape = 16 / 9;
}
