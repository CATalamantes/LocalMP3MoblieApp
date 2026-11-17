import 'package:flutter/material.dart';

abstract final class AppTheme {
  // Midnight Crimson / red-navy wireframe colors, explicitly assigned so
  // Material's generated palettes cannot introduce green accents.
  static const background = Color(0xFF101722);
  static const surface = Color(0xFF16202E);
  static const blue = Color(0xFF1D3956);
  static const crimson = Color(0xFFE11927);
  static const text = Color(0xFFF5F6FA);
  static const muted = Color(0xFFBAC1CC);
  static const outline = Color(0xFF2B4058);

  static ThemeData get midnightCrimson => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: crimson,
      onPrimary: Colors.white,
      secondary: blue,
      onSecondary: text,
      tertiary: crimson,
      onTertiary: Colors.white,
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      outline: outline,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: background,
      indicatorColor: blue,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? crimson : muted,
        ),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: blue,
      selectedColor: crimson,
      side: BorderSide(color: outline),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: blue,
      border: OutlineInputBorder(),
    ),
    dividerColor: outline,
  );
}
