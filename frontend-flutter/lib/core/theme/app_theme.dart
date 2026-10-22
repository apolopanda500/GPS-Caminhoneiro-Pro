import 'package:flutter/material.dart';

// ---------------------------------------------------------------- Paleta
const Color kDarkBlack = Color(0xFF0A0A0A);
const Color kDarkRedTransition = Color(0xFF1C0303);
const Color kEmergencyRed = Color(0xFF8B0000);
const Color kLightText = Color(0xFFE5E5E5);
const Color kLightBackground = Color(0xFFF5F2EE);
const Color kLightSurface = Color(0xFFFBF9F6);
const Color kLightInk = Color(0xFF1A1A1A);

const Color kAppBarDark = Color(0xFF1C0303);
const Color kAppBarLight = Color(0xFFFBF9F6);
const Color kDividerDark = Color(0x33FFFFFF);
const Color kDividerLight = Color(0x1F000000);

/// Mistura a cor de destaque com o fundo, para os cartoes/bottomsheets
/// acompanharem a cor escolhida pelo usuario.
Color _tint(Color accent, Color base, double forca) =>
    Color.alphaBlend(accent.withValues(alpha: forca), base);

/// Cor dos campos de digitacao e das barras de selecao.
///
/// Nao e branco puro: e a cor escolhida pelo usuario misturada com o fundo
/// do tema, para o campo se destacar do cartao sem estourar o olho.
Color fieldFill(BuildContext context, {Color? accent}) {
  final escuro = Theme.of(context).brightness == Brightness.dark;
  final destaque = accent ?? Theme.of(context).colorScheme.primary;
  return escuro
      ? _tint(destaque, kDarkBlack, 0.30)
      : _tint(destaque, kLightBackground, 0.12);
}

/// Versao sem [BuildContext], para usar dentro da montagem do tema.
Color fieldFillFor(Color accent, bool escuro) => escuro
    ? _tint(accent, kDarkBlack, 0.30)
    : _tint(accent, kLightBackground, 0.12);

/// Cor do texto dentro dos campos e das barras de selecao.
Color fieldText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? kLightText : kLightInk;

/// Versao sem [BuildContext], para usar dentro da montagem do tema.
Color fieldTextFor(bool escuro) => escuro ? kLightText : kLightInk;

