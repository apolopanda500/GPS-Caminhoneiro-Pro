import 'dart:async';
import 'dart:convert';

import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';

/// Camada de **transito em tempo real** no mapa.
///
/// Usa os tiles vetoriais de fluxo do TomTom (Orbis v2): cada trecho de via
/// vem com o `relative_speed` (1 = livre, 0 = parado) e o app pinta a via de
/// verde a vermelho. O motorista ve o gargalo antes de chegar nele.
class CamadaTrafego {
  CamadaTrafego._();
  static final CamadaTrafego instancia = CamadaTrafego._();

  static const String idFonte = 'tomtom-trafego';
  static const String idCamada = 'tomtom-trafego-via';

  /// Nome da camada dentro do tile vetorial.
  static const String camadaDoTile = 'Traffic flow';

  static bool get disponivel => AppConstants.trafficConfigured;

  static String get _urlTiles =>
      'https://api.tomtom.com/maps/orbis/traffic/flow/vector/tile/'
      '{z}/{x}/{y}?apiVersion=2&key=${AppConstants.tomTomTrafficApiKey}';

  /// Cor da via conforme a velocidade relativa (1 = livre, 0 = parado).
  static final List<Object> _cores = [
    'interpolate',
    ['linear'],
    ['get', 'relative_speed'],
    0.0,
    '#C62828',
    0.2,
    '#E65100',
    0.4,
    '#F9A825',
    0.7,
    '#2E7D32',
    1.0,
    '#1B5E20',
  ];

  /// Largura da linha conforme o zoom (fina: o transito e um aviso, nao
  /// pode cobrir a via).
  static final List<Object> _largura = [
    'interpolate',
    ['linear'],
    ['zoom'],
    8,
    0.6,
    12,
    1.2,
    15,
    2.0,
    18,
    3.5,
  ];

  /// Primeira camada do estilo que desenha nomes de ruas, bairros ou pontos.
  ///
  /// O transito entra ABAIXO dela para nao cobrir os nomes das ruas. Estilos
  /// vetoriais usam camadas `symbol`; os estilos raster (satelite) tem uma
  /// camada de nomes (ex.: `esri-nomes-overlay`).
  Future<String?> _camadaDeRotulos(ml.MapLibreMapController controller) async {
    try {
      final raw = await controller.getStyle();
      if (raw == null || raw.isEmpty) return null;
      final estilo = jsonDecode(raw);
      if (estilo is! Map) return null;
      final layers = estilo['layers'];
      if (layers is! List) return null;
      for (final layer in layers) {
        if (layer is! Map) continue;
        final id = (layer['id'] ?? '').toString();
        final tipo = (layer['type'] ?? '').toString();
        final nome = id.toLowerCase();
        final ehRotulo = tipo == 'symbol' ||
            nome.contains('label') ||
            nome.contains('name') ||
            nome.contains('nomes') ||
            nome.contains('places') ||
            nome.contains('place-');
        if (ehRotulo) return id;
      }
    } catch (_) {}
    return null;
  }

  /// Liga (ou desliga) a camada de transito no mapa.
  Future<void> aplicar(ml.MapLibreMapController controller) async {
    if (!disponivel) return;
    try {
      await controller.removeLayer(idCamada);
    } catch (_) {}
    try {
      await controller.removeSource(idFonte);
    } catch (_) {}

    try {
      await controller.addSource(
        idFonte,
        ml.VectorSourceProperties(
          tiles: [_urlTiles],
          minzoom: 6,
          maxzoom: 22,
        ),
      );
    } catch (_) {
      return;
    }

    final abaixoDe = await _camadaDeRotulos(controller);
    try {
      await controller.addLayer(
        idFonte,
        idCamada,
        ml.LineLayerProperties(
          lineColor: _cores,
          lineWidth: _largura,
          lineOpacity: 0.62,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        sourceLayer: camadaDoTile,
        belowLayerId: abaixoDe,
        // So mostra o que esta lento: evita um emaranhado de linhas verdes
        // por cima das ruas e dos nomes.
        filter: [
          '<',
          ['get', 'relative_speed'],
          0.7,
        ],
      );
    } catch (_) {
      // Se a layer nao entrar, o mapa continua funcionando sem o transito.
    }
  }

  /// Remove a camada de transito.
  Future<void> remover(ml.MapLibreMapController controller) async {
    try {
      await controller.removeLayer(idCamada);
    } catch (_) {}
    try {
      await controller.removeSource(idFonte);
    } catch (_) {}
  }
}
