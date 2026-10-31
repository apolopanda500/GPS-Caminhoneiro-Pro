import 'dart:math' as math;

/// Informacoes solares calculadas localmente (algoritmo NOAA).
///
/// Nao depende de API: funciona offline e e exato para sunrise/sunset,
/// meio-dia solar e altura do sol (para saber se e dia ou noite).
class InfoSolar {
  final DateTime? nascerDoSol;
  final DateTime? porDoSol;
  final DateTime meioDiaSolar;
  final double elevacaoGraus;
  /// Azimute do sol em graus (0 = norte, 90 = leste, 180 = sul).
  final double azimuteGraus;

  /// true = o sol esta acima do horizonte.
  final bool ehDia;

  const InfoSolar({
    this.nascerDoSol,
    this.porDoSol,
    required this.meioDiaSolar,
    required this.elevacaoGraus,
    required this.azimuteGraus,
    required this.ehDia,
  });

  /// Duracao da noite (em horas) na data referencia.
  double get horasDeNoite {
    final n = nascerDoSol;
    final p = porDoSol;
    if (n == null || p == null) return 0;
    var d = p.difference(n).inMinutes / 60.0;
    if (d <= 0) d += 24;
    return d;
  }
}

/// Calcula a posicao do sol para uma latitude/longitude.
///
/// [agora] e opcional (padrao: momento atual). O resultado usa o horario
/// local do dispositivo.
InfoSolar calcularSolar({
  required double latitude,
  required double longitude,
  DateTime? agora,
}) {
  final instante = (agora ?? DateTime.now()).toUtc();
  final dias = instante.difference(DateTime.utc(2000)).inDays;
  final minutosUtc =
      instante.hour * 60.0 + instante.minute + instante.second / 60.0;

  // Anos fracionarios (gamma)
  final gamma = 2 * math.pi / 365 * (dias + (minutosUtc / 60 - 12) / 24);

  // Equacao do tempo (em minutos)
  final eqt = 229.18 *
      (0.000075 +
          0.001868 * math.cos(gamma) -
          0.032077 * math.sin(gamma) -
          0.014615 * math.cos(2 * gamma) -
          0.040849 * math.sin(2 * gamma));

  // Declinacao solar
  final decl = 0.006918 -
      0.399912 * math.cos(gamma) +
      0.070257 * math.sin(gamma) -
      0.006758 * math.cos(2 * gamma) +
      0.000907 * math.sin(2 * gamma) -
      0.002697 * math.cos(3 * gamma) +
      0.00148 * math.sin(3 * gamma);

  final latRad = latitude * math.pi / 180;

  // Hora solar verdadeira (minutos) e angulo horario (radianos).
  final ts = minutosUtc + eqt + 4 * longitude;
  final anguloHorario = (ts / 4 - 180) * math.pi / 180;

  // Meio-dia solar em UTC e hora do nascer/por do sol.
  final meioDiaMin = 720 - 4 * longitude - eqt;
  final ha = math.acos(((math.cos(0.833 * math.pi / 180) -
              math.sin(latRad) * math.sin(decl)) /
          (math.cos(latRad) * math.cos(decl)))
      .clamp(-1.0, 1.0));
  final meiaDuracaoMin = ha * 180 / math.pi * 4;

  final base = DateTime.utc(instante.year, instante.month, instante.day);
  final meioDiaUtc = base.add(Duration(minutes: meioDiaMin.round()));
  final nascer =
      base.add(Duration(minutes: (meioDiaMin - meiaDuracaoMin).round()));
  final por =
      base.add(Duration(minutes: (meioDiaMin + meiaDuracaoMin).round()));

  // Elevacao solar atual
  final elevacao = math.asin(
          math.sin(latRad) * math.sin(decl) +
              math.cos(latRad) * math.cos(decl) * math.cos(anguloHorario)) *
      180 /
      math.pi;

  // Azimute solar (0 = norte, 90 = leste, 180 = sul, 270 = oeste).
  final azimute = (math.atan2(
                  math.sin(anguloHorario),
                  math.cos(anguloHorario) * math.sin(latRad) -
                      math.tan(decl) * math.cos(latRad)) *
              180 /
              math.pi +
          180) %
      360;

  return InfoSolar(
    nascerDoSol: nascer.toLocal(),
    porDoSol: por.toLocal(),
    meioDiaSolar: meioDiaUtc.toLocal(),
    elevacaoGraus: elevacao,
    azimuteGraus: azimute,
    ehDia: elevacao > -0.833,
  );
}

/// Quanto escurecer o mapa no modo realista.
///
/// 0 = dia claro; 0,28 no crepusculo; ate ~0,5 na madrugada. A lua cheia
/// clareia um pouco a cena noturna (menos escurecida).
double fatorEscuridao({
  required double elevacaoGraus,
  double iluminacaoLua = 0,
}) {
  if (elevacaoGraus >= 6) return 0;
  if (elevacaoGraus >= -6) {
    return ((6 - elevacaoGraus) / 12 * 0.28).clamp(0.0, 0.28);
  }
  final noite = ((-elevacaoGraus - 6) / 12).clamp(0.0, 1.0);
  final base = 0.34 + noite * 0.16;
  final lua = (iluminacaoLua / 100).clamp(0.0, 1.0) * 0.12;
  return (base - lua).clamp(0.0, 0.6);
}
