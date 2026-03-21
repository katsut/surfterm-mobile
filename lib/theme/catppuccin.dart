import 'package:flutter/material.dart';

/// Catppuccin Mocha color palette.
///
/// See https://github.com/catppuccin/catppuccin for the full spec.
abstract final class CatppuccinMocha {
  // Base colors
  static const Color base = Color(0xFF1E1E2E);
  static const Color mantle = Color(0xFF181825);
  static const Color crust = Color(0xFF11111B);

  // Surface colors
  static const Color surface0 = Color(0xFF313244);
  static const Color surface1 = Color(0xFF45475A);
  static const Color surface2 = Color(0xFF585B70);

  // Overlay colors
  static const Color overlay0 = Color(0xFF6C7086);
  static const Color overlay1 = Color(0xFF7F849C);
  static const Color overlay2 = Color(0xFF9399B2);

  // Text colors
  static const Color text = Color(0xFFCDD6F4);
  static const Color subtext0 = Color(0xFFA6ADC8);
  static const Color subtext1 = Color(0xFFBAC2DE);

  // Accent colors
  static const Color green = Color(0xFFA6E3A1);
  static const Color yellow = Color(0xFFF9E2AF);
  static const Color red = Color(0xFFF38BA8);
  static const Color blue = Color(0xFF89B4FA);
  static const Color mauve = Color(0xFFCBA6F7);
  static const Color peach = Color(0xFFFAB387);
  static const Color teal = Color(0xFF94E2D5);
  static const Color lavender = Color(0xFFB4BEFE);

  /// Build a full [ThemeData] based on Catppuccin Mocha.
  static ThemeData themeData() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: base,
      colorScheme: const ColorScheme.dark(
        primary: mauve,
        secondary: blue,
        surface: surface0,
        error: red,
        onPrimary: crust,
        onSecondary: crust,
        onSurface: text,
        onError: crust,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: mantle,
        foregroundColor: text,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: surface0,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: mauve,
        foregroundColor: crust,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface0,
        hintStyle: const TextStyle(color: overlay1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: mauve),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: text),
        bodyMedium: TextStyle(color: text),
        bodySmall: TextStyle(color: subtext0),
        titleLarge: TextStyle(color: text, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: text, fontWeight: FontWeight.w600),
        labelLarge: TextStyle(color: text),
      ),
      dividerColor: surface1,
      iconTheme: const IconThemeData(color: subtext0),
    );
  }
}
