import 'package:flutter/material.dart';

class AppColors {
  static const boardLight = Color(0xFFE8D9BF);
  static const boardDark = Color(0xFFB08B5A);
  static const castleTint = Color(0x55B71C1C);
  static const whitePiece = Color(0xFFFAFAFA);
  static const blackPiece = Color(0xFF212121);
  static const highlight = Color(0x8843A047);
  static const capture = Color(0x99D32F2F);
  static const selected = Color(0xAAFFC107);
  static const lastMove = Color(0x553F51B5);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF8E0E0E),
    brightness: Brightness.dark,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF14110F),
    appBarTheme: const AppBarTheme(centerTitle: true),
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
  );
}
