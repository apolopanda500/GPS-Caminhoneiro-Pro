import 'package:flutter/foundation.dart';
import 'package:gps_camioneiro_pro/data/models/alert_model.dart';

class AlertProvider extends ChangeNotifier {
  final List<AlertModel> _alerts = [];

  List<AlertModel> get alerts => List.unmodifiable(_alerts);

  void addAlert(AlertModel alert) {
    _alerts.insert(0, alert);
    notifyListeners();
  }

  void setAlerts(List<AlertModel> alerts) {
    _alerts.clear();
    _alerts.addAll(alerts);
    notifyListeners();
  }

  void clearAlerts() {
    _alerts.clear();
    notifyListeners();
  }
}
