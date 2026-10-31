import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:gps_camioneiro_pro/core/utils/overlay_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Camadas de mapa suportadas.
enum MapLayerMode { satellite, streets, detailed }

/// Perfis de desempenho gráfico (GPU/CPU).
enum RenderQuality { economy, balanced, ultra }

/// Modo da camera que acompanha o caminhao no mapa.
enum CameraMode {
  norte,
  navegacao,
  cabine,
}

/// Preferências avançadas do app (desempenho, mapa, GPS e hardware).
/// Persistidas em SharedPreferences para sobreviver a reinícios.
class SettingsProvider extends ChangeNotifier {
  static const _kModoLeitura = 'settings.modoLeitura';
  static const _kTargetFps = 'settings.targetFps';
  static const _kLayer = 'settings.layer';
  static const _kGpsInterval = 'settings.gpsInterval';
  static const _kHighAccuracy = 'settings.highAccuracy';
  static const _kBackgroundLocation = 'settings.backgroundLocation';
  static const _kBatterySaver = 'settings.batterySaver';
  static const _kShowTrucks = 'settings.showTrucks';
  static const _kTrafficLayer = 'settings.trafficLayer';
  static const _kRadarSound = 'settings.radarSound';
  static const _kVibration = 'settings.vibration';
  static const _kPushNotifications = 'settings.pushNotifications';
  static const _kNightMode = 'settings.nightMode';
  static const _kSoundEnabled = 'settings.soundEnabled';
  static const _kBuildings3d = 'settings.buildings3d';
  static const _kLastMapUpdate = 'settings.lastMapUpdate';
  static const _kRenderQuality = 'settings.renderQuality';
  /// Qualidade escolhida pelo usuario (salva). Quando o modo economia esta
  /// desligado, e essa qualidade que vale. Quando ligado, forcamos economy.
  static const _kSavedRenderQuality = 'settings.savedRenderQuality';
  /// FPS alvo do usuario salvo para restaurar ao sair do modo economia.
  static const _kSavedRenderQualityFps = 'settings.savedRenderQualityFps';
  static const _kTracking = 'settings.trackingEnabled';
  static const _kDayStartedAt = 'settings.dayStartedAt';
  static const _kOverlayOpacity = 'settings.overlayOpacity';
  static const _kOverlayAccent = 'settings.overlayAccent';
  static const _kRadioFab = 'settings.radioFab';
  static const _kRegiao = 'settings.regiao';
  static const _kPerfilPronto = 'settings.perfilPronto';
  static const _kCorRota = 'settings.corRota';
  static const _kCameraMode = 'settings.cameraMode';
  static const _kAutoPerfil = 'settings.autoPerfil';
  static const _kRealismo = 'settings.realismo';

  /// O mapa de ruas é recarregado a cada 12 h ou na virada do dia.
  static const Duration mapUpdateInterval = Duration(hours: 12);

  bool _modoLeitura = false;
  int _targetFps = 60;
  MapLayerMode _layer = MapLayerMode.satellite;
  int _gpsIntervalSeconds = 1;
  bool _highAccuracy = true;
  bool _backgroundLocation = true;
  bool _batterySaver = false;
  bool _showTrucks = true;
  bool _trafficLayer = true;
  bool _radarSound = true;
  bool _vibration = true;
  bool _pushNotifications = true;
  bool _nightMode = true;
  bool _soundEnabled = true;
  bool _buildings3d = true;
  DateTime? _lastMapUpdate;
  RenderQuality _renderQuality = RenderQuality.ultra;
  /// Qualidade grafica escolhida pelo usuario (persistida). So e usada quando
  /// o modo economia esta DESLIGADO. Quando ligado, forcamos RenderQuality.economy.
  RenderQuality _savedRenderQuality = RenderQuality.ultra;
  /// FPS alvo do usuario antes de entrar em economia. Usado para restaurar ao
  /// desligar o modo economia de bateria.
  int _savedTargetFps = 60;
  bool _trackingEnabled = true;
  DateTime? _dayStartedAt;
  double _overlayOpacity = 0.92;
  int _overlayAccent = 0;
  bool _radioFabEnabled = true;
  String _regiao = 'RJ';
  bool _perfilPronto = false;
  String _corRota = '#1D4ED8';
  CameraMode _cameraMode = CameraMode.norte;
  bool _autoPerfil = true;
  bool _realismo = false;
  String _aparelhoResumo = '';
  RenderQuality _detectadaQualidade = RenderQuality.balanced;
  int _detectadoFps = 60;
  bool _loaded = false;

