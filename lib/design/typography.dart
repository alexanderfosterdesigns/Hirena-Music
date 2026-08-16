import 'package:flutter/material.dart';

import 'tokens.dart';

/// Typography — Inter (UI/body) + Barlow (display/hero) with heavy weight
/// contrast and tight tracking, following the streaming "poster + bold title"
/// convention.
abstract final class HType {
  static const String _display = 'Barlow';
  static const String _body = 'Inter';

  // Display
  static const TextStyle hero = TextStyle(
    fontFamily: _display,
    fontSize: 52,
    height: 1.05,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.2,
    color: HColors.inkPrimary,
  );

  static const TextStyle screenTitle = TextStyle(
    fontFamily: _display,
    fontSize: 34,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: HColors.inkPrimary,
  );

  // Section
  static const TextStyle rowTitle = TextStyle(
    fontFamily: _display,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: HColors.inkPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: _body,
    fontSize: 14,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: HColors.inkPrimary,
  );

  // Body & metadata
  static const TextStyle body = TextStyle(
    fontFamily: _body,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: HColors.inkPrimary,
  );

  static const TextStyle metadata = TextStyle(
    fontFamily: _body,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: HColors.inkSecondary,
  );

  // Eyebrow / caption (uppercase, tracked)
  static const TextStyle eyebrow = TextStyle(
    fontFamily: _body,
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    color: HColors.brandRed,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _body,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: HColors.inkSecondary,
  );
}
