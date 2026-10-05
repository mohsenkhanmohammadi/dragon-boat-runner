import 'package:flutter/material.dart';

const dragonRed = Color(0xFFB91C1C);
const dragonGold = Color(0xFFF2B33D);
const deepWater = Color(0xFF0F2A3D);

/// Colour used everywhere something was set/changed by the team admin.
const adminBlue = Color(0xFF1E6FD9);

const yesGreen = Color(0xFF2E7D32);
const noRed = Color(0xFFC62828);
const maybeAmber = Color(0xFFF59E0B);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: dragonRed,
    primary: dragonRed,
    secondary: dragonGold,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFFAF7F2),
    appBarTheme: const AppBarTheme(centerTitle: false),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
  );
}
