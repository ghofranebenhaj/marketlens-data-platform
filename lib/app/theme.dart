import 'package:flutter/material.dart';

const background = Color(0xFF080A09),
    surface = Color(0xFF141715),
    secondary = Color(0xFF1D231E);
const lime = Color(0xFF7FE34F),
    deepGreen = Color(0xFF19351B),
    ink = Color(0xFFF4F7F2),
    muted = Color(0xFF98A196),
    negative = Color(0xFFEF5A67);
ThemeData appTheme({bool light = false}) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: lime,
        brightness: light ? Brightness.light : Brightness.dark,
      ).copyWith(
        primary: light ? const Color(0xFF336E18) : lime,
        surface: light ? const Color(0xFFF2F5EF) : surface,
        onSurface: light ? background : ink,
        onSurfaceVariant: light ? const Color(0xFF52604E) : muted,
        surfaceContainerHighest: light ? const Color(0xFFE0E8DC) : secondary,
        error: negative,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: light ? const Color(0xFFE8EEE5) : background,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: light ? const Color(0xFFE8EEE5) : background,
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: light ? Colors.white : secondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.all(18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: light ? Colors.white : surface,
      indicatorColor: deepGreen,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? lime
              : (light ? const Color(0xFF52604E) : muted),
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          color: states.contains(WidgetState.selected)
              ? (light ? const Color(0xFF336E18) : lime)
              : (light ? const Color(0xFF52604E) : muted),
        ),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
      ),
      headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5),
    ),
  );
}
