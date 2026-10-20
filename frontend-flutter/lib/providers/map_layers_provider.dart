import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'package:gps_camioneiro_pro/core/network/weather_layers.dart';

/// Camadas ambientais em tempo real sobre o mapa.
///
/// - **Radar de chuva** (RainViewer: 1200+ radares, frames a cada 10 min)
/// - **Nuvens por infravermelho** (satelite)
/// - **Relevo** (hillshade com DEM real dos AWS Terrain Tiles)
class MapLayersProvider extends ChangeNotifier {
  bool _radar = false;
  bool _nuvens = false;
  bool _relevo = false;
  bool _carregando = false;

  String? _frameRadar;
  String? _frameInfrarrojo;
  Timer? _timer;

  ml.MapLibreMapController? _controller;

  bool get radar => _radar;
  bool get nuvens => _nuvens;
  bool get relevo => _relevo;
  bool get carregando => _carregando;

  /// Liga/desliga o radar de chuva.
  Future<void> setRadar(bool value) async {
    if (_radar == value) return;
    _radar = value;
    notifyListeners();
    if (value) await _atualizarFrames();
    await aplicar(_controller);
  }

  /// Liga/desliga as nuvens (infravermelho).
  Future<void> setNuvens(bool value) async {
    if (_nuvens == value) return;
    _nuvens = value;
    notifyListeners();
    if (value) await _atualizarFrames();
    await aplicar(_controller);
  }

  /// Liga/desliga o relevo (hillshade com relevo real).
  Future<void> setRelevo(bool value) async {
    if (_relevo == value) return;
    _relevo = value;
    notifyListeners();
    await aplicar(_controller);
  }

  /// Guarda o controller, agenda a atualizacao e aplica as camadas.
  Future<void> ligar(ml.MapLibreMapController controller) async {
    _controller = controller;
    _timer ??= Timer.periodic(const Duration(minutes: 10), (_) async {
      if (!_radar && !_nuvens) return;
      await _atualizarFrames();
      await aplicar(_controller);
    });
    await _atualizarFrames();
    await aplicar(controller);
  }

  Future<void> _atualizarFrames() async {
    _carregando = true;
    notifyListeners();
    final frames = await WeatherLayers.framesAtuais();
    _frameRadar = frames['radar'];
    _frameInfrarrojo = frames['infrarrojo'];
    _carregando = false;
    notifyListeners();
  }

  /// Aplica (ou remove) as camadas no mapa.
  Future<void> aplicar(ml.MapLibreMapController? controller) async {
    final c = controller;
    if (c == null) return;
    try {
      await _aplicarRaster(
        c,
        id: 'camada_radar',
        url: (z, x, y) => _frameRadar == null
            ? ''
            : WeatherLayers.urlRadar(_frameRadar!, z, x, y),
        ativo: _radar,
        opacidade: 0.55,
      );
      await _aplicarRaster(
        c,
        id: 'camada_nuvens',
        url: (z, x, y) => _frameInfrarrojo == null
            ? ''
            : WeatherLayers.urlInfrarrojo(_frameInfrarrojo!, z, x, y),
        ativo: _nuvens,
        opacidade: 0.45,
      );
      await _aplicarRelevo(c);
    } catch (_) {
      // Estilo recarregado: a proxima atualizacao reaplica as camadas.
    }
  }

  Future<void> _aplicarRaster(
    ml.MapLibreMapController c, {
    required String id,
    required String Function(int z, int x, int y) url,
    required bool ativo,
    required double opacidade,
  }) async {
    final sourceId = '${id}_fonte';
    final layerId = '${id}_camada';

    if (!ativo) {
      try {
        await c.removeLayer(layerId);
      } catch (_) {}
      try {
        await c.removeSource(sourceId);
      } catch (_) {}
      return;
    }

    try {
      await c.removeLayer(layerId);
    } catch (_) {}
    try {
      await c.removeSource(sourceId);
    } catch (_) {}

    c.addSource(sourceId, ml.RasterSourceProperties(
      tiles: [url(0, 0, 0)],
      tileSize: 256,
      minzoom: 0,
      maxzoom: 7,
    ));
    c.addLayer(sourceId, layerId, ml.RasterLayerProperties(
      rasterOpacity: opacidade,
    ));
  }

  /// Relevo real (hillshade) a partir do DEM dos AWS Terrain Tiles.
  Future<void> _aplicarRelevo(ml.MapLibreMapController c) async {
    const sourceId = 'terreno_dem_fonte';
    const layerId = 'terreno_relevo_camada';

    if (!_relevo) {
      try {
        await c.removeLayer(layerId);
      } catch (_) {}
      try {
        await c.removeSource(sourceId);
      } catch (_) {}
      return;
    }

    try {
      await c.removeLayer(layerId);
    } catch (_) {}
    try {
      await c.removeSource(sourceId);
    } catch (_) {}

    c.addSource(sourceId, const ml.RasterDemSourceProperties(
      tiles: [
        'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png',
      ],
      tileSize: 256,
      encoding: 'terrarium',
      maxzoom: 15,
    ));
    c.addLayer(sourceId, layerId, const ml.HillshadeLayerProperties(
      hillshadeExaggeration: 0.4,
      hillshadeShadowColor: '#1A1A1A',
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
