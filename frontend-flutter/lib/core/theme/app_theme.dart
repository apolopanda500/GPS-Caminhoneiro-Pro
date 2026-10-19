import 'package:flutter/material.dart';

const Color kDarkBlack = Color(0xFF0A0A0A);
const Color kDarkRedTransition = Color(0xFF1C0303);
const Color kEmergencyRed = Color(0xFF8B0000);
const Color kLightText = Color(0xFFE5E5E5);
const Color kLightBackground = Color(0xFFF5F2EE);
const Color kLightSurface = Color(0xFFFFFFFF);
const Color kLightInk = Color(0xFF1A1A1A);

final ThemeData appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kDarkBlack,
  primaryColor: kEmergencyRed,
  colorScheme: const ColorScheme.dark(
    primary: kEmergencyRed,
    surface: kDarkRedTransition,
    onPrimary: Colors.white,
    onSurface: kLightText,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: kLightText, fontSize: 16),
    bodyMedium: TextStyle(color: kLightText, fontSize: 14),
    titleLarge: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kEmergencyRed,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
    ),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: kDarkRedTransition,
    hintStyle: TextStyle(color: Colors.grey),
    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kEmergencyRed)),
  ),
);

final ThemeData appLightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: kLightBackground,
  primaryColor: kEmergencyRed,
  colorScheme: const ColorScheme.light(
    primary: kEmergencyRed,
    surface: kLightSurface,
    onPrimary: Colors.white,
    onSurface: kLightInk,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: kLightInk, fontSize: 16),
    bodyMedium: TextStyle(color: Color(0xFF3A3A3A), fontSize: 14),
    titleLarge: TextStyle(color: kLightInk, fontSize: 20, fontWeight: FontWeight.bold),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kEmergencyRed,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
    ),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: kLightSurface,
    hintStyle: TextStyle(color: Colors.black45),
    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kEmergencyRed)),
  ),
);
