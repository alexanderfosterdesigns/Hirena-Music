import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Builds the app-wide dark theme from tokens only — no hardcoded colors in
/// widgets.
abstract final class HTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: HColors.brandRed,
      onPrimary: HColors.inkPrimary,
      secondary: HColors.brandRedDark,
      onSecondary: HColors.inkPrimary,
      error: HColors.brandRed,
      onError: HColors.inkPrimary,
      surface: HColors.surfaceRaised,
      onSurface: HColors.inkPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: HColors.canvas,
      canvasColor: HColors.canvas,
      fontFamily: 'Inter',
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: HColors.inkPrimary,
        displayColor: HColors.inkPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: HColors.inkPrimary,
        titleTextStyle: HType.screenTitle,
      ),
      dividerTheme: const DividerThemeData(
        color: HColors.hairline,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: HColors.inkSecondary,
        textColor: HColors.inkPrimary,
      ),
      iconTheme: const IconThemeData(color: HColors.inkPrimary),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HColors.inkPrimary,
          foregroundColor: HColors.canvas,
          textStyle: HType.body.copyWith(fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HRadii.chip),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HColors.surfaceRaised,
        hintStyle: HType.metadata,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HRadii.chip),
          borderSide: BorderSide.none,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: HColors.brandRed,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: HColors.brandRed,
        thumbColor: HColors.brandRed,
        inactiveTrackColor: HColors.surfaceHover,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: HColors.surfaceHover,
          borderRadius: BorderRadius.all(Radius.circular(HRadii.chip)),
        ),
        textStyle: HType.caption,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: HColors.surfaceHover,
        contentTextStyle: HType.body,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HRadii.card)),
      ),
    );
  }
}