  bool get modoLeitura => _modoLeitura;
  /// FPS efetivo: quando o modo economia esta LIGADO limitamos a 30 (durabilidade
  /// para longa estrada); quando DESLIGADO usamos o valor alvo do usuario (ate 144).
  int get targetFps => _batterySaver ? 30 : _targetFps;
  MapLayerMode get layer => _layer;
  int get gpsIntervalSeconds => _gpsIntervalSeconds;
  bool get highAccuracy => _highAccuracy;
  bool get backgroundLocation => _backgroundLocation;
  bool get batterySaver => _batterySaver;

  /// Intervalo real do GPS: com a economia de bateria ligada o app pede
  /// bem menos posicoes (o caminhoneiro economiza a bateria do celular).
  int get intervaloGpsReal {
    if (!_batterySaver) return _gpsIntervalSeconds;
    final maior = _gpsIntervalSeconds * 3;
    return maior < 8 ? 8 : maior;
  }

  /// Com a economia ligada o clima e atualizado de menos em menos.
  Duration get intervaloClima =>
      _batterySaver ? const Duration(minutes: 10) : const Duration(minutes: 2);

  bool get showTrucks => _showTrucks;
  bool get trafficLayer => _trafficLayer;
  bool get radarSound => _radarSound;
  bool get vibration => _vibration;
  bool get pushNotifications => _pushNotifications;
  bool get nightMode => _nightMode;
  /// Modo realista: escurece o mapa conforme a posicao real do sol e a luz
  /// da lua, sem trocar o estilo do mapa.
  bool get realismo => _realismo;
  bool get soundEnabled => _soundEnabled;
  bool get buildings3d => _buildings3d;
  bool get isLoaded => _loaded;
  DateTime? get lastMapUpdate => _lastMapUpdate;
  /// Qualidade grafica efetiva. Quando o modo economia esta LIGADO, forcamos
  /// RenderQuality.economy (menos FPS, sem predios 3D, sem camadas pesadas).
  /// Quando DESLIGADO, usamos a qualidade escolhida pelo usuario (_renderQuality).
  RenderQuality get renderQuality =>
      _batterySaver ? RenderQuality.economy : _renderQuality;

  /// Qualidade que o usuario escolheu (ignora o modo economia).
  RenderQuality get savedRenderQuality => _renderQuality;

  /// FPS alvo do usuario antes de entrar em economia (ignora o modo economia).
  int get savedTargetFps => _savedTargetFps;

  bool get trackingEnabled => _trackingEnabled;
  DateTime? get dayStartedAt => _dayStartedAt;

  /// Opacidade dos painéis e botões flutuantes sobre o mapa (0.3 a 1.0).
  double get overlayOpacity => _overlayOpacity;

  /// Índice da cor de destaque usada nos painéis e na barra de ferramentas.
  int get overlayAccentIndex => _overlayAccent;

  Color get overlayColor =>
      kOverlayAccents[_overlayAccent % kOverlayAccents.length];

  /// Mostra o botão flutuante do rádio sobre o mapa.
  bool get radioFabEnabled => _radioFabEnabled;

  /// Estado/regiao onde o motorista atua (ex.: RJ). A busca de enderecos
  /// prioriza essa regiao e o que esta perto da sua posicao.
  String get regiao => _regiao;

  /// True quando o perfil (motorista ou ajudante) ja foi configurado.
  bool get perfilPronto => _perfilPronto;

  /// Cor da linha da rota (hex, ex.: '#FF6D00').
  String get corRota => _corRota;

  /// Camera de acompanhamento escolhida no mapa.
  CameraMode get cameraMode => _cameraMode;

  /// Quando ligado, o app usa automaticamente o maximo que o aparelho
  /// aguenta (FPS da tela e qualidade grafica). Ao mexer no FPS ou na
  /// qualidade manualmente, isso desliga.
  bool get autoPerfil => _autoPerfil;

  /// Resumo do aparelho detectado (mostrado nas configuracoes).
  String get aparelhoResumo => _aparelhoResumo;

