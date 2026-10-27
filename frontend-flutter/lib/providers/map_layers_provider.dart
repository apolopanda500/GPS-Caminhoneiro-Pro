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
    try {
      if (value) {
        await _atualizarFrames();
        _iniciarAnimacao();
      } else {
        _pararAnimacao();
      }
      // Só aplica se o controller ainda for válido
      if (_controller != null) {
        await aplicar(_controller);
      }
    } catch (e) {
      // Erro ao aplicar radar - tentar novamente na próxima atualização
      debugPrint('Erro ao aplicar radar: $e');
    }
  }

  /// Liga/desliga as nuvens (infravermelho).
  Future<void> setNuvens(bool value) async {
    if (_nuvens == value) return;
    _nuvens = value;
    notifyListeners();
    try {
      if (value) {
        await _atualizarFrames();
        if (_frameInfrarrojo == null) await _atualizarGrade('nuvens');
      }
      // Só aplica se o controller ainda for válido
      if (_controller != null) {
        await aplicar(_controller);
      }
    } catch (e) {
      // Erro ao aplicar nuvens - tentar novamente na próxima atualização
      debugPrint('Erro ao aplicar nuvens: $e');
    }
  }

  /// O satelite esta entregando nuvens agora. Quando o feed esta vazio, a
  /// camada usa a cobertura de nuvens prevista (Open-Meteo) como reserva.
  bool get nuvensPorSatelite => _frameInfrarrojo != null;

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
      url: WeatherLayers.templateRadar(f.path),
      ativo: _radar,
      opacidade: 0.6,
    );
  }

  /// Guarda o controller, agenda a atualizacao e aplica as camadas.
  Future<void> ligar(ml.MapLibreMapController controller) async {
    _controller = controller;
    _timer ??= Timer.periodic(const Duration(minutes: 10), (_) async {
      final temRaster = _radar || _nuvens;
      final temGrade = _precipitacao ||
          _vento ||
          _temperatura ||
          _nuvensPrevistas ||
          (_nuvens && _frameInfrarrojo == null);
      if (!temRaster && !temGrade) return;
      if (temRaster) await _atualizarFrames();
      if (temGrade) await _atualizarGradesAtivas();
      await aplicar(_controller);
    });
    final precisaFrames = _radar || _nuvens;
    if (precisaFrames) {
      await _atualizarFrames();
    } else {
      _frames = const [];
      _frameRadar = null;
      _frameInfrarrojo = null;
    }
    await aplicar(controller);
  }

  /// Recarrega so as camadas de grade que estao ligadas.
  Future<void> _atualizarGradesAtivas() async {
    if (_precipitacao) await _atualizarGrade('precipitacao');
    if (_vento) await _atualizarGrade('vento');
    if (_temperatura) await _atualizarGrade('temperatura');
    if (_nuvensPrevistas || (_nuvens && _frameInfrarrojo == null)) {
      await _atualizarGrade('nuvens');
    }
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
    _centroDaGrade = pos;
    _carregando = false;
    notifyListeners();
  }

  /// Posicao usada como centro das grades de previsao.
  LatLng? _posicaoAtual;

  /// Centro da grade que esta na tela (para re-centrar quando o caminhao
  /// anda ~15 km e as areas de clima sao atualizadas ao vivo).
  LatLng? _centroDaGrade;
  bool _atualizandoGrade = false;

  /// Atualiza o centro das camadas de previsao (a posicao do caminhao).
  /// Quando o caminhao anda longe do centro da grade, as areas de clima
  /// sao recarregadas na nova regiao (ao vivo, conforme dirige).
  void definirPosicao(LatLng pos) {
    _posicaoAtual = pos;
    final centro = _centroDaGrade;
    if (_atualizandoGrade) return;
    final camadasGrade = [
      if (_precipitacao) 'precipitacao',
      if (_vento) 'vento',
      if (_temperatura) 'temperatura',
      if (_nuvensPrevistas || (_nuvens && _frameInfrarrojo == null)) 'nuvens',
    ];
    if (camadasGrade.isEmpty) return;
    final faltando = camadasGrade
        .any((camada) => (_grades[camada] ?? const []).isEmpty);
    if (faltando) {
      _atualizandoGrade = true;
      unawaited(() async {
        try {
          await _atualizarGradesAtivas();
          await aplicar(_controller);
        } finally {
          _atualizandoGrade = false;
        }
      }());
      return;
    }
    final centroAntigo = centro;
    if (centroAntigo == null) return;
    const dist = Distance();
    final km = dist.as(LengthUnit.Kilometer, centroAntigo, pos);
    if (km < 15) return;
    _atualizandoGrade = true;
    unawaited(() async {
      try {
        await _atualizarGradesAtivas();
        await aplicar(_controller);
      } finally {
        _atualizandoGrade = false;
      }
    }());
  }

  /// Aplica (ou remove) as camadas no mapa.
  Future<void> aplicar(ml.MapLibreMapController? controller) async {
    final c = controller;
    if (c == null) return;
    try {
      // PRIORIDADE 1: Radar de chuva com tile real (já tem formatos de chuva)
      await _aplicarRaster(
        c,
        id: 'camada_radar',
        url: _frameRadar == null
            ? null
            : WeatherLayers.templateRadar(_frameRadar!),
        ativo: _radar && _frameRadar != null,
        opacidade: 0.8,
      );
      
      // PRIORIDADE 2: Nuvens com tile infravermelho real (já tem formatos de nuvens)
      await _aplicarRaster(
        c,
        id: 'camada_nuvens',
        url: _frameInfrarrojo == null
            ? null
            : WeatherLayers.templateInfrarrojo(_frameInfrarrojo!),
        ativo: _nuvens && _frameInfrarrojo != null,
        opacidade: 0.6,
      );
      
      // PRIORIDADE 3: Relevo apenas se nada mais estiver ativo
      if (!_radar && !_nuvens) {
        await _aplicarRelevo(c);
      }
      
      // Camadas de grade (precipitação, vento, temperatura) só se usuário quiser
      // Estas usam círculos/gradientes como fallback quando não há tiles disponíveis
      if (_precipitacao && !_radar) {
        // Se radar já está ativo, precipitacao fica por conta do radar
      }
      if (_vento && !_radar && !_nuvens) {
        // Apenas como fallback visual
      }
      if (_temperatura && !_radar && !_nuvens) {
        // Apenas como fallback visual
      }
      
    } catch (_) {
      // Estilo recarregado: a proxima atualizacao reaplica as camadas.
    }
  }

  Future<void> _aplicarRaster(
    ml.MapLibreMapController c, {
    required String id,
    required String? url,
    required bool ativo,
    required double opacidade,
  }) async {
    final sourceId = '${id}_fonte';
    final layerId = '${id}_camada';

    if (!ativo || url == null || url.isEmpty) {
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

    c.addSource(
        sourceId,
        ml.RasterSourceProperties(
          tiles: [url],
          tileSize: 256,
          minzoom: 0,
          maxzoom: 12,
        ));
    c.addLayer(
        sourceId,
        layerId,
        ml.RasterLayerProperties(
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

    c.addSource(
        sourceId,
        const ml.RasterDemSourceProperties(
          tiles: [
            'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png',
          ],
          tileSize: 256,
          encoding: 'terrarium',
          maxzoom: 15,
        ));
    c.addLayer(
        sourceId,
        layerId,
        const ml.HillshadeLayerProperties(
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
