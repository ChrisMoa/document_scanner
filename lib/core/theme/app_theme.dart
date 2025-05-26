import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color errorColor = Color(0xFFB00020);
  static const Color surfaceColor = Color(0xFFFAFAFA);
  static const Color backgroundColor = Color(0xFFFFFFFF);

  static const Color darkPrimaryColor = Color(0xFF1976D2);
  static const Color darkSecondaryColor = Color(0xFF018786);
  static const Color darkSurfaceColor = Color(0xFF121212);
  static const Color darkBackgroundColor = Color(0xFF000000);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(primary: primaryColor, secondary: secondaryColor, error: errorColor, surface: surfaceColor, background: backgroundColor),
      appBarTheme: const AppBarTheme(backgroundColor: primaryColor, foregroundColor: Colors.white, elevation: 2, centerTitle: true),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      cardTheme: CardTheme(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)).data,
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: surfaceColor),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(primary: darkPrimaryColor, secondary: darkSecondaryColor, surface: darkSurfaceColor),
      appBarTheme: const AppBarTheme(backgroundColor: darkPrimaryColor, foregroundColor: Colors.white, elevation: 2, centerTitle: true),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      cardTheme:
          CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: darkSurfaceColor,
          ).data,
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: darkSurfaceColor),
    );
  }
}
