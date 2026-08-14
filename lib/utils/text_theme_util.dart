import 'package:flutter/material.dart';

/// Scales only text styles that define an explicit font size.
///
/// Flutter's Material text theme can contain styles whose [TextStyle.fontSize]
/// is null. Calling `TextTheme.apply(fontSizeFactor: ...)` on such a theme
/// triggers an assertion in recent Flutter versions.
TextTheme scaleTextThemeFontSizes(TextTheme theme, double factor) {
  TextStyle? scale(TextStyle? style) {
    if (style == null || style.fontSize == null) {
      return style;
    }
    return style.apply(fontSizeFactor: factor);
  }

  return theme.copyWith(
    displayLarge: scale(theme.displayLarge),
    displayMedium: scale(theme.displayMedium),
    displaySmall: scale(theme.displaySmall),
    headlineLarge: scale(theme.headlineLarge),
    headlineMedium: scale(theme.headlineMedium),
    headlineSmall: scale(theme.headlineSmall),
    titleLarge: scale(theme.titleLarge),
    titleMedium: scale(theme.titleMedium),
    titleSmall: scale(theme.titleSmall),
    bodyLarge: scale(theme.bodyLarge),
    bodyMedium: scale(theme.bodyMedium),
    bodySmall: scale(theme.bodySmall),
    labelLarge: scale(theme.labelLarge),
    labelMedium: scale(theme.labelMedium),
    labelSmall: scale(theme.labelSmall),
  );
}
