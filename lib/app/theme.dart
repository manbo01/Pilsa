import 'package:flutter/material.dart';

/// 필사 감성의 잉크/한지 톤 시드 컬러.
const _seed = Color(0xFF4E5D4A);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'NotoSansKR',
    scaffoldBackgroundColor:
        brightness == Brightness.light ? const Color(0xFFFAF8F3) : null,
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
