import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light {
    const teal = Color(0xFF00897B);
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      primary: teal,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7FAF9),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF10201D),
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Color(0xFF10201D),
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE4ECEA)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEAF5F3),
        selectedColor: teal,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: teal,
        unselectedItemColor: Color(0xFF71817D),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
