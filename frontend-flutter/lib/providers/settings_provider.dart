import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Camadas de mapa suportadas.
enum MapLayerMode { satellite, streets, detailed }

/// Perfis de desempenho gráfico (GPU/CPU).
enum RenderQuality { economy, balanced, ultra }

/// Preferências avançadas do app (desempenho, mapa, GPS e hardware).
/// Persistidas em SharedPreferences para sobreviver a reinícios.
class SettingsProvider extends ChangeNotifier {
  static const _kShowFps = 'settings.showFps';
  static const _kTargetFps = 'settings.targetFps';
  static const _kLayer = 'settings.layer';
  static const _kGpsInterval = 'settings.gpsInterval';
  static const _kHighAccuracy = 'settings.highAccuracy';
  static const _kBackgroundLocation = 'settings.backgroundLocation';
  static const _kBatterySaver = 'settings.batterySaver';
  static const _kShowTrucks = 'settings.showTrucks';
  static const _kRadarSound = 'settings.radarSound';
  static const _kVibration = 'settings.vibration';
  static const _kPushNotifications = 'settings.pushNotifications';
  static const _kNightMode = 'settings.nightMode';
  static const _kSoundEnabled = 'settings.soundEnabled';
  static const _kBuildings3d = 'settings.buildings3d';
  static const _kLastMapUpdate = 'settings.lastMapUpdate';
  static const _kRenderQuality = 'settings.renderQuality';
  static const _kTracking = 'settings.trackingEnabled';
  static const _kDayStartedAt = 'settings.dayStartedAt';

  /// O mapa de ruas é recarregado a cada 12 h ou na virada do dia.
  static const Duration mapUpdateInterval = Duration(hours: 12);

  bool _showFps = false;
  int _targetFps = 60;
  MapLayerMode _layer = MapLayerMode.satellite;
  int _gpsIntervalSeconds = 2;
  bool _highAccuracy = true;
  bool _backgroundLocation = true;
  bool _batterySaver = false;
  bool _showTrucks = true;
  bool _radarSound = true;
  bool _vibration = true;
  bool _pushNotifications = true;
  bool _nightMode = true;
  bool _soundEnabled = true;
  bool _buildings3d = true;
  DateTime? _lastMapUpdate;
  RenderQuality _renderQuality = RenderQuality.balanced;
  bool _trackingEnabled = true;
  DateTime? _dayStartedAt;
  bool _loaded = false;

  bool get showFps => _showFps;
  int get targetFps => _targetFps;
  MapLayerMode get layer => _layer;
  int get gpsIntervalSeconds => _gpsIntervalSeconds;
  bool get highAccuracy => _highAccuracy;
  bool get backgroundLocation => _backgroundLocation;
  bool get batterySaver => _batterySaver;
  bool get showTrucks => _showTrucks;
  bool get radarSound => _radarSound;
  bool get vibration => _vibration;
  bool get pushNotifications => _pushNotifications;
  bool get nightMode => _nightMode;
  bool get soundEnabled => _soundEnabled;
  bool get buildings3d => _buildings3d;
  bool get isLoaded => _loaded;
  DateTime? get lastMapUpdate => _lastMapUpdate;
  RenderQuality get renderQuality => _renderQuality;
  bool get trackingEnabled => _trackingEnabled;
  DateTime? get dayStartedAt => _dayStartedAt;

  String get dayStartedLabel {
    final start = _dayStartedAt;
    if (!_trackingEnabled || start == null) return 'Expediente encerrado';
    final h = start.hour.toString().padLeft(2, '0');
    final m = start.minute.toString().padLeft(2, '0');
    return 'Em expediente desde $h:$m';
  }

  int get qualityTargetFps => switch (_renderQuality) {
        RenderQuality.economy => 30,
        RenderQuality.balanced => 60,
        RenderQuality.ultra => 120,
      };

  bool get qualityBuildings3d => _renderQuality != RenderQuality.economy;

  Future<void> setRenderQuality(RenderQuality value) async {
    _renderQuality = value;
    _targetFps = qualityTargetFps;
    _buildings3d = qualityBuildings3d;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kRenderQuality, value.index);
    await prefs.setInt(_kTargetFps, _targetFps);
    await prefs.setBool(_kBuildings3d, _buildings3d);
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
    _showFps = prefs.getBool(_kShowFps) ?? false;
    _targetFps = prefs.getInt(_kTargetFps) ?? 60;
    _layer = MapLayerMode.values[prefs.getInt(_kLayer) ?? 0];
    _gpsIntervalSeconds = prefs.getInt(_kGpsInterval) ?? 2;
    _highAccuracy = prefs.getBool(_kHighAccuracy) ?? true;
    _backgroundLocation = prefs.getBool(_kBackgroundLocation) ?? true;
    _batterySaver = prefs.getBool(_kBatterySaver) ?? false;
    _showTrucks = prefs.getBool(_kShowTrucks) ?? true;
    _radarSound = prefs.getBool(_kRadarSound) ?? true;
    _vibration = prefs.getBool(_kVibration) ?? true;
    _pushNotifications = prefs.getBool(_kPushNotifications) ?? true;
    _nightMode = prefs.getBool(_kNightMode) ?? true;
    _soundEnabled = prefs.getBool(_kSoundEnabled) ?? true;
    _buildings3d = prefs.getBool(_kBuildings3d) ?? true;
    final lastUpdate = prefs.getInt(_kLastMapUpdate);
    _lastMapUpdate = lastUpdate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastUpdate);
    final quality = prefs.getInt(_kRenderQuality);
    if (quality != null &&
        quality >= 0 &&
        quality < RenderQuality.values.length) {
      _renderQuality = RenderQuality.values[quality];
    }
    _trackingEnabled = prefs.getBool(_kTracking) ?? true;
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

  Future<void> setShowFps(bool value) async {
    _showFps = value;
    notifyListeners();
    await _setBool(_kShowFps, value);
  }

  Future<void> setTargetFps(int value) async {
    if (!supportedFps.contains(value)) return;
    _targetFps = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTargetFps, value);
  }

  Future<void> setLayer(MapLayerMode value) async {
    _layer = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLayer, value.index);
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

  Future<void> setBatterySaver(bool value) async {
    _batterySaver = value;
    notifyListeners();
    await _setBool(_kBatterySaver, value);
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
}
