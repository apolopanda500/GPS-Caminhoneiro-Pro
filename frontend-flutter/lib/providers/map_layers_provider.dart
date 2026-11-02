import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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

  String? _frameInfrarrojo;
  Timer? _timer;

  /// Timeline do radar (passado + previsao).
  List<FrameRadar> _frames = const [];
  int _frameAtual = 0;
  bool _animando = false;
  Timer? _animador;

  /// Pontos da grade de previsao (por camada).
  final Map<String, List<Ponto>> _grades = {};
  List<Map<String, double>> _ventoSetas = const [];

  /// Controle do que ja esta desenhado no mapa. Sem isso o provider
  /// removia/recriava as camadas a cada atualizacao do GPS: era isso que
  /// fazia as nuvens e o radar piscarem na tela.
  final Map<String, String> _rasterAplicado = {};
  final Set<String> _radarCamadasCriadas = {};
  final Map<String, String> _assinaturaGrade = {};
  String _assinaturaVento = '';
  String _radarAssinatura = '';
  bool _relevoAplicado = false;
  bool _setaVentoPronta = false;
  bool _ventoAplicado = false;

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
    if (_economia && value) return;
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
    if (_economia && value) return;
    _nuvens = value;
    notifyListeners();
    try {
      if (value) {
        await _atualizarFrames();
        if (_frameInfrarrojo == null) await _atualizarClima();
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
    if (_economia && value) return;
    _relevo = value;
    notifyListeners();
    await aplicar(_controller);
  }

  /// Liga/desliga a previsao de precipitacao (Open-Meteo).
  Future<void> setPrecipitacao(bool value) async {
    if (_precipitacao == value) return;
    if (_economia && value) return;
    _precipitacao = value;
    notifyListeners();
    if (value) await _atualizarClima();
    await aplicar(_controller);
  }

  /// Radar + chuva + nuvens + vento + temperatura em um unico controle.
  ///
  /// O relevo fica de fora: e a unica camada que continua com botao proprio.
  bool get climaCompleto =>
      _radar &&
      _precipitacao &&
      (_nuvens || _nuvensPrevistas) &&
      _vento &&
      _temperatura;

  /// Liga/desliga juntos o radar, a chuva, as nuvens, o vento e a
  /// temperatura. Centraliza num unico lugar o que antes eram cinco botoes.
  Future<void> setClimaCompleto(bool value) async {
    if (_economia && value) return;
    if (_radar == value &&
        _nuvens == value &&
        _nuvensPrevistas == value &&
        _precipitacao == value &&
        _vento == value &&
        _temperatura == value) {
      return;
    }
    _radar = value;
    _nuvens = value;
    _nuvensPrevistas = value;
    _precipitacao = value;
    _vento = value;
    _temperatura = value;
    if (!value) _pararAnimacao();
    notifyListeners();
    try {
      if (value) {
        await _atualizarFrames();
        _iniciarAnimacao();
        await _atualizarClima();
      }
      if (_controller != null) await aplicar(_controller);
    } catch (e) {
      debugPrint('Erro ao aplicar clima: $e');
    }
  }

  /// Liga/desliga o vento (Open-Meteo).
  Future<void> setVento(bool value) async {
    if (_vento == value) return;
    if (_economia && value) return;
    _vento = value;
    notifyListeners();
    if (value) await _atualizarClima();
    await aplicar(_controller);
  }

  /// Liga/desliga a temperatura (Open-Meteo).
  Future<void> setTemperatura(bool value) async {
    if (_temperatura == value) return;
    if (_economia && value) return;
    _temperatura = value;
    notifyListeners();
    if (value) await _atualizarClima();
    await aplicar(_controller);
  }

  /// Liga/desliga a cobertura de nuvens prevista (Open-Meteo).
  Future<void> setNuvensPrevistas(bool value) async {
    if (_nuvensPrevistas == value) return;
    if (_economia && value) return;
    _nuvensPrevistas = value;
    notifyListeners();
    if (value) await _atualizarClima();
    await aplicar(_controller);
  }

  bool _nuvensPrevistas = false;
  bool get nuvensPrevistas => _nuvensPrevistas;

  /// Modo economia de bateria: o mapa fica so com o essencial (rota,
  /// caminhao e avisos). Nenhuma camada de clima e ligada nesse modo.
  bool _economia = false;
  bool get economia => _economia;

  /// Liga/desliga o modo economia de bateria nas camadas do mapa.
  Future<void> setEconomia(bool value) async {
    if (_economia == value) return;
    _economia = value;
    if (value) {
      _radar = false;
      _nuvens = false;
      _nuvensPrevistas = false;
      _relevo = false;
      _precipitacao = false;
      _vento = false;
      _temperatura = false;
      _pararAnimacao();
    }
    notifyListeners();
    if (_controller != null) await aplicar(_controller);
  }

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
    final c = _controller;
    if (c == null) return;
    unawaited(_mostrarFrameRadar(c));
  }

  /// Troca o frame do radar apenas mudando a visibilidade das camadas ja
  /// criadas. Recriar a camada a cada frame (a cada 700 ms) piscava a tela.
  Future<void> _mostrarFrameRadar(ml.MapLibreMapController c) async {
    if (!_radar || _frames.isEmpty) {
      for (final id in _radarCamadasCriadas) {
        try {
          await c.setLayerVisibility(id, false);
        } catch (_) {}
      }
      return;
    }

    // O feed do radar muda a cada ~10 min: ai as camadas sao trocadas.
    final novaAssinatura = _frames.map((f) => f.path).join('|');
    if (novaAssinatura != _radarAssinatura) {
      _radarAssinatura = novaAssinatura;
      for (final id in _radarCamadasCriadas) {
        try {
          await c.removeLayer(id);
        } catch (_) {}
        try {
          await c.removeSource('${id}_fonte');
        } catch (_) {}
      }
      _radarCamadasCriadas.clear();
    }

    for (var i = 0; i < _frames.length; i++) {
      final id = 'camada_radar_$i';
      if (_radarCamadasCriadas.contains(id)) continue;
      final url = WeatherLayers.templateRadar(_frames[i].path);
      try {
        await c.addSource(
          '${id}_fonte',
          ml.RasterSourceProperties(
            tiles: [url],
            tileSize: 256,
            minzoom: 0,
            maxzoom: WeatherLayers.maxZoomTiles.toDouble(),
          ),
        );
        await c.addLayer(
          '${id}_fonte',
          id,
          const ml.RasterLayerProperties(
            rasterOpacity: [
              'interpolate',
              ['linear'],
              ['zoom'],
              11, 0.0,
              12, 0.7,
              15, 0.7,
              17, 0.4,
              18, 0.18,
            ],
            rasterResampling: 'linear',
            rasterFadeDuration: 700,
          ),
          maxzoom: WeatherLayers.maxZoomCamada,
        );
        _radarCamadasCriadas.add(id);
      } catch (_) {}
    }

    for (var i = 0; i < _frames.length; i++) {
      final id = 'camada_radar_$i';
      if (!_radarCamadasCriadas.contains(id)) continue;
      try {
        await c.setLayerVisibility(id, i == _frameAtual);
      } catch (_) {}
    }
  }

  /// Guarda o controller, agenda a atualizacao e aplica as camadas.
  Future<void> ligar(ml.MapLibreMapController controller) async {
    _controller = controller;
    // O estilo foi (re)carregado: tudo que estava desenhado sumiu do mapa.
    _rasterAplicado.clear();
    _radarCamadasCriadas.clear();
    _circulosCriados.clear();
    _emojisClima.clear();
    _assinaturaGrade.clear();
    _assinaturaVento = '';
    _radarAssinatura = '';
    _relevoAplicado = false;
    _setaVentoPronta = false;
    _ventoAplicado = false;
    _timer ??= Timer.periodic(const Duration(minutes: 10), (_) async {
      final temRaster = _radar || _nuvens;
      final temGrade = _precipitacao ||
          _vento ||
          _temperatura ||
          _nuvensPrevistas ||
          (_nuvens && _frameInfrarrojo == null);
      if (!temRaster && !temGrade) return;
      if (temRaster) await _atualizarFrames();
      if (temGrade) await _atualizarClima();
      await aplicar(_controller);
    });
    final precisaFrames = _radar || _nuvens;
    if (precisaFrames) {
      await _atualizarFrames();
    } else {
      _frames = const [];
      _frameInfrarrojo = null;
    }
    await aplicar(controller);
  }

  /// Recarrega a grade de clima (uma unica chamada para todas as camadas).
  Future<void> _atualizarClima() async {
    final pos = _posicaoAtual;
    if (pos == null) return;
    _carregando = true;
    notifyListeners();
    final grade =
        await WeatherLayers.gradeClima(pos.latitude, pos.longitude);
    _grades['precipitacao'] = grade.precipitacao;
    _grades['temperatura'] = grade.temperatura;
    _grades['nuvens'] = grade.nuvens;
    _ventoSetas = grade.vento;
    _centroDaGrade = pos;
    _carregando = false;
    notifyListeners();
  }

  Future<void> _atualizarFrames() async {
    _carregando = true;
    notifyListeners();
    final frames = await WeatherLayers.framesRadar();
    _frames = frames;
    if (frames.isNotEmpty) {
      _frameAtual = frames.length - 1;
    }
    final mapa = await WeatherLayers.framesAtuais();
    _frameInfrarrojo = mapa['infrarrojo'];
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
      if (_temperatura) 'temperatura',
      if (_nuvensPrevistas || (_nuvens && _frameInfrarrojo == null)) 'nuvens',
    ];
    if (camadasGrade.isEmpty && !_vento) return;
    final faltando = camadasGrade
            .any((camada) => (_grades[camada] ?? const []).isEmpty) ||
        (_vento && _ventoSetas.isEmpty);
    if (faltando) {
      _atualizandoGrade = true;
      unawaited(() async {
        try {
          await _atualizarClima();
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
        await _atualizarClima();
        await aplicar(_controller);
      } finally {
        _atualizandoGrade = false;
      }
    }());
  }

  /// Aplica (ou remove) as camadas no mapa.
  ///
  /// Tudo aqui e incremental: se a camada ja esta com a mesma URL/config,
  /// nada e removido nem recriado. E o que mantem nuvens e radar estaveis.
  Future<void> aplicar(ml.MapLibreMapController? controller) async {
    final c = controller;
    if (c == null) return;
    try {
      // Radar de chuva: camadas por frame (animacao sem piscar).
      await _mostrarFrameRadar(c);

      // Nuvens com tile infravermelho real (nuvens de verdade, com formato).
      await _aplicarRasterEstavel(
        c,
        id: 'camada_nuvens',
        url: _frameInfrarrojo == null
            ? null
            : WeatherLayers.templateInfrarrojo(_frameInfrarrojo!),
        ativo: _nuvens && _frameInfrarrojo != null && !_nuvensPrevistas,
        opacidade: 0.5,
        suavizar: true,
      );

      // Relevo apenas quando nao ha camada de satelite por cima.
      await _aplicarRelevo(c);

      if (_precipitacao) {
        await _aplicarCirculos(c, 'precipitacao', const Color(0xFF64B5F6));
      } else {
        await _removerCirculos(c, 'precipitacao');
      }
      if (_temperatura) {
        await _aplicarCirculos(c, 'temperatura', const Color(0xFFFF7043));
      } else {
        await _removerCirculos(c, 'temperatura');
      }
      // Sem satelite, as nuvens viram a cobertura prevista (Open-Meteo).
      if (_nuvensPrevistas || (_nuvens && _frameInfrarrojo == null)) {
        await _aplicarCirculos(c, 'nuvens', const Color(0xFFB0BEC5));
      } else {
        await _removerCirculos(c, 'nuvens');
      }
      if (_vento) {
        await _aplicarVento(c);
      } else {
        await _removerVento(c);
      }
    } catch (_) {
      // Estilo recarregado: a proxima atualizacao reaplica as camadas.
    }
  }

  /// Desenha (ou atualiza) as setas de vento.
  ///
  /// Usa uma imagem de seta de verdade (SDF) em vez do caractere "➤", que
  /// renderizava torto e em tamanho diferente em cada aparelho.
  Future<void> _aplicarVento(ml.MapLibreMapController c) async {
    const sourceId = 'vento_setas_fonte';
    const layerId = 'vento_setas_camada';
    const labelId = 'vento_velocidade_camada';
    if (_ventoSetas.isEmpty) {
      await _removerVento(c);
      return;
    }
    final features = _ventoSetas.map((e) => {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [e['lon'], e['lat']],
          },
          'properties': {
            'dir': ((e['dir'] ?? 0) + 180) % 360,
            'speed': (e['speed'] ?? 0).clamp(0, 200),
            'label': '${(e['speed'] ?? 0).round()}',
          },
        }).toList();
    final assinatura = _ventoSetas
        .map((e) => '${e['lat']},${e['lon']},${e['dir']},${e['speed']}')
        .join(';');
    if (assinatura == _assinaturaVento && _ventoAplicado) return;

    final geojson = <String, dynamic>{
      'type': 'FeatureCollection',
      'features': features,
    };

    if (_ventoAplicado) {
      try {
        await c.setGeoJsonSource(sourceId, geojson);
        _assinaturaVento = assinatura;
        return;
      } catch (_) {
        _ventoAplicado = false;
      }
    }

    if (!_setaVentoPronta) {
      try {
        await c.addImage('seta_vento', await _imagemSetaVento(), true);
        _setaVentoPronta = true;
      } catch (_) {}
    }
    if (!_setaVentoPronta) return;

    const fade = [
      'interpolate',
      ['linear'],
      ['zoom'],
      10, 0.0,
      11, 0.5,
      13, 0.6,
      14, 0.0,
    ];

    try {
      try {
        await c.removeLayer('vento_velocidade_camada');
      } catch (_) {}
      try {
        await c.removeLayer('vento_setas_camada');
      } catch (_) {}
      try {
        await c.removeSource(sourceId);
      } catch (_) {}
      await c.addGeoJsonSource(sourceId, geojson);
      await c.addSymbolLayer(
        sourceId,
        layerId,
        ml.SymbolLayerProperties(
          iconImage: 'seta_vento',
          iconColor: '#E3F2FD',
          iconOpacity: fade,
          iconRotate: ['get', 'dir'],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconSize: [
            'interpolate',
            ['linear'],
            ['get', 'speed'],
            0, 0.4,
            25, 0.7,
            60, 1.0,
            100, 1.3,
          ],
        ),
      );
      await c.addSymbolLayer(
        sourceId,
        labelId,
        ml.SymbolLayerProperties(
          textField: ['get', 'label'],
          textSize: 10,
          textColor: '#0D1B2A',
          textHaloColor: '#E3F2FD',
          textHaloWidth: 2,
          textAllowOverlap: true,
          textIgnorePlacement: true,
          textOpacity: fade,
          textOffset: [0, 1.6],
        ),
      );
      _ventoAplicado = true;
      _assinaturaVento = assinatura;
    } catch (_) {
      _ventoAplicado = false;
    }
  }

  Future<void> _removerVento(ml.MapLibreMapController c) async {
    if (!_ventoAplicado && _assinaturaVento.isEmpty) return;
    _assinaturaVento = '';
    _ventoAplicado = false;
    try {
      await c.removeLayer('vento_velocidade_camada');
    } catch (_) {}
    try {
      await c.removeLayer('vento_setas_camada');
    } catch (_) {}
    try {
      await c.removeSource('vento_setas_fonte');
    } catch (_) {}
  }

  /// Seta branca apontando para cima (norte), usada como imagem SDF.
  Future<Uint8List> _imagemSetaVento() async {
    const size = 64.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, size, size),
    );
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..isAntiAlias = true;
    final path = ui.Path()
      ..moveTo(size * 0.5, size * 0.05)
      ..lineTo(size * 0.80, size * 0.66)
      ..lineTo(size * 0.60, size * 0.58)
      ..lineTo(size * 0.60, size * 0.95)
      ..lineTo(size * 0.40, size * 0.95)
      ..lineTo(size * 0.40, size * 0.58)
      ..lineTo(size * 0.20, size * 0.66)
      ..close();
    canvas.drawPath(path, paint);
    final imagem = await recorder.endRecording().toImage(64, 64);
    final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
    imagem.dispose();
    return dados!.buffer.asUint8List();
  }

  /// Emoji usado em cada camada de previsao (imagem real, nao texto).
  static const Map<String, String> _emojiDaCamada = {
    'precipitacao': '🌧️',
    'temperatura': '🌡️',
    'nuvens': '☁️',
  };

  /// Emoji de cada tipo de ceu (nuvens com e sem chuva).
  static const Map<String, String> _emojiNuvem = {
    'limpo': '☀️',
    'poucas': '🌤️',
    'parcial': '⛅',
    'nublado': '☁️',
    'encoberto': '🌥️',
    'chuva': '🌧️',
    'chuva_forte': '🌧️',
    'tempestade': '⛈️',
    'neve': '🌨️',
  };

  /// Cor de fundo de cada tipo de ceu.
  static const Map<String, String> _corNuvem = {
    'limpo': '#FFD54F',
    'poucas': '#FFF59D',
    'parcial': '#E0E0E0',
    'nublado': '#B0BEC5',
    'encoberto': '#78909C',
    'chuva': '#4FC3F7',
    'chuva_forte': '#0288D1',
    'tempestade': '#5C6BC0',
    'neve': '#E1F5FE',
  };

  /// Cor suave do circulo de fundo de cada camada.
  static const Map<String, Color> _corDaCamada = {
    'precipitacao': Color(0xFF64B5F6),
    'temperatura': Color(0xFFFF7043),
    'nuvens': Color(0xFFCFD8DC),
  };

  /// Sufixo do valor mostrado ao lado do emoji.
  static const Map<String, String> _sufixoDaCamada = {
    'precipitacao': '%',
    'temperatura': '°',
    'nuvens': '%',
  };

  /// Imagens de emoji ja enviadas ao mapa (evita reenviar a cada render).
  final Set<String> _emojisClima = {};
  final Set<String> _circulosCriados = {};

  /// Emoji de verdade desenhado como PNG (o MapLibre nao renderiza emoji em
  /// text-layer de forma confiavel; imagem sempre aparece igual).
  Future<Uint8List> _imagemEmoji(String emoji) async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    const centro = Offset(48, 48);
    canvas.drawCircle(
      centro,
      size * 0.44,
      Paint()..color = const Color(0xE6FFFFFF),
    );
    canvas.drawCircle(
      centro,
      size * 0.44,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x44000000),
    );
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: emoji, style: const TextStyle(fontSize: size * 0.56)),
    )..layout();
    tp.paint(canvas, Offset(centro.dx - tp.width / 2, centro.dy - tp.height / 2));
    final imagem =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
    imagem.dispose();
    return dados!.buffer.asUint8List();
  }

  /// Previsao desenhada com emoji real + valor (chuva, temperatura, nuvens).
  ///
  /// Atualiza a fonte no lugar (sem recriar as camadas): nao pisca.
  Future<void> _aplicarCirculos(
    ml.MapLibreMapController c,
    String camada,
    Color cor,
  ) async {
    final sourceId = '${camada}_circulos_fonte';
    final layerId = '${camada}_circulos_camada';
    final emojiLayerId = '${camada}_emoji_camada';
    final valorLayerId = '${camada}_valor_camada';
    final pontos = _grades[camada] ?? const [];
    if (pontos.isEmpty) {
      await _removerCirculos(c, camada);
      return;
    }
    final nuvens = camada == 'nuvens';
    final assinatura = pontos
        .map((p) => '${p.lat},${p.lon},${p.valor},${p.tipo ?? ''}')
        .join(';');
    if (_assinaturaGrade[camada] == assinatura &&
        _circulosCriados.contains(camada)) {
      return;
    }

    final features = pontos.map((p) => {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [p.lon, p.lat],
          },
          'properties': {
            'v': p.valor,
            'tipo': p.tipo ?? 'nublado',
            'chuva': p.chuva,
            'valor': '${p.valor.round()}${_sufixoDaCamada[camada] ?? ''}',
          },
        }).toList();
    final geojson = <String, dynamic>{
      'type': 'FeatureCollection',
      'features': features,
    };

    // Cada tipo de ceu tem sua imagem (sol, nuvem, chuva, trovoada, neve).
    final tipos = nuvens
        ? pontos.map((p) => p.tipo ?? 'nublado').toSet()
        : <String>{};
    if (nuvens) {
      for (final tipo in tipos) {
        final nome = 'clima_nuvem_$tipo';
        if (_emojisClima.contains(nome)) continue;
        try {
          await c.addImage(
            nome,
            await _imagemEmoji(_emojiNuvem[tipo] ?? '☁️'),
          );
          _emojisClima.add(nome);
        } catch (_) {}
      }
    } else {
      final emojiNome = 'clima_$camada';
      if (!_emojisClima.contains(emojiNome)) {
        try {
          await c.addImage(
            emojiNome,
            await _imagemEmoji(_emojiDaCamada[camada] ?? '☁️'),
          );
          _emojisClima.add(emojiNome);
        } catch (_) {}
      }
    }

    const fade = [
      'interpolate',
      ['linear'],
      ['zoom'],
      10, 0.0,
      11, 0.45,
      13, 0.5,
      14, 0.0,
    ];

    try {
      await c.setGeoJsonSource(sourceId, geojson);
    } catch (_) {
      _circulosCriados.remove(camada);
    }
    if (_circulosCriados.contains(camada)) {
      _assinaturaGrade[camada] = assinatura;
      return;
    }

    final corHex = (cor == const Color(0x00000000) ? _corDaCamada[camada]! : cor)
        .toARGB32()
        .toRadixString(16)
        .substring(2);
    try {
      try {
        await c.removeLayer(valorLayerId);
      } catch (_) {}
      try {
        await c.removeLayer(emojiLayerId);
      } catch (_) {}
      try {
        await c.removeLayer(layerId);
      } catch (_) {}
      try {
        await c.removeSource(sourceId);
      } catch (_) {}
      await c.addGeoJsonSource(sourceId, geojson);
      if (nuvens) {
        await c.addCircleLayer(
          sourceId,
          layerId,
          ml.CircleLayerProperties(
            circleRadius: [
              'interpolate',
              ['linear'],
              ['get', 'v'],
              0, 10,
              50, 26,
              100, 46,
            ],
            circleColor: [
              'match',
              ['get', 'tipo'],
              'limpo', _corNuvem['limpo'],
              'poucas', _corNuvem['poucas'],
              'parcial', _corNuvem['parcial'],
              'nublado', _corNuvem['nublado'],
              'encoberto', _corNuvem['encoberto'],
              'chuva', _corNuvem['chuva'],
              'chuva_forte', _corNuvem['chuva_forte'],
              'tempestade', _corNuvem['tempestade'],
              'neve', _corNuvem['neve'],
              _corNuvem['nublado'],
            ],
            circleOpacity: [
              'interpolate',
              ['linear'],
              ['get', 'v'],
              0, 0.12,
              50, 0.3,
              100, 0.5,
            ],
            circleBlur: 3.0,
          ),
        );
        await c.addSymbolLayer(
          sourceId,
          emojiLayerId,
          ml.SymbolLayerProperties(
            iconImage: [
              'match',
              ['get', 'tipo'],
              'limpo', 'clima_nuvem_limpo',
              'poucas', 'clima_nuvem_poucas',
              'parcial', 'clima_nuvem_parcial',
              'nublado', 'clima_nuvem_nublado',
              'encoberto', 'clima_nuvem_encoberto',
              'chuva', 'clima_nuvem_chuva',
              'chuva_forte', 'clima_nuvem_chuva_forte',
              'tempestade', 'clima_nuvem_tempestade',
              'neve', 'clima_nuvem_neve',
              'clima_nuvem_nublado',
            ],
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            iconOpacity: fade,
            iconSize: [
              'interpolate',
              ['linear'],
              ['get', 'v'],
              0, 0.42,
              50, 0.56,
              100, 0.72,
            ],
          ),
        );
      } else {
        await c.addCircleLayer(
          sourceId,
          layerId,
          ml.CircleLayerProperties(
            circleRadius: 8.0,
            circleColor: '#$corHex',
            circleOpacity: [
              'interpolate',
              ['linear'],
              ['zoom'],
              10, 0.0,
              11, 0.3,
              13, 0.35,
              14, 0.0,
            ],
            circleBlur: 0.0,
          ),
        );
        await c.addSymbolLayer(
          sourceId,
          emojiLayerId,
          ml.SymbolLayerProperties(
            iconImage: 'clima_$camada',
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            iconOpacity: fade,
            iconSize: [
              'interpolate',
              ['linear'],
              ['get', 'v'],
              if (camada == 'temperatura') ...[
                0, 0.42,
                20, 0.5,
                40, 0.62,
              ] else ...[
                0, 0.38,
                50, 0.5,
                100, 0.62,
              ],
            ],
          ),
        );
      }
      await c.addSymbolLayer(
        sourceId,
        valorLayerId,
        ml.SymbolLayerProperties(
          textField: nuvens
              ? [
                  'case',
                  ['>=', ['get', 'v'], 30],
                  ['get', 'valor'],
                  '',
                ]
              : ['get', 'valor'],
          textSize: 11,
          textColor: '#0D1B2A',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2.2,
          textAllowOverlap: true,
          textIgnorePlacement: true,
          textOpacity: fade,
          textOffset: [0, 1.3],
        ),
      );
      _circulosCriados.add(camada);
      _assinaturaGrade[camada] = assinatura;
    } catch (_) {
      _circulosCriados.remove(camada);
    }
  }

  Future<void> _removerCirculos(ml.MapLibreMapController c, String camada) async {
    if (!_assinaturaGrade.containsKey(camada)) return;
    _assinaturaGrade.remove(camada);
    _circulosCriados.remove(camada);
    try {
      await c.removeLayer('${camada}_valor_camada');
    } catch (_) {}
    try {
      await c.removeLayer('${camada}_emoji_camada');
    } catch (_) {}
    try {
      await c.removeLayer('${camada}_circulos_camada');
    } catch (_) {}
    try {
      await c.removeSource('${camada}_circulos_fonte');
    } catch (_) {}
  }

  /// Camada raster unica, recriada SO quando a URL muda de verdade.
  Future<void> _aplicarRasterEstavel(
    ml.MapLibreMapController c, {
    required String id,
    required String? url,
    required bool ativo,
    required double opacidade,
    bool suavizar = false,
  }) async {
    final sourceId = '${id}_fonte';
    final layerId = '${id}_camada';

    if (!ativo || url == null || url.isEmpty) {
      if (!_rasterAplicado.containsKey(id)) return;
      _rasterAplicado.remove(id);
      try {
        await c.setLayerVisibility(layerId, false);
      } catch (_) {}
      return;
    }

    if (_rasterAplicado[id] == url) {
      try {
        await c.setLayerVisibility(layerId, true);
      } catch (_) {}
      return;
    }
    _rasterAplicado[id] = url;

    try {
      try {
        await c.removeLayer(layerId);
      } catch (_) {}
      try {
        await c.removeSource(sourceId);
      } catch (_) {}
      await c.addSource(
        sourceId,
        ml.RasterSourceProperties(
          tiles: [url],
          tileSize: 256,
          minzoom: 0,
          maxzoom: WeatherLayers.maxZoomTiles.toDouble(),
        ),
      );
      await c.addLayer(
        sourceId,
        layerId,
        ml.RasterLayerProperties(
          // Some suavemente ao aproximar: no zoom de rua/cabine o clima
          // atrapalharia enxergar a via, entao a opacidade vai a zero.
          rasterOpacity: [
            'interpolate',
            ['linear'],
            ['zoom'],
            10, 0.0,
            11, opacidade,
            13, opacidade * 0.7,
            14, 0.0,
          ],
          rasterResampling: 'linear',
          rasterFadeDuration: 900,
          rasterSaturation: suavizar ? -0.25 : null,
          rasterContrast: suavizar ? 0.08 : null,
        ),
        maxzoom: WeatherLayers.maxZoomCamada,
      );
    } catch (_) {
      _rasterAplicado.remove(id);
    }
  }

  /// Relevo real (hillshade) a partir do DEM dos AWS Terrain Tiles.
  Future<void> _aplicarRelevo(ml.MapLibreMapController c) async {
    const sourceId = 'terreno_dem_fonte';
    const layerId = 'terreno_relevo_camada';

    if (!_relevo) {
      if (!_relevoAplicado) return;
      _relevoAplicado = false;
      try {
        await c.removeLayer(layerId);
      } catch (_) {}
      try {
        await c.removeSource(sourceId);
      } catch (_) {}
      return;
    }
    if (_relevoAplicado) return;
    _relevoAplicado = true;

    try {
      await c.addSource(
        sourceId,
        const ml.RasterDemSourceProperties(
          tiles: [
            'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png',
          ],
          tileSize: 256,
          encoding: 'terrarium',
          maxzoom: 15,
        ),
      );
      await c.addLayer(
        sourceId,
        layerId,
        const ml.HillshadeLayerProperties(
          hillshadeExaggeration: 0.5,
          hillshadeShadowColor: '#1A1A1A',
        ),
      );
    } catch (_) {
      _relevoAplicado = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animador?.cancel();
    super.dispose();
  }
}
