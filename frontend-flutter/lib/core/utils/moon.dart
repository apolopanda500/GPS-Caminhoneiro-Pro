import 'dart:math' as math;

/// Fase da Lua (ciclo sinodico de 29,53 dias) e iluminacao.
class InfoLua {
  /// Idade da lua em dias desde a lua nova.
  final double idadeDias;

  /// Porcentagem iluminada (0 = nova, 100 = cheia).
  final double iluminacao;

  /// Nome da fase em portugues.
  final String fase;

  /// Emoji correspondente.
  final String emoji;

  const InfoLua({
    required this.idadeDias,
    required this.iluminacao,
    required this.fase,
    required this.emoji,
  });
}

/// Calcula a fase da lua para uma data (algoritmo do ciclo sinodico).
InfoLua calcularLua({DateTime? agora}) {
  // Lua nova de referencia: 2000-01-06 18:14 UTC.
  final referencia = DateTime.utc(2000, 1, 6, 18, 14);  const periodo = 29.530588853;
  final instante = (agora ?? DateTime.now()).toUtc();
  final dias = instante.difference(referencia).inSeconds / 86400.0;
  var idade = dias % periodo;
  if (idade < 0) idade += periodo;

  final fracao = idade / periodo;
  final iluminacao = (1 - math.cos(2 * math.pi * fracao)) / 2;

  String fase;
  String emoji;
  if (idade < 1.0 || idade > periodo - 1.0) {
    fase = 'Lua nova';
    emoji = '🌑';
  } else if (idade < 6.4) {
    fase = 'Lua crescente';
    emoji = '🌒';
  } else if (idade < 8.4) {
    fase = 'Quarto crescente';
    emoji = '🌓';
  } else if (idade < 13.8) {
    fase = 'Gibosa crescente';
    emoji = '🌔';
  } else if (idade < 15.8) {
    fase = 'Lua cheia';
    emoji = '🌕';
  } else if (idade < 21.1) {
    fase = 'Gibosa minguante';
    emoji = '🌖';
  } else if (idade < 23.1) {
    fase = 'Quarto minguante';
    emoji = '🌗';
  } else {
    fase = 'Minguante';
    emoji = '🌘';
  }

  return InfoLua(
    idadeDias: idade,
    iluminacao: iluminacao * 100,
    fase: fase,
    emoji: emoji,
  );
}
