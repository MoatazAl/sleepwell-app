import 'package:flutter/material.dart';

const kBrand = Color(0xFF8B5CF6);
const kBrandDark = Color(0xFF6D28D9);
const kAccent = Color(0xFFC4B5FD);

const kAccentBlue = Color(0xFF67E8F9);
const kAccentBlueSoft = Color(0x3322D3EE);

const kBackgroundTop = Color(0xFF14021F);
const kBackgroundBottom = Color(0xFF07010D);

const kSurface = Color(0xFF16051F);
const kSurfaceSoft = Color(0xFF21102C);
const kSurfaceCard = Color(0xFF261235);

const kTextPrimary = Colors.white;
const kTextSecondary = Color(0xFFE7DDF7);
const kTextMuted = Color(0xFFBCAED9);
const kBorder = Color(0x33FFFFFF);

ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBackgroundBottom,
  colorScheme: const ColorScheme.dark(
    primary: kBrand,
    secondary: kAccentBlue,
    surface: kSurface,
    onPrimary: Colors.white,
    onSecondary: Colors.black,
    onSurface: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    surfaceTintColor: Colors.transparent,
  ),
  cardTheme: CardThemeData(
    color: kSurfaceCard,
    elevation: 0,
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: kBorder),
    ),
  ),
  dividerColor: Colors.white12,
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      color: kTextPrimary,
      fontWeight: FontWeight.w800,
      fontSize: 32,
      height: 1.1,
    ),
    headlineMedium: TextStyle(
      color: kTextPrimary,
      fontWeight: FontWeight.w700,
      fontSize: 26,
      height: 1.15,
    ),
    titleLarge: TextStyle(
      color: kTextPrimary,
      fontWeight: FontWeight.w700,
      fontSize: 20,
    ),
    titleMedium: TextStyle(
      color: kTextPrimary,
      fontWeight: FontWeight.w600,
      fontSize: 16,
    ),
    bodyLarge: TextStyle(color: kTextPrimary, fontSize: 16, height: 1.45),
    bodyMedium: TextStyle(color: kTextSecondary, fontSize: 14, height: 1.45),
    bodySmall: TextStyle(color: kTextMuted, fontSize: 12, height: 1.4),
  ),
  iconTheme: const IconThemeData(color: Colors.white),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kBrand,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: kBorder),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: kSurfaceSoft,
    hintStyle: const TextStyle(color: kTextMuted),
    labelStyle: const TextStyle(color: kTextSecondary),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.transparent),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.transparent),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: kBrand, width: 1.2),
    ),
  ),
);

final BoxDecoration appBackgroundDecoration = const BoxDecoration(
  gradient: LinearGradient(
    colors: [kBackgroundTop, kBackgroundBottom],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ),
);

final BoxDecoration glassCardDecoration = BoxDecoration(
  borderRadius: BorderRadius.circular(24),
  color: Colors.white.withValues(alpha: 0.06),
  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.28),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ],
);
