import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gps_camioneiro_pro/data/models/alert_model.dart';

class AlertProvider extends ChangeNotifier {
  final List<AlertModel> _alerts = [];
  final Set<String> _hiddenIds = {};
  static const _kHidden = 'alerts.hidden.v1';

  List<AlertModel> get alerts =>
      List.unmodifiable(_alerts.where((a) => !_hiddenIds.contains(a.id)));

  Set<String> get hiddenIds => Set.unmodifiable(_hiddenIds);

  AlertProvider() {
    _loadHidden();
  }

  Future<SharedPreferences?> _prefsSeguro() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadHidden() async {
    final prefs = await _prefsSeguro();
    if (prefs == null) return;
    final raw = prefs.getString(_kHidden) ?? '';
    if (raw.isNotEmpty) {
      _hiddenIds.addAll(raw.split(',').where((e) => e.isNotEmpty));
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    final prefs = await _prefsSeguro();
    if (prefs == null) return;
    await prefs.setString(_kHidden, _hiddenIds.join(','));
  }

  void addAlert(AlertModel alert) {
    _hiddenIds.remove(alert.id);
    _alerts.insert(0, alert);
    _persist();
    notifyListeners();
  }

  void setAlerts(List<AlertModel> alerts) {
    _alerts.clear();
    _alerts.addAll(alerts);
    notifyListeners();
  }

  /// Esconde um sinal (some da lista e do mapa, persistido).
  void hide(String id) {
    _hiddenIds.add(id);
    _persist();
    notifyListeners();
  }

  /// Mostra de novo todos os sinalizados ocultos.
  Future<void> clearHidden() async {
    _hiddenIds.clear();
    await _persist();
    notifyListeners();
  }

  /// Remove definitivamente um sinal da lista e dos ocultos.
  void clearAlert(String id) {
    _alerts.removeWhere((a) => a.id == id);
    _hiddenIds.remove(id);
    _persist();
    notifyListeners();
  }

  void clearAlerts() {
    _alerts.clear();
    notifyListeners();
  }
}