/// Cor de apoio (dica, rotulo) dentro dos campos.
Color fieldHint(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white54
        : kLightInk.withValues(alpha: 0.55);

/// Versao sem [BuildContext], para usar dentro da montagem do tema.
Color fieldHintFor(bool escuro) =>
    escuro ? Colors.white54 : kLightInk.withValues(alpha: 0.55);

// --------------------------------------------------- Superficies no mapa
Color overlaySurface(
  BuildContext context, {
  double opacity = 1.0,
  Color? accent,
}) {
  final escuro = Theme.of(context).brightness == Brightness.dark;
  final Color destaque = accent ?? Theme.of(context).colorScheme.primary;
  final Color base = escuro ? _tint(destaque, kDarkBlack, 0.16) : kLightSurface;
  return base.withValues(
      alpha: (base.a * opacity.clamp(0.3, 1.0)).clamp(0.05, 1.0));
}

Color overlayBorder(BuildContext context, {Color? accent}) =>
    accent ??
    (Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.primary
        : const Color(0x33000000));

Color overlayAccent(BuildContext context, {Color? accent}) =>
    accent ?? Theme.of(context).colorScheme.primary;

Color overlayText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? Colors.white : kLightInk;

Color overlayTextMuted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : kLightInk;

Color overlayTextSoft(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : kLightInk.withValues(alpha: 0.7);

/// Fundo das folhas (bottomsheets) e dialogos: segue o tema e a cor escolhida.
Color sheetBackground(BuildContext context, {Color? accent}) {
  final escuro = Theme.of(context).brightness == Brightness.dark;
  final destaque = accent ?? Theme.of(context).colorScheme.primary;
  return escuro ? _tint(destaque, kDarkBlack, 0.18) : kLightSurface;
}

/// Divisor das folhas e listas.
Color sheetDivider(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? kDividerDark
        : kDividerLight;

/// Texto principal de uma folha.
Color sheetText(BuildContext context) => overlayText(context);

/// Texto secundario de uma folha.
Color sheetMuted(BuildContext context) => overlayTextMuted(context);

/// Cor de destaque (icones, acoes) de uma folha: a cor escolhida pelo usuario.
Color sheetAccent(BuildContext context, {Color? accent}) =>
    overlayAccent(context, accent: accent);

// ---------------------------------------------------------------- ESCURO
/// Tema escuro. [accent] e a cor escolhida pelo usuario na tela de Aparencia
/// e vale para TODO o app: botoes, cartoes, appbar, chips, campos e icones.
ThemeData appTheme({Color accent = kEmergencyRed}) {
  final surface = _tint(accent, kDarkBlack, 0.16);
  final appBar = _tint(accent, kDarkBlack, 0.22);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kDarkBlack,
    canvasColor: kDarkBlack,
    primaryColor: accent,
    colorScheme: ColorScheme.dark(
      primary: accent,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: kLightText,
      error: const Color(0xFFFF6B6B),
      onError: Colors.black,
      outline: kDividerDark,
      outlineVariant: kDividerDark,
    ),
    splashFactory: InkSplash.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: appBar,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      titleTextStyle:
          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      contentTextStyle: const TextStyle(color: kLightText),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: kLightText,
      textColor: kLightText,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      labelStyle: const TextStyle(color: kLightText),
      side: const BorderSide(color: kDividerDark),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(surface),
        foregroundColor: const WidgetStatePropertyAll(kLightText),
        side: const WidgetStatePropertyAll(BorderSide(color: kDividerDark)),
      ),
    ),
    dividerTheme:
        const DividerThemeData(color: kDividerDark, space: 1, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: appBar,
      indicatorColor: accent.withValues(alpha: 0.22),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? accent : kLightText,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected) ? accent : kLightText,
          fontSize: 12,
        ),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: appBar,
      selectedItemColor: accent,
      unselectedItemColor: kLightText,
      type: BottomNavigationBarType.fixed,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : Colors.white70,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? accent : Colors.white24,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: kLightText, fontSize: 16),
      bodyMedium: TextStyle(color: kLightText, fontSize: 14),
      bodySmall: TextStyle(color: Colors.white70, fontSize: 12),
      titleLarge: TextStyle(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
      labelLarge: TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: appBar,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldFillFor(accent, true),
      hintStyle: TextStyle(color: fieldHintFor(true)),
      labelStyle: TextStyle(color: fieldTextFor(true)),
      floatingLabelStyle: TextStyle(color: accent),
      prefixIconColor: fieldHintFor(true),
      suffixIconColor: fieldHintFor(true),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kDividerDark, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.6),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: TextStyle(color: fieldTextFor(true)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFillFor(accent, true),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kDividerDark, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------ CLARO
/// Tema claro. [accent] e a cor escolhida pelo usuario e vale para todo o app.
ThemeData appLightTheme({Color accent = kEmergencyRed}) {
  final surface = _tint(accent, kLightSurface, 0.10);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: kLightBackground,
    canvasColor: kLightBackground,
    primaryColor: accent,
    colorScheme: ColorScheme.light(
      primary: accent,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: kLightInk,
      error: const Color(0xFFB71C1C),
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
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      titleTextStyle: const TextStyle(
        color: kLightInk,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
      contentTextStyle: const TextStyle(color: Color(0xFF3A3A3A)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: kLightInk,
      textColor: kLightInk,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      labelStyle: const TextStyle(color: kLightInk),
      side: const BorderSide(color: kDividerLight),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(surface),
        foregroundColor: const WidgetStatePropertyAll(kLightInk),
        side: const WidgetStatePropertyAll(BorderSide(color: kDividerLight)),
      ),
    ),
    dividerTheme:
        const DividerThemeData(color: kDividerLight, space: 1, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: accent.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? accent : kLightInk,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected) ? accent : kLightInk,
          fontSize: 12,
        ),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: accent,
      unselectedItemColor: kLightInk,
      type: BottomNavigationBarType.fixed,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : Colors.white70,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? accent : Colors.black26,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: kLightInk, fontSize: 16),
      bodyMedium: TextStyle(color: Color(0xFF3A3A3A), fontSize: 14),
      bodySmall: TextStyle(color: Color(0xFF3A3A3A), fontSize: 12),
      titleLarge: TextStyle(
          color: kLightInk, fontSize: 20, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(
          color: kLightInk, fontSize: 16, fontWeight: FontWeight.w600),
      labelLarge: TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: kLightInk,
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldFillFor(accent, false),
      hintStyle: TextStyle(color: fieldHintFor(false)),
      labelStyle: TextStyle(color: fieldTextFor(false)),
      floatingLabelStyle: TextStyle(color: accent),
      prefixIconColor: fieldHintFor(false),
      suffixIconColor: fieldHintFor(false),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kDividerLight, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.6),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: TextStyle(color: fieldTextFor(false)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFillFor(accent, false),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kDividerLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      ),
    ),
  );
}
