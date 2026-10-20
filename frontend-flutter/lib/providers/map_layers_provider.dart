import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:latlong2/latlong.dart';

import 'package:gps_camioneiro_pro/core/network/weather_layers.dart';

/// Camadas ambientais em tempo real sobre o mapa.
///
/// - **Radar de chuva animado** (RainViewer: 1200+ radares, frames a cada
///   10 min, com 2 h de passado e previsao) - da para ver a chuva se movendo.
/// - **Precipitacao, vento, temperatura e nuvens** (Open-Meteo) desenhados
///   como circulos coloridos sobre o mapa.
/// - **Relevo** (hillshade com DEM real dos AWS Terrain Tiles)
class MapLayersProvider extends ChangeNotifier {
  bool _radar = false;
  bool _nuvens = false;
  bool _relevo = false;
  bool _precipitacao = false;
  bool _vento = false;
  bool _temperatura = false;
  bool _carregando = false;

  String? _frameRadar;
  String? _frameInfrarrojo;
  Timer? _timer;

  /// Timeline do radar (passado + previsao).
  List<FrameRadar> _frames = const [];
  int _frameAtual = 0;
  bool _animando = false;
  Timer? _animador;

  /// Pontos da grade de previsao (por camada).
  final Map<String, List<Ponto>> _grades = {};

  ml.MapLibreMapController? _controller;

  bool get radar => _radar;
  bool get nuvens => _nuvens;
  bool get relevo => _relevo;
  bool get precipitacao => _precipitacao;
  bool get vento => _vento;
  bool get temperatura => _temperatura;
  bool get carregando => _carregando;

  /// Quantos frames de radar existem (2 h de passado + previsao).
  int get totalFrames => _frames.length;

  /// Frame que esta na tela agora.
  int get frameAtual => _frameAtual;

  /// O radar esta animando (play)?
  bool get animando => _animando;

  /// Rotulo do frame atual (hora) e se e previsao.
  String get rotuloFrame {
    if (_frames.isEmpty) return '';
    final f = _frames[_frameAtual.clamp(0, _frames.length - 1)];
    return f.nowcast ? '${f.hora} (previsão)' : f.hora;
  }

