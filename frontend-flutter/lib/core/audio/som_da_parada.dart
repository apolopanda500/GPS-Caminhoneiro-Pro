/// Qual som toca em cada momento da parada.
///
/// Regra do app: **um unico sino** na chegada e a voz falando apenas o
/// numero da parada ou o nome do cliente. Sem som de saida, sem som de
/// entrega e sem falar nomes de ruas.
library;

enum MomentoParada {
  /// O caminhao entrou no raio da parada (chegada).
  chegada,

  /// O caminhao saiu da parada e comecou a andar.
  saida,

  /// A entrega foi confirmada (dwell cumprido).
  entrega,
}

/// Sons que podem tocar em cada momento.
class SomDaParada {
  const SomDaParada._();

  /// O sino unico toca **so na chegada** (nunca na saida/entrega).
  static bool tocaSino(MomentoParada momento) =>
      momento == MomentoParada.chegada;

  /// A voz fala na chegada e na saida (anuncia a proxima parada por numero
  /// ou nome do cliente).
  static bool fala(MomentoParada momento) =>
      momento == MomentoParada.chegada || momento == MomentoParada.saida;
}