  Future<void> setAutoPerfil(bool value) async {
    _autoPerfil = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoPerfil, value);
  }

  /// Aplica o perfil real do aparelho (RAM, nucleos, Hz). So vale quando o
  /// modo economia esta desligado e o usuario nao fixou uma escolha manual.
  Future<void> aplicarPerfilDoAparelho({
    required int ramMb,
    required int nucleos,
    required double refreshHz,
    required bool lowRam,
    required String resumo,
    required RenderQuality qualidadeSugerida,
    required int fpsMaximo,
  }) async {
    _aparelhoResumo = resumo;
    _detectadaQualidade = qualidadeSugerida;
    _detectadoFps = supportedFps.contains(fpsMaximo) ? fpsMaximo : 60;
    if (_autoPerfil && !_batterySaver) {
      _renderQuality = qualidadeSugerida;
      _savedRenderQuality = qualidadeSugerida;
      _targetFps = supportedFps.contains(fpsMaximo) ? fpsMaximo : 60;
      _savedTargetFps = _targetFps;
      _buildings3d = qualidadeSugerida != RenderQuality.economy;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (_autoPerfil && !_batterySaver) {
      await prefs.setInt(_kRenderQuality, _renderQuality.index);
      await prefs.setInt(_kSavedRenderQuality, _savedRenderQuality.index);
      await prefs.setInt(_kTargetFps, _targetFps);
      await prefs.setInt(_kSavedRenderQualityFps, _savedTargetFps);
      await prefs.setBool(_kBuildings3d, _buildings3d);
    }
  }

  String get dayStartedLabel {
    final start = _dayStartedAt;
    if (!_trackingEnabled || start == null) return 'Expediente encerrado';
    final h = start.hour.toString().padLeft(2, '0');
    final m = start.minute.toString().padLeft(2, '0');
    return 'Em expediente desde $h:$m';
  }

  /// FPS alvo efetivo do mapa: 30 no modo economia, o FPS escolhido
  /// (60/120) com o modo normal ligado.
  int get qualityTargetFps => _batterySaver ? 30 : _targetFps;

  /// Predios 3D: o usuario escolhe; no modo economia ficam desligados.
  bool get qualityBuildings3d => !_batterySaver && _buildings3d;

  Future<void> setRenderQuality(RenderQuality value) async {
    // Quando o modo economia esta ligado, forcamos economy independente do valor.
    // Quando desligado, respeitamos a escolha do usuario.
    _autoPerfil = false;
    _renderQuality = _batterySaver ? RenderQuality.economy : value;
    _savedRenderQuality = value;
    final targetFpsForQuality = switch (value) {
      RenderQuality.economy => 30,
      RenderQuality.balanced => 60,
      RenderQuality.ultra => 120,
    };
    if (!_batterySaver) {
      _targetFps = targetFpsForQuality;
    }
    _savedTargetFps = targetFpsForQuality;
    _buildings3d = !_batterySaver && value != RenderQuality.economy;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoPerfil, false);
    await prefs.setInt(_kRenderQuality, _renderQuality.index);
    await prefs.setInt(_kSavedRenderQuality, _savedRenderQuality.index);
    await prefs.setInt(_kTargetFps, _targetFps);
    await prefs.setInt(_kSavedRenderQualityFps, _savedTargetFps);
    await prefs.setBool(_kBuildings3d, _buildings3d);
  }

  /// Liga/desliga a camada de transito em tempo real no mapa.
  Future<void> setTrafficLayer(bool value) async {
    _trafficLayer = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTrafficLayer, value);
  }

  Future<void> startDay({DateTime? now}) async {
    _trackingEnabled = true;
    _dayStartedAt = now ?? DateTime.now();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTracking, true);
    await prefs.setInt(_kDayStartedAt, _dayStartedAt!.millisecondsSinceEpoch);
  }

  Future<void> endDay() async {
    _trackingEnabled = false;
    _dayStartedAt = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTracking, false);
    await prefs.remove(_kDayStartedAt);
  }

  /// True quando passaram 12 h da última atualização ou mudou o dia.
  bool mapUpdateDue({DateTime? now}) {
    final last = _lastMapUpdate;
    if (last == null) return true;
    final current = now ?? DateTime.now();
    if (current.difference(last) >= mapUpdateInterval) return true;
    return current.year != last.year ||
        current.month != last.month ||
        current.day != last.day;
  }

  int get mapCacheVersion => _lastMapUpdate?.millisecondsSinceEpoch ?? 0;

  String get lastMapUpdateLabel {
    final last = _lastMapUpdate;
    if (last == null) return 'nunca atualizado';
    final d = last.day.toString().padLeft(2, '0');
    final m = last.month.toString().padLeft(2, '0');
    final h = last.hour.toString().padLeft(2, '0');
    final min = last.minute.toString().padLeft(2, '0');
    return '$d/$m $h:$min';
  }

  Future<void> markMapUpdated({DateTime? now}) async {
    _lastMapUpdate = now ?? DateTime.now();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastMapUpdate, _lastMapUpdate!.millisecondsSinceEpoch);
  }

  /// Alvos de FPS válidos: 30, 60 e 120.
  static const List<int> supportedFps = [30, 60, 120];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _modoLeitura = prefs.getBool(_kModoLeitura) ?? false;
    _targetFps = prefs.getInt(_kTargetFps) ?? 60;
    _savedTargetFps = prefs.getInt(_kSavedRenderQualityFps) ?? _targetFps;
    _layer = MapLayerMode.values[prefs.getInt(_kLayer) ?? 0];
    _gpsIntervalSeconds = prefs.getInt(_kGpsInterval) ?? 1;
    _highAccuracy = prefs.getBool(_kHighAccuracy) ?? true;
    _backgroundLocation = prefs.getBool(_kBackgroundLocation) ?? true;
    _batterySaver = prefs.getBool(_kBatterySaver) ?? false;
    _autoPerfil = prefs.getBool(_kAutoPerfil) ?? true;
    _showTrucks = prefs.getBool(_kShowTrucks) ?? true;
    _trafficLayer = prefs.getBool(_kTrafficLayer) ?? true;
    _radarSound = prefs.getBool(_kRadarSound) ?? true;
    _vibration = prefs.getBool(_kVibration) ?? true;
    _pushNotifications = prefs.getBool(_kPushNotifications) ?? true;
    _nightMode = prefs.getBool(_kNightMode) ?? true;
    _realismo = prefs.getBool(_kRealismo) ?? false;
    _soundEnabled = prefs.getBool(_kSoundEnabled) ?? true;
    _buildings3d = prefs.getBool(_kBuildings3d) ?? true;
    final lastUpdate = prefs.getInt(_kLastMapUpdate);
    _lastMapUpdate = lastUpdate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastUpdate);
    // Restaura a qualidade escolhida pelo usuario (nao forca mais ultra).
    final savedQuality = prefs.getInt(_kSavedRenderQuality);
    if (savedQuality != null &&
        savedQuality >= 0 &&
        savedQuality < RenderQuality.values.length) {
      _renderQuality = RenderQuality.values[savedQuality];
      _savedRenderQuality = _renderQuality;
    }
    // Se o modo economia estiver ligado, forçamos overrides de durabilidade.
    if (_batterySaver) {
      _renderQuality = RenderQuality.economy;
      _targetFps = 30;
      _buildings3d = false;
    } else {
      _targetFps = prefs.getInt(_kTargetFps) ?? 60;
      if (!supportedFps.contains(_targetFps)) _targetFps = 60;
      _buildings3d = _renderQuality != RenderQuality.economy;
    }
    _trackingEnabled = prefs.getBool(_kTracking) ?? true;
    _overlayOpacity =
        (prefs.getDouble(_kOverlayOpacity) ?? 0.92).clamp(0.3, 1.0);
    final accent = prefs.getInt(_kOverlayAccent) ?? 0;
    _overlayAccent =
        (accent >= 0 && accent < kOverlayAccents.length) ? accent : 0;
    _radioFabEnabled = prefs.getBool(_kRadioFab) ?? true;
    _regiao = prefs.getString(_kRegiao) ?? 'RJ';
    _perfilPronto = prefs.getBool(_kPerfilPronto) ?? false;
    _corRota = prefs.getString(_kCorRota) ?? '#1D4ED8';
    final cameraMode = prefs.getInt(_kCameraMode) ?? 0;
    _cameraMode = (cameraMode >= 0 && cameraMode < CameraMode.values.length)
        ? CameraMode.values[cameraMode]
        : CameraMode.norte;
    final dayStart = prefs.getInt(_kDayStartedAt);
    _dayStartedAt =
        dayStart == null ? null : DateTime.fromMillisecondsSinceEpoch(dayStart);
    if (_trackingEnabled && _dayStartedAt == null) {
      _dayStartedAt = DateTime.now();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  /// Liga/desliga o modo de leitura acessivel (textos e toques maiores).
  Future<void> setModoLeitura(bool value) async {
    _modoLeitura = value;
    notifyListeners();
    await _setBool(_kModoLeitura, value);
  }

  Future<void> setTargetFps(int value) async {
    if (!supportedFps.contains(value)) return;
    _autoPerfil = false;
    if (_batterySaver) {
      // Em economia, so anotamos a escolha para restaurar ao sair.
      _savedTargetFps = value;
    } else {
      _targetFps = value;
      _savedTargetFps = value;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoPerfil, false);
    await prefs.setInt(_kTargetFps, _batterySaver ? 30 : value);
    await prefs.setInt(_kSavedRenderQualityFps, _savedTargetFps);
  }

  Future<void> setLayer(MapLayerMode value) async {
    _layer = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLayer, value.index);
  }

  Future<void> setCameraMode(CameraMode value) async {
    _cameraMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCameraMode, value.index);
  }

  Future<void> setGpsInterval(int seconds) async {
    if (seconds < 1 || seconds > 60) return;
    _gpsIntervalSeconds = seconds;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kGpsInterval, seconds);
  }

  Future<void> setHighAccuracy(bool value) async {
    _highAccuracy = value;
    notifyListeners();
    await _setBool(_kHighAccuracy, value);
  }

  Future<void> setBackgroundLocation(bool value) async {
    _backgroundLocation = value;
    notifyListeners();
    await _setBool(_kBackgroundLocation, value);
  }

  /// Liga/desliga o modo economia de bateria.
  ///
  /// - **Ligado**: durabilidade para longa estrada. Força qualidade economy,
  ///   FPS limitado a 30, desliga predios 3D, GPS pede posicao com intervalo
  ///   maior e clima atualiza a cada 10 min.
  /// - **Desligado**: usa todo poder. Restaura FPS ate 144, qualidade escolhida
  ///   pelo usuario, predios 3D, GPS no intervalo configurado e clima a cada 2 min.
  Future<void> setBatterySaver(bool value) async {
    _batterySaver = value;
    if (value) {
      // Modo economia: salvar FPS atual antes de limitar, e aplicar overrides de durabilidade.
      _savedTargetFps = _targetFps;
      _renderQuality = RenderQuality.economy;
      _targetFps = 30;
      _buildings3d = false;
    } else {
      // Modo potencia maxima: restaurar FPS do usuario e qualidade escolhida.
      // Com o perfil automatico ligado, volta ao maximo que o aparelho aguenta.
      _targetFps = _autoPerfil ? _detectadoFps : _savedTargetFps;
      if (!supportedFps.contains(_targetFps)) _targetFps = 60;
      _renderQuality = _autoPerfil ? _detectadaQualidade : _savedRenderQuality;
      _buildings3d = _renderQuality != RenderQuality.economy;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBatterySaver, value);
    await prefs.setInt(_kTargetFps, _targetFps);
    await prefs.setBool(_kBuildings3d, _buildings3d);
    await prefs.setInt(_kRenderQuality, _renderQuality.index);
    await prefs.setInt(_kSavedRenderQuality, _savedRenderQuality.index);
  }

  Future<void> setShowTrucks(bool value) async {
    _showTrucks = value;
    notifyListeners();
    await _setBool(_kShowTrucks, value);
  }

  Future<void> setRadarSound(bool value) async {
    _radarSound = value;
    notifyListeners();
    await _setBool(_kRadarSound, value);
  }

  Future<void> setVibration(bool value) async {
    _vibration = value;
    notifyListeners();
    await _setBool(_kVibration, value);
  }

  Future<void> setPushNotifications(bool value) async {
    _pushNotifications = value;
    notifyListeners();
    await _setBool(_kPushNotifications, value);
  }

  Future<void> setNightMode(bool value) async {
    _nightMode = value;
    notifyListeners();
    await _setBool(_kNightMode, value);
  }

  Future<void> setRealismo(bool value) async {
    _realismo = value;
    notifyListeners();
    await _setBool(_kRealismo, value);
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    notifyListeners();
    await _setBool(_kSoundEnabled, value);
  }

  Future<void> setBuildings3d(bool value) async {
    _buildings3d = value;
    notifyListeners();
    await _setBool(_kBuildings3d, value);
  }

  /// Ajusta a transparência dos elementos flutuantes do mapa.
  Future<void> setOverlayOpacity(double value) async {
    _overlayOpacity = value.clamp(0.3, 1.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kOverlayOpacity, _overlayOpacity);
  }

  /// Troca a cor de destaque dos painéis e da barra de ferramentas.
  Future<void> setOverlayAccent(int index) async {
    if (index < 0 || index >= kOverlayAccents.length) return;
    _overlayAccent = index;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kOverlayAccent, index);
  }

  /// Liga ou desliga o botão flutuante do rádio no mapa.
  Future<void> setRadioFabEnabled(bool value) async {
    _radioFabEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRadioFab, value);
  }

  /// Define a cor da linha da rota.
  Future<void> setCorRota(String hex) async {
    _corRota = hex;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCorRota, hex);
  }

  /// Marca o perfil como configurado (feito uma vez por conta).
  Future<void> setPerfilConfigurado(bool value) async {
    _perfilPronto = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPerfilPronto, value);
  }

  /// Define a regiao de atuacao (usado para priorizar a busca de enderecos).
  Future<void> setRegiao(String value) async {
    final v = value.trim().toUpperCase();
    if (v.isEmpty) return;
    _regiao = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRegiao, v);
  }
}
