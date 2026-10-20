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

  /// true = o sol esta acima do horizonte.
  final bool ehDia;

  const InfoSolar({
    this.nascerDoSol,
    this.porDoSol,
    required this.meioDiaSolar,
    required this.elevacaoGraus,
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
  final hora = instante.hour + instante.minute / 60.0;

  // Anos fracionarios (gamma)
  final gamma = 2 * math.pi / 365 * (dias + (hora - 12) / 24);

  // Equacao do tempo (em minutos)
  final eqt =
      229.18 * (0.000075 + 0.001868 * math.cos(gamma) - 0.032077 * math.sin(gamma) -
          0.014615 * math.cos(2 * gamma) -
          0.040849 * math.sin(2 * gamma));

  // Declinacao solar
  final decl =
      0.006918 - 0.399912 * math.cos(gamma) + 0.070257 * math.sin(gamma) -
          0.006758 * math.cos(2 * gamma) +
          0.000907 * math.sin(2 * gamma) -
          0.002697 * math.cos(3 * gamma) +
          0.00148 * math.sin(3 * gamma);

  // Hora solar
  final ts = hora * 60 + eqt + 4 * longitude;
  final ha = math.acos(
      ((math.cos(0.833 * math.pi / 180) - math.sin(latitude * math.pi / 180) * math.sin(decl)) /
              (math.cos(latitude * math.pi / 180) * math.cos(decl)))
          .clamp(-1.0, 1.0));

  // Nascer e por do sol (em UTC)
  final meioDiaUtc = DateTime.utc(instante.year, instante.month, instante.day)
      .add(Duration(minutes: ts.round()));
  final nascer = meioDiaUtc.subtract(Duration(minutes: (ha * 180 / math.pi * 4).round()));
  final por = meioDiaUtc.add(Duration(minutes: (ha * 180 / math.pi * 4).round()));

  // Elevacao solar atual
  final elevacao =
      math.asin(math.sin(latitude * math.pi / 180) * math.sin(decl) +
              math.cos(latitude * math.pi / 180) * math.cos(decl) * math.cos(ts * math.pi / 180 - math.pi)) *
          180 /
          math.pi;

  return InfoSolar(
    nascerDoSol: nascer.toLocal(),
    porDoSol: por.toLocal(),
    meioDiaSolar: meioDiaUtc.toLocal(),
    elevacaoGraus: elevacao,
    ehDia: elevacao > -0.833,
  );
}
