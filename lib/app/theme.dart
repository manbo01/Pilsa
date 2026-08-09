import 'package:flutter/material.dart';

/// 필사 감성의 잉크/한지 톤 시드 컬러.
const _seed = Color(0xFF4E5D4A);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  // paper-like background colors and matching text colors
  final bool light = brightness == Brightness.light;
  final Color scaffoldBg = light ? const Color(0xFFF6EFE1) : const Color(0xFF2F1B0F);
  final Color bodyColor = light ? const Color(0xFF0B0B0B) : const Color(0xFFEDE0C8);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'MapoFlowerIsland',
    scaffoldBackgroundColor: scaffoldBg,
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
          bodyColor: bodyColor,
          displayColor: bodyColor,
          fontFamily: 'MapoFlowerIsland',
        ),
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
  );
}
