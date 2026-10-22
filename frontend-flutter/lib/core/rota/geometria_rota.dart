import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Calculos de geometria usados pelo acompanhamento da rota no mapa:
/// distancia do caminhao ate a linha, trecho que ainda falta e direcao.
class GeometriaRota {
  GeometriaRota._();

  static const Distance _distance = Distance();

  /// Distancia em metros entre dois pontos.
  static double distancia(LatLng a, LatLng b) =>
      _distance.as(LengthUnit.Meter, a, b);

  /// Projeta [ponto] no segmento [a]-[b] e devolve a distancia em metros.
  static double distanciaAoSegmento(LatLng ponto, LatLng a, LatLng b) {
    final comprimento = distancia(a, b);
    if (comprimento <= 0.01) return distancia(ponto, a);
    final proporcao =
        ((ponto.longitude - a.longitude) * (b.longitude - a.longitude) +
                (ponto.latitude - a.latitude) *
                    (b.latitude - a.latitude) *
                    math.cos(a.latitude * math.pi / 180) *
                    math.cos(a.latitude * math.pi / 180)) /
            (math.pow(b.longitude - a.longitude, 2) +
                math.pow(
                    (b.latitude - a.latitude) *
                        math.cos(a.latitude * math.pi / 180),
                    2));
    final t = proporcao.clamp(0.0, 1.0);
    final projetado = LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
    return distancia(ponto, projetado);
  }

  /// Menor distancia do caminhao ate qualquer trecho da rota.
  static double distanciaAteRota(List<LatLng> rota, LatLng ponto) {
    if (rota.isEmpty) return double.infinity;
    if (rota.length == 1) return distancia(ponto, rota.first);
    var menor = double.infinity;
    for (var i = 0; i < rota.length - 1; i++) {
      final d = distanciaAoSegmento(ponto, rota[i], rota[i + 1]);
      if (d < menor) menor = d;
    }
    return menor;
  }

  /// Indice do ponto da rota mais proximo do caminhao.
  static int indiceMaisProximo(List<LatLng> rota, LatLng ponto) {
    if (rota.isEmpty) return -1;
    var melhor = 0;
    var menor = double.infinity;
    for (var i = 0; i < rota.length; i++) {
      final d = distancia(ponto, rota[i]);
      if (d < menor) {
        menor = d;
        melhor = i;
      }
    }
    return melhor;
  }

  /// Trecho da rota que ainda falta percorrer.
  ///
  /// Descarta o que ja ficou para tras a partir do ponto mais proximo do
  /// caminhao, mantendo [margemMetros] de linha atras dele para a linha nao
  /// "cortar" na frente do veiculo. A posicao atual entra no inicio para a
  /// linha sair de dentro do caminhao.
  static List<LatLng> restante(
    List<LatLng> rota,
    LatLng posicao, {
    double margemMetros = 30,
  }) {
    if (rota.length < 2) return List<LatLng>.from(rota);
    final indice = indiceMaisProximo(rota, posicao);
    var inicio = indice;
    var acumulado = 0.0;
    for (var i = indice; i > 0; i--) {
      final trecho = distancia(rota[i], rota[i - 1]);
      if (acumulado + trecho > margemMetros) break;
      acumulado += trecho;
      inicio = i - 1;
    }
    final trecho = <LatLng>[posicao, ...rota.sublist(inicio)];
    final limpo = <LatLng>[];
    for (final p in trecho) {
      if (limpo.isEmpty || distancia(limpo.last, p) > 1) limpo.add(p);
    }
    return limpo.length < 2 ? List<LatLng>.from(rota) : limpo;
  }

  /// Direcao (graus, 0 = norte) do ponto [a] para o ponto [b].
  static double bearing(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180 / math.pi;
    return (brng + 360) % 360;
  }

  /// Suaviza a direcao da camera sem dar a volta pelo lado errado.
  static double suavizarBearing(double atual, double alvo, double fator) {
    var diferenca = (alvo - atual + 540) % 360 - 180;
    if (diferenca.abs() <= 1) return alvo % 360;
    return (atual + diferenca * fator.clamp(0.0, 1.0)) % 360;
  }

  /// Ponto [metros] a frente de [origem] na direcao [bearingGraus].
  static LatLng deslocar(LatLng origem, double bearingGraus, double metros) {
    const raioTerra = 6378137.0;
    final angular = metros / raioTerra;
    final direcao = bearingGraus * math.pi / 180;
    final lat1 = origem.latitude * math.pi / 180;
    final lon1 = origem.longitude * math.pi / 180;
    final lat2 = math.asin(math.sin(lat1) * math.cos(angular) +
        math.cos(lat1) * math.sin(angular) * math.cos(direcao));
    final lon2 = lon1 +
        math.atan2(
          math.sin(direcao) * math.sin(angular) * math.cos(lat1),
          math.cos(angular) - math.sin(lat1) * math.sin(lat2),
        );
    return LatLng(lat2 * 180 / math.pi, lon2 * 180 / math.pi);
  }
}
