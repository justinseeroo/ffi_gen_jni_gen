import 'package:flutter/material.dart';

/// Light and dark Material 3 themes generated from a single seed color.
abstract final class AppTheme {
  static const _seedColor = Colors.teal;

  static final ThemeData light = ThemeData(
    colorSchemeSeed: _seedColor,
    brightness: Brightness.light,
  );

  static final ThemeData dark = ThemeData(
    colorSchemeSeed: _seedColor,
    brightness: Brightness.dark,
  );
}
