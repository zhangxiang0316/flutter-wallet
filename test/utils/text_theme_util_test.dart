import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/utils/text_theme_util.dart';

void main() {
  test('scales explicit font sizes and preserves styles without one', () {
    const theme = TextTheme(
      bodyLarge: TextStyle(fontSize: 20),
      bodyMedium: TextStyle(color: Colors.red),
    );

    final scaled = scaleTextThemeFontSizes(theme, 0.86);

    expect(scaled.bodyLarge?.fontSize, closeTo(17.2, 0.0001));
    expect(scaled.bodyMedium?.fontSize, isNull);
    expect(scaled.bodyMedium?.color, Colors.red);
  });
}
