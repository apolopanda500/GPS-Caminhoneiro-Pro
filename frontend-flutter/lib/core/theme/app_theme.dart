import 'package:flutter/material.dart';

const Color kDarkBlack = Color(0xFF0A0A0A);
const Color kDarkRedTransition = Color(0xFF1C0303);
const Color kEmergencyRed = Color(0xFF8B0000);
const Color kLightText = Color(0xFFE5E5E5);
const Color kLightBackground = Color(0xFFF5F2EE);
const Color kLightSurface = Color(0xFFFFFFFF);
const Color kLightInk = Color(0xFF1A1A1A);

const Color kAppBarDark = Color(0xFF1C0303);
const Color kAppBarLight = Color(0xFFFFFFFF);
const Color kDividerDark = Color(0x33FFFFFF);
const Color kDividerLight = Color(0x1F000000);

/// Superfícies flutuantes sobre o mapa (barra lateral, cartões, HUD).
/// No tema claro ficam brancas e translúcidas para o mapa aparecer atrás.
Color overlaySurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xE6101418)
        : const Color(0xF2FFFFFF);

Color overlayBorder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? kEmergencyRed
        : const Color(0x33000000);

Color overlayAccent(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? kEmergencyRed
        : const Color(0xFFD32F2F);

Color overlayText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? Colors.white : kLightInk;

Color overlayTextMuted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? Colors.white70 : kLightInk;

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kDarkBlack,
  canvasColor: kDarkBlack,
  primaryColor: kEmergencyRed,
  colorScheme: const ColorScheme.dark(
    primary: kEmergencyRed,
    secondary: kEmergencyRed,
    surface: kDarkRedTransition,
    onPrimary: Colors.white,
    onSurface: kLightText,
    outline: kDividerDark,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: kAppBarDark,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  cardTheme: const CardThemeData(
    color: kDarkRedTransition,
    elevation: 0,
    margin: EdgeInsets.zero,
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: kDarkRedTransition,
    titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    contentTextStyle: TextStyle(color: kLightText),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: kDarkRedTransition,
    modalBackgroundColor: kDarkRedTransition,
  ),
  listTileTheme: const ListTileThemeData(
    iconColor: kLightText,
    textColor: kLightText,
  ),
  dividerTheme: const DividerThemeData(color: kDividerDark, space: 1, thickness: 1),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? Colors.white : Colors.white70,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? kEmergencyRed : Colors.white24,
    ),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: kLightText, fontSize: 16),
    bodyMedium: TextStyle(color: kLightText, fontSize: 14),
    titleLarge: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kEmergencyRed,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kEmergencyRed,
      side: const BorderSide(color: kEmergencyRed, width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: kEmergencyRed),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: kDarkRedTransition,
    contentTextStyle: TextStyle(color: Colors.white),
    behavior: SnackBarBehavior.floating,
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
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: kLightBackground,
  canvasColor: kLightBackground,
  primaryColor: kEmergencyRed,
  colorScheme: const ColorScheme.light(
    primary: kEmergencyRed,
    secondary: kEmergencyRed,
    surface: kLightSurface,
    onPrimary: Colors.white,
    onSurface: kLightInk,
    outline: kDividerLight,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: kAppBarLight,
    foregroundColor: kLightInk,
    elevation: 0,
    centerTitle: true,
  ),
  cardTheme: const CardThemeData(
    color: kLightSurface,
    elevation: 0,
    margin: EdgeInsets.zero,
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: kLightSurface,
    titleTextStyle: TextStyle(
      color: kLightInk,
      fontWeight: FontWeight.bold,
      fontSize: 18,
    ),
    contentTextStyle: TextStyle(color: Color(0xFF3A3A3A)),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: kLightSurface,
    modalBackgroundColor: kLightSurface,
  ),
  listTileTheme: const ListTileThemeData(
    iconColor: kLightInk,
    textColor: kLightInk,
  ),
  dividerTheme: const DividerThemeData(color: kDividerLight, space: 1, thickness: 1),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? Colors.white : Colors.white70,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? kEmergencyRed : Colors.black26,
    ),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: kLightInk, fontSize: 16),
    bodyMedium: TextStyle(color: Color(0xFF3A3A3A), fontSize: 14),
    titleLarge: TextStyle(color: kLightInk, fontSize: 20, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(color: kLightInk, fontSize: 16, fontWeight: FontWeight.w600),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kEmergencyRed,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kEmergencyRed,
      side: const BorderSide(color: kEmergencyRed, width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: kEmergencyRed),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: kLightInk,
    contentTextStyle: TextStyle(color: Colors.white),
    behavior: SnackBarBehavior.floating,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: kLightSurface,
    hintStyle: TextStyle(color: Colors.black45),
    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kEmergencyRed)),
  ),
);
