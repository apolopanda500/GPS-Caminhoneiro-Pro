import 'package:flutter/material.dart';

// ---------------------------------------------------------------- Paleta
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

// --------------------------------------------------- Superficies no mapa
Color overlaySurface(
  BuildContext context, {
  double opacity = 1.0,
  Color? accent,
}) {
  final base = Theme.of(context).brightness == Brightness.dark
      ? const Color(0xE6101418)
      : const Color(0xF2FFFFFF);
  return base
      .withValues(alpha: (base.a * opacity.clamp(0.3, 1.0)).clamp(0.05, 1.0));
}

Color overlayBorder(BuildContext context, {Color? accent}) =>
    accent ??
    (Theme.of(context).brightness == Brightness.dark
        ? kEmergencyRed
        : const Color(0x33000000));

Color overlayAccent(BuildContext context, {Color? accent}) =>
    accent ?? kEmergencyRed;

Color overlayText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? Colors.white : kLightInk;

Color overlayTextMuted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? Colors.white70 : kLightInk;

Color overlayTextSoft(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : kLightInk.withValues(alpha: 0.7);

// ---------------------------------------------------------------- ESCURO
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kDarkBlack,
  canvasColor: kDarkBlack,
  primaryColor: kEmergencyRed,
  colorScheme: const ColorScheme.dark(
    primary: kEmergencyRed,
    onPrimary: Colors.white,
    secondary: kEmergencyRed,
    onSecondary: Colors.white,
    surface: kDarkRedTransition,
    onSurface: kLightText,
    error: Color(0xFFFF6B6B),
    onError: Colors.black,
    outline: kDividerDark,
    outlineVariant: kDividerDark,
  ),
  splashFactory: InkSplash.splashFactory,
  appBarTheme: const AppBarTheme(
    backgroundColor: kAppBarDark,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    iconTheme: IconThemeData(color: Colors.white),
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
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: kEmergencyRed,
    foregroundColor: Colors.white,
    elevation: 2,
  ),
  chipTheme: const ChipThemeData(
    backgroundColor: kDarkRedTransition,
    labelStyle: TextStyle(color: kLightText),
    side: BorderSide(color: kDividerDark),
  ),
  segmentedButtonTheme: const SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(kDarkRedTransition),
      foregroundColor: WidgetStatePropertyAll(kLightText),
      side: WidgetStatePropertyAll(BorderSide(color: kDividerDark)),
    ),
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
    bodySmall: TextStyle(color: Colors.white70, fontSize: 12),
    titleLarge: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
    labelLarge: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kEmergencyRed,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: kEmergencyRed,
      foregroundColor: Colors.white,
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
    labelStyle: TextStyle(color: kLightText),
    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD32F2F))),
  ),
);

// ------------------------------------------------------------------ CLARO
final ThemeData appLightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: kLightBackground,
  canvasColor: kLightBackground,
  primaryColor: kEmergencyRed,
  colorScheme: const ColorScheme.light(
    primary: kEmergencyRed,
    onPrimary: Colors.white,
    secondary: kEmergencyRed,
    onSecondary: Colors.white,
    surface: kLightSurface,
    onSurface: kLightInk,
    error: Color(0xFFB71C1C),
    onError: Colors.white,
    outline: kDividerLight,
    outlineVariant: kDividerLight,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: kAppBarLight,
    foregroundColor: kLightInk,
    elevation: 0,
    centerTitle: true,
    iconTheme: IconThemeData(color: kLightInk),
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
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: kEmergencyRed,
    foregroundColor: Colors.white,
    elevation: 2,
  ),
  chipTheme: const ChipThemeData(
    backgroundColor: kLightSurface,
    labelStyle: TextStyle(color: kLightInk),
    side: BorderSide(color: kDividerLight),
  ),
  segmentedButtonTheme: const SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(kLightSurface),
      foregroundColor: WidgetStatePropertyAll(kLightInk),
      side: WidgetStatePropertyAll(BorderSide(color: kDividerLight)),
    ),
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
    bodySmall: TextStyle(color: Color(0xFF3A3A3A), fontSize: 12),
    titleLarge: TextStyle(color: kLightInk, fontSize: 20, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(color: kLightInk, fontSize: 16, fontWeight: FontWeight.w600),
    labelLarge: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kEmergencyRed,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: kEmergencyRed,
      foregroundColor: Colors.white,
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
    labelStyle: TextStyle(color: kLightInk),
    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD32F2F))),
  ),
);
