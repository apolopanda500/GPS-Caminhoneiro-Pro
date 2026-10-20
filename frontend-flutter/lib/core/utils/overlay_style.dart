import 'package:flutter/material.dart';

/// Paleta de destaque usada nos painéis e na barra de ferramentas do mapa.
const List<Color> kOverlayAccents = [
  Color(0xFF8B0000),
  Color(0xFFB45309),
  Color(0xFF1D4ED8),
  Color(0xFF15803D),
  Color(0xFF7E22CE),
  Color(0xFF334155),
];

/// Estilo dos elementos flutuantes sobre o mapa (botões, painéis, HUD).
///
/// Fica fora do app_theme de propósito: as cores de destaque e a
/// transparência são preferências do usuário e não fazem parte do tema.
class OverlayStyle {
  const OverlayStyle._();

  /// Cor de destaque escolhida pelo usuário.
  static Color accent(Color? accent) =>
      accent ?? kOverlayAccents.first;

  /// Superfície translúcida que acompanha o tema claro/escuro.
  static Color surface(BuildContext context, double opacity) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base =
        dark ? const Color(0xE6101418) : const Color(0xF2FFFFFF);
    final o = opacity.clamp(0.3, 1.0);
    return base.withValues(alpha: (base.a * o).clamp(0.05, 1.0));
  }

  /// Borda dos painéis, no destaque escolhido.
  static Color border(BuildContext context, Color accent) =>
      Theme.of(context).brightness == Brightness.dark
          ? accent.withValues(alpha: 0.85)
          : accent.withValues(alpha: 0.45);

  /// Texto legível sobre a superfície.
  static Color text(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A);
}
