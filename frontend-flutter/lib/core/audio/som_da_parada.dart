/// Qual som toca em cada momento da parada.
///
/// Fica separado do mapa para poder ser testado em bateria: e aqui que
/// mora a regra "o sino toca uma vez so" (o problema de som fora de
/// sincronia com as paradas).
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

  /// O sino de chegada toca **so na chegada** (nunca na saida/entrega).
  static bool tocaSino(MomentoParada momento) => momento == MomentoParada.chegada;

  /// O sino de estacao (sino de trem) toca junto com o sino de chegada.
  static bool tocaSinoEstacao(MomentoParada momento) =>
      momento == MomentoParada.chegada;

  /// O som de saida toca **so na saida**.
  static bool tocaSomSaida(MomentoParada momento) => momento == MomentoParada.saida;

  /// A voz fala na chegada e na saida (anuncia a proxima parada).
  static bool fala(MomentoParada momento) =>
      momento == MomentoParada.chegada || momento == MomentoParada.saida;

  /// O som "de entrega concluida" toca so na entrega.
  static bool tocaSomEntrega(MomentoParada momento) =>
      momento == MomentoParada.entrega;
}