  /// Liga/desliga o radar de chuva.
  Future<void> setRadar(bool value) async {
    if (_radar == value) return;
    _radar = value;
    notifyListeners();
    if (value) {
      await _atualizarFrames();
      _iniciarAnimacao();
    } else {
      _pararAnimacao();
    }
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

  /// Liga/desliga a previsao de precipitacao (Open-Meteo).
  Future<void> setPrecipitacao(bool value) async {
    if (_precipitacao == value) return;
    _precipitacao = value;
    notifyListeners();
    if (value) await _atualizarGrade('precipitacao');
    await aplicar(_controller);
  }

  /// Liga/desliga o vento (Open-Meteo).
  Future<void> setVento(bool value) async {
    if (_vento == value) return;
    _vento = value;
    notifyListeners();
    if (value) await _atualizarGrade('vento');
    await aplicar(_controller);
  }

  /// Liga/desliga a temperatura (Open-Meteo).
  Future<void> setTemperatura(bool value) async {
    if (_temperatura == value) return;
    _temperatura = value;
    notifyListeners();
    if (value) await _atualizarGrade('temperatura');
    await aplicar(_controller);
  }

  /// Liga/desliga a cobertura de nuvens prevista (Open-Meteo).
  Future<void> setNuvensPrevistas(bool value) async {
    if (_nuvensPrevistas == value) return;
    _nuvensPrevistas = value;
    notifyListeners();
    if (value) await _atualizarGrade('nuvens');
    await aplicar(_controller);
  }

  bool _nuvensPrevistas = false;
  bool get nuvensPrevistas => _nuvensPrevistas;

  /// Da play/pause na animacao do radar.
  void alternarAnimacao() {
    if (_animando) {
      _pararAnimacao();
    } else {
      _iniciarAnimacao();
    }
    notifyListeners();
  }

  /// Volta o radar para o inicio (passado).
  void recomecarRadar() {
    _frameAtual = 0;
    _aplicarFrame();
    notifyListeners();
  }

  void _iniciarAnimacao() {
    if (_frames.length < 2) return;
    _animando = true;
    _animador?.cancel();
    _animador = Timer.periodic(const Duration(milliseconds: 700), (_) {
      _frameAtual = (_frameAtual + 1) % _frames.length;
      _aplicarFrame();
      notifyListeners();
    });
  }

  void _pararAnimacao() {
    _animando = false;
    _animador?.cancel();
    _animador = null;
  }

  void _aplicarFrame() {
    if (_frames.isEmpty) return;
    final f = _frames[_frameAtual.clamp(0, _frames.length - 1)];
    _frameRadar = f.path;
    final c = _controller;
    if (c == null) return;
    _aplicarRaster(
      c,
      id: 'camada_radar',
      url: (z, x, y) => WeatherLayers.urlRadar(f.path, z, x, y),
      ativo: _radar,
      opacidade: 0.6,
    );
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
    final frames = await WeatherLayers.framesRadar();
    _frames = frames;
    if (frames.isNotEmpty) {
      _frameAtual = frames.length - 1;
      _frameRadar = frames[_frameAtual].path;
    }
    final mapa = await WeatherLayers.framesAtuais();
    _frameInfrarrojo = mapa['infrarrojo'];
    _carregando = false;
    notifyListeners();
  }

  /// Busca a grade de previsao de uma camada (Open-Meteo).
  Future<void> _atualizarGrade(String camada) async {
    final pos = _posicaoAtual;
    if (pos == null) return;
    _carregando = true;
    notifyListeners();
    final pontos = await WeatherLayers.gradePrevisao(
      pos.latitude,
      pos.longitude,
      campo: switch (camada) {
        'precipitacao' => 'precipitation_probability',
        'vento' => 'wind_speed_10m',
        'temperatura' => 'temperature_2m',
        _ => 'cloud_cover',
      },
    );
    _grades[camada] = pontos;
    _carregando = false;
    notifyListeners();
  }

  /// Posicao usada como centro das grades de previsao.
  LatLng? _posicaoAtual;

  /// Atualiza o centro das camadas de previsao (a posicao do caminhao).
  void definirPosicao(LatLng pos) {
    _posicaoAtual = pos;
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
        opacidade: 0.6,
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
      await _aplicarGrade(c, 'precipitacao', _precipitacao);
      await _aplicarGrade(c, 'vento', _vento);
      await _aplicarGrade(c, 'temperatura', _temperatura);
      await _aplicarGrade(c, 'nuvens', _nuvensPrevistas);
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

  /// Desenha uma grade de previsao como circulos coloridos.
  Future<void> _aplicarGrade(
    ml.MapLibreMapController c,
    String camada,
    bool ativo,
  ) async {
    final sourceId = 'grade_${camada}_fonte';
    final layerId = 'grade_${camada}_camada';
    try {
      await c.removeLayer(layerId);
    } catch (_) {}
    try {
      await c.removeSource(sourceId);
    } catch (_) {}

    if (!ativo) return;
    final pontos = _grades[camada] ?? const [];
    if (pontos.isEmpty) return;

    final geojson = {
      'type': 'FeatureCollection',
      'features': [
        for (final p in pontos)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [p.lon, p.lat],
            },
            'properties': {'valor': p.valor},
          },
      ],
    };

    c.addSource(sourceId, ml.GeojsonSourceProperties(data: geojson));
    c.addLayer(sourceId, layerId, ml.CircleLayerProperties(
      circleRadius: 26,
      circleColor: _corDaCamada(camada),
      circleOpacity: 0.45,
      circleStrokeWidth: 1,
      circleStrokeColor: '#FFFFFF66',
    ));
  }

  /// Cor da camada de previsao (verde = pouco, vermelho = muito).
  List<Object> _corDaCamada(String camada) {
    switch (camada) {
      case 'precipitacao':
        return [
          'interpolate',
          ['linear'],
          ['get', 'valor'],
          0, '#FFFFFF00',
          20, '#FFD54F',
          50, '#FF8A65',
          80, '#E53935',
          100, '#B71C1C',
        ];
      case 'vento':
        return [
          'interpolate',
          ['linear'],
          ['get', 'valor'],
          0, '#E1F5FE',
          20, '#81D4FA',
          40, '#29B6F6',
          60, '#1E88E5',
          90, '#0D47A1',
        ];
      case 'temperatura':
        return [
          'interpolate',
          ['linear'],
          ['get', 'valor'],
          0, '#1565C0',
          12, '#64B5F6',
          20, '#FFF176',
          28, '#FF7043',
          40, '#B71C1C',
        ];
      default:
        return [
          'interpolate',
          ['linear'],
          ['get', 'valor'],
          0, '#FFFFFF00',
          40, '#B0BEC5',
          80, '#78909C',
          100, '#37474F',
        ];
    }
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
    _animador?.cancel();
    super.dispose();
  }
}
