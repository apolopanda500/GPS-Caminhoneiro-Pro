import 'package:latlong2/latlong.dart';

/// Caixa geographica aproximada de cada estado brasileiro.
///
/// Usado para descobrir a UF a partir da posicao do GPS (sem depender de
/// internet): o app so busca e filtra dentro do estado onde o caminhao esta.
class CaixaEstado {
  final String uf;
  final double latMin;
  final double latMax;
  final double lonMin;
  final double lonMax;

  const CaixaEstado(this.uf, this.latMin, this.latMax, this.lonMin, this.lonMax);

  bool contem(double lat, double lon) =>
      lat >= latMin && lat <= latMax && lon >= lonMin && lon <= lonMax;
}

/// As caixas estao em ordem de especificidade: os estados menores e do
/// litoral sao testados antes dos grandes (MG, BA e PR engoliriam os
/// vizinhos sem isso).
const List<CaixaEstado> kCaixasEstado = [
  // Litoral / small
  CaixaEstado('RJ', -22.03, -22.75, -41.05, -44.60),
  CaixaEstado('ES', -17.90, -20.50, -39.20, -41.20),
  CaixaEstado('SE', -9.60, -11.50, -36.10, -38.60),
  CaixaEstado('AL', -8.90, -10.50, -35.10, -37.40),
  CaixaEstado('PB', -6.20, -8.30, -34.70, -37.30),
  CaixaEstado('PE', -3.80, -9.20, -33.10, -38.20),
  CaixaEstado('CE', -2.70, -6.00, -34.50, -39.60),
  CaixaEstado('RN', -4.90, -6.30, -34.60, -37.60),
  CaixaEstado('SC', -25.90, -29.40, -48.30, -53.80),
  CaixaEstado('PR', -22.50, -26.70, -48.00, -54.60),
  CaixaEstado('SP', -19.70, -25.30, -39.70, -53.20),
  CaixaEstado('RS', -27.10, -30.20, -49.60, -57.70),
  CaixaEstado('BA', -10.20, -18.50, -35.50, -44.40),
  CaixaEstado('MA', -1.20, -10.20, -40.20, -48.50),
  CaixaEstado('PI', -2.70, -10.20, -40.20, -45.40),
  CaixaEstado('PA', -0.20, -9.90, -46.30, -54.10),
  CaixaEstado('AM', 2.20, -4.20, -56.10, -69.80),
  CaixaEstado('TO', 5.20, -9.50, -45.80, -49.40),
  CaixaEstado('GO', -13.70, -19.80, -40.80, -52.20),
  CaixaEstado('MT', -7.30, -19.20, -50.20, -60.50),
  CaixaEstado('MS', -19.00, -22.00, -47.40, -58.20),
  CaixaEstado('DF', -16.00, -15.40, -48.20, -47.60),
  CaixaEstado('MG', -14.10, -22.30, -40.30, -53.30),
  CaixaEstado('ES2', -17.90, -20.50, -39.20, -41.20),
  CaixaEstado('RO', 9.40, -13.40, -59.80, -74.60),
  CaixaEstado('AC', -7.90, -11.10, -68.60, -73.80),
  CaixaEstado('RR', 1.20, 5.30, -59.80, -67.80),
  CaixaEstado('AP', 0.10, 4.40, -50.10, -54.10),
];

/// Estado (UF) da posicao do GPS, ou null se estiver fora do Brasil.
String? estadoDaPosicao(LatLng pos) {
  for (final caixa in kCaixasEstado) {
    if (caixa.uf == 'ES2') continue;
    if (caixa.contem(pos.latitude, pos.longitude)) return caixa.uf;
  }
  return null;
}
