import 'package:flutter/material.dart';

const stockBlue = Color(0xFF2563EB);
const stockNavy = Color(0xFF0F172A);
const stockSuccess = Color(0xFF16A34A);
const stockWarning = Color(0xFFF59E0B);
const stockError = Color(0xFFDC2626);

ThemeData stockTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final colors = ColorScheme.fromSeed(
    seedColor: stockBlue,
    brightness: brightness,
  );
  final scheme = light
      ? colors.copyWith(
          primary: stockBlue,
          secondary: stockNavy,
          surface: Colors.white,
          error: stockError,
        )
      : colors;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: light ? const Color(0xFFF8FAFC) : scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: light ? const Color(0xFFF8FAFC) : scheme.surface,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      color: light ? Colors.white : scheme.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: border,
      enabledBorder: border,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
