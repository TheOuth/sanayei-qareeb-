import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const blue = Color(0xFF2B8CF0);
  static const navy = Color(0xFF0F3A68);
  static const ink = Color(0xFF10233A);
  static const mute = Color(0xFF5B6F86);
  static const bg = Color(0xFFF3F8FF);
  static const hair = Color(0xFFDCE8F5);
  static const green = Color(0xFF1FA463);
  static const red = Color(0xFFD64545);
  static const gold = Color(0xFFE0A21B);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: C.blue, primary: C.blue, surface: Colors.white),
    scaffoldBackgroundColor: C.bg,
  );
  TextTheme tt;
  try {
    tt = GoogleFonts.readexProTextTheme(base.textTheme).apply(bodyColor: C.ink, displayColor: C.ink);
  } catch (_) {
    tt = base.textTheme.apply(bodyColor: C.ink, displayColor: C.ink);
  }
  return base.copyWith(
    textTheme: tt,
    appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: C.ink, elevation: 0, centerTitle: true, surfaceTintColor: Colors.white),
    cardTheme: CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.hair))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: C.blue, minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(foregroundColor: C.blue, minimumSize: const Size(0, 48), side: const BorderSide(color: C.hair), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.hair)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.hair)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.blue, width: 1.6)),
    ),
  );
}
