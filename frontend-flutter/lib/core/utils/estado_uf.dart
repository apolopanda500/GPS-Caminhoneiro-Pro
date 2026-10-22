import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Caixa geographica aproximada de cada estado brasileiro.
///
/// Serve como resposta imediata (sem internet). A resposta precisa vem do
/// geocodificador reverso ([estadoPreciso]).
class CaixaEstado {
  final String uf;
  final double latMin;
  final double latMax;
  final double lonMin;
  final double lonMax;

  const CaixaEstado(
      this.uf, this.latMin, this.latMax, this.lonMin, this.lonMax);

  bool contem(double lat, double lon) {
    final latOk =
        lat >= math.min(latMin, latMax) && lat <= math.max(latMin, latMax);
    final lonOk =
        lon >= math.min(lonMin, lonMax) && lon <= math.max(lonMin, lonMax);
    return latOk && lonOk;
  }
}

/// Ordem de teste: os estados menores e do litoral primeiro (MG, BA, PR e SP
/// engoliriam os vizinhos sem isso).
const List<CaixaEstado> kCaixasEstado = [
  CaixaEstado('AC', -11.10, -7.90, -74.20, -66.50),
  CaixaEstado('AP', -1.00, 4.60, -54.10, -49.80),
  CaixaEstado('RR', 1.20, 5.30, -67.80, -59.80),
  CaixaEstado('RO', -13.40, 9.40, -74.60, -59.90),
  CaixaEstado('AM', -4.20, 2.20, -69.80, -56.10),
  CaixaEstado('PA', -9.90, -0.20, -54.10, -46.30),
  CaixaEstado('MA', -10.20, -1.20, -48.00, -40.20),
  CaixaEstado('PI', -10.20, -2.70, -45.40, -40.20),
  CaixaEstado('RJ', -23.10, -21.90, -44.30, -40.90),
  CaixaEstado('ES', -20.50, -17.90, -41.20, -39.20),
  CaixaEstado('SE', -11.50, -9.60, -38.60, -36.10),
  CaixaEstado('AL', -10.50, -8.90, -37.40, -35.10),
  CaixaEstado('PB', -8.30, -6.20, -37.30, -34.79),
  CaixaEstado('PE', -9.20, -3.80, -38.20, -33.10),
  CaixaEstado('CE', -6.00, -2.70, -39.60, -34.50),
  CaixaEstado('RN', -6.30, -4.90, -37.60, -34.60),
  CaixaEstado('DF', -16.00, -15.30, -48.20, -47.50),
  CaixaEstado('GO', -19.80, -13.70, -52.20, -40.80),
  CaixaEstado('MT', -19.20, -7.30, -60.50, -50.20),
  CaixaEstado('MS', -22.00, -19.00, -58.20, -47.40),
  CaixaEstado('TO', -9.50, 5.20, -49.40, -45.80),
  CaixaEstado('SC', -29.40, -25.90, -53.80, -48.30),
  CaixaEstado('RS', -30.20, -27.10, -57.70, -49.60),
  CaixaEstado('PR', -26.70, -22.50, -54.60, -48.00),
  CaixaEstado('MG', -22.30, -14.10, -53.30, -40.30),
  CaixaEstado('SP', -25.30, -19.70, -53.30, -39.60),
  CaixaEstado('BA', -18.50, -10.20, -44.40, -35.50),
];

/// Nome completo do estado -> sigla (para o retorno do geocodificador).
const Map<String, String> kNomeParaUf = {
  'acre': 'AC',
  'alagoas': 'AL',
  'amapa': 'AP',
  'amazonas': 'AM',
  'bahia': 'BA',
  'ceara': 'CE',
  'distrito federal': 'DF',
  'espirito santo': 'ES',
  'goias': 'GO',
  'maranhao': 'MA',
  'mato grosso': 'MT',
  'mato grosso do sul': 'MS',
  'minas gerais': 'MG',
  'para': 'PA',
  'paraiba': 'PB',
  'parana': 'PR',
  'pernambuco': 'PE',
  'piau': 'PI',
  'rio de janeiro': 'RJ',
  'rio grande do norte': 'RN',
  'rio grande do sul': 'RS',
  'rondonia': 'RO',
  'roraima': 'RR',
  'santa catarina': 'SC',
  'sao paulo': 'SP',
  'sergipe': 'SE',
  'tocantins': 'TO',
};

/// Estado (UF) da posicao, pela caixa aproximada. Resposta imediata.
String? estadoDaPosicao(LatLng pos) {
  for (final caixa in kCaixasEstado) {
    if (caixa.contem(pos.latitude, pos.longitude)) return caixa.uf;
  }
  return null;
}

/// Estado (UF) exato, pelo geocodificador reverso (Nominatim).
///
/// [resolver] existe para os testes: sem ele, usa a API real.
/// Guarda o ultimo resultado para nao consultar a cada posicao do GPS.
class EstadoUf {
  EstadoUf._();
  static final EstadoUf instancia = EstadoUf._();

  String? _uf;
  LatLng? _ultimaPosicao;
  DateTime _quando = DateTime.fromMillisecondsSinceEpoch(0);

  /// UF atual (caixa, imediata) e a data da ultima consulta precisa.
  String? get uf => _uf;

  /// Descobre a UF do caminhao. Consulta o geocodificador reverso no maximo
  /// uma vez a cada 5 minutos ou quando o caminhao muda de estado.
  Future<String?> descobrir(LatLng pos, {bool forcar = false}) async {
    final agora = DateTime.now();
    final longe =
        _ultimaPosicao == null || _distancia(_ultimaPosicao!, pos) > 2000;
    if (!forcar &&
        _uf != null &&
        !longe &&
        agora.difference(_quando) < const Duration(minutes: 5)) {
      return _uf;
    }
    final preciso = await estadoPreciso(pos);
    if (preciso == null) return _uf ?? estadoDaPosicao(pos);
    _uf = preciso;
    _ultimaPosicao = pos;
    _quando = agora;
    return _uf;
  }

  static double _distancia(LatLng a, LatLng b) {
    final dx = (a.longitude - b.longitude) * 111320 * 0.75;
    final dy = (a.latitude - b.latitude) * 111320;
    return (dx * dx + dy * dy);
  }
}

/// Estado (UF) exato, pelo geocodificador reverso (Nominatim).
///
/// [resolver] existe para os testes: sem ele, usa a API real.
Future<String?> estadoPreciso(
  LatLng pos, {
  Future<String?> Function(LatLng)? resolver,
}) async {
  try {
    if (resolver != null) return await resolver(pos);
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=5'
      '&lat=${pos.latitude}&lon=${pos.longitude}',
    );
    final resp = await http.get(uri, headers: {
      'User-Agent': 'gps-camioneiro-pro/1.0'
    }).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return estadoDaPosicao(pos);
    final data =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final address = data['address'] as Map<String, dynamic>? ?? const {};
    final nome = (address['state'] ?? '').toString().toLowerCase();
    final uf = kNomeParaUf[nome];
    return uf ?? estadoDaPosicao(pos);
  } catch (_) {
    return estadoDaPosicao(pos);
  }
}
