import 'package:flutter/material.dart';

const kBrand = Color(0xff7C4DFF);
const kSurface = Color(0xffF9F6FF);

ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: kBrand),
  scaffoldBackgroundColor: kSurface,
  cardTheme: const CardThemeData(
    elevation: 3,
    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 0,
  ),
);
