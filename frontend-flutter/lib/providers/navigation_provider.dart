import 'package:flutter/foundation.dart';
import 'package:gps_camioneiro_pro/data/models/truck_config.dart';

class NavigationProvider extends ChangeNotifier {
  TruckConfig? _truckConfig;
  bool _isNavigating = false;
  String _currentRoute = '';

  TruckConfig? get truckConfig => _truckConfig;
  bool get isNavigating => _isNavigating;
  String get currentRoute => _currentRoute;

  void setTruckConfig(TruckConfig config) {
    _truckConfig = config;
    notifyListeners();
  }

  void startNavigation(String routeSummary) {
    _currentRoute = routeSummary;
    _isNavigating = true;
    notifyListeners();
  }

  void stopNavigation() {
    _isNavigating = false;
    _currentRoute = '';
    notifyListeners();
  }
}
