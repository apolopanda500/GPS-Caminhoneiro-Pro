import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gps_camioneiro_pro/data/models/trip_model.dart';

/// Histórico real de viagens do motorista, persistido localmente.
class TripProvider extends ChangeNotifier {
  static const String _kTrips = 'history.trips';
  static const int _maxTrips = 50;

  final List<TripModel> _trips = [];
  bool _loaded = false;

  List<TripModel> get trips => List.unmodifiable(_trips);
  bool get isEmpty => _trips.isEmpty;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTrips);
      _trips.clear();
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _trips.addAll(
          list.whereType<Map<String, dynamic>>().map(TripModel.fromJson),
        );
      }
      _loaded = true;
      notifyListeners();
    } catch (_) {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> addTrip(TripModel trip) async {
    _trips.insert(0, trip);
    if (_trips.length > _maxTrips) {
      _trips.removeRange(_maxTrips, _trips.length);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _trips.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_trips.map((t) => t.toJson()).toList());
      await prefs.setString(_kTrips, raw);
    } catch (_) {}
  }
}
