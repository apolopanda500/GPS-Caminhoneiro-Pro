import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'package:gps_camioneiro_pro/core/network/directions_service.dart';

enum StopStatus { pending, arrived, delivered }

class RouteStopEntry {
  final String label;
  final LatLng point;
  final String neighborhood;
  final String customer;
  final String note;
  final double radiusMeters;
  final String orderLabel;

  const RouteStopEntry({
    required this.label,
    required this.point,
    this.neighborhood = '',
    this.customer = '',
    this.note = '',
    this.radiusMeters = 120,
    this.orderLabel = '',
  });

  RouteStopEntry copyWith({
    String? label,
    LatLng? point,
    String? neighborhood,
    String? customer,
    String? note,
    double? radiusMeters,
    String? orderLabel,
  }) {
    return RouteStopEntry(
      label: label ?? this.label,
      point: point ?? this.point,
      neighborhood: neighborhood ?? this.neighborhood,
      customer: customer ?? this.customer,
      note: note ?? this.note,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      orderLabel: orderLabel ?? this.orderLabel,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'lat': point.latitude,
        'lon': point.longitude,
        'neighborhood': neighborhood,
        'customer': customer,
        'note': note,
        'radiusMeters': radiusMeters,
      };

  factory RouteStopEntry.fromJson(Map<String, dynamic> j) {
    return RouteStopEntry(
      label: (j['label'] ?? '').toString(),
      point: LatLng(
        (j['lat'] as num?)?.toDouble() ?? 0,
        (j['lon'] as num?)?.toDouble() ?? 0,
      ),
      neighborhood: (j['neighborhood'] ?? '').toString(),
      customer: (j['customer'] ?? '').toString(),
      note: (j['note'] ?? '').toString(),
      radiusMeters: (j['radiusMeters'] as num?)?.toDouble() ?? 120,
    );
  }
}

/// Planejamento e validação de entregas por parada (clientes numerados).
class RouteProvider extends ChangeNotifier {
  static const Distance _distance = Distance();

  final DirectionsService _service;
  final List<RouteStopEntry> _stops = [];
  final Map<int, StopStatus> _status = {};
  final Map<int, DateTime> _arrivedAt = {};

  RouteResult? _result;
  bool _loading = false;
  String? _error;
  int _lastCompletedCount = 0;
  List<List<double>>? _area;
  String? _areaLabel;

  RouteProvider({DirectionsService? service})
      : _service = service ?? DirectionsService();

  List<RouteStopEntry> get stops => List.unmodifiable(_stops);
  RouteResult? get result => _result;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasRoute => _result != null;

  StopStatus statusOf(int index) => _status[index] ?? StopStatus.pending;

  int get totalStops => _stops.length;

  int get deliveredCount => List.generate(_stops.length, (i) => i)
      .where((i) => statusOf(i) == StopStatus.delivered)
      .length;

  int get arrivedCount => List.generate(_stops.length, (i) => i)
      .where((i) => statusOf(i) == StopStatus.arrived)
      .length;

  int get pendingCount => totalStops - deliveredCount;

  bool get allDelivered => _stops.isNotEmpty && deliveredCount == _stops.length;

  List<List<double>>? get highlightedArea => _area;
  String? get highlightedAreaLabel => _areaLabel;

  void setHighlightedArea(List<List<double>>? ring, {String? label}) {
    _area = ring;
    _areaLabel = label;
    notifyListeners();
  }

  void clearHighlightedArea() {
    _area = null;
    _areaLabel = null;
    notifyListeners();
  }

  int? get nextStopIndex {
    for (var i = 0; i < _stops.length; i++) {
      if (statusOf(i) != StopStatus.delivered) return i;
    }
    return null;
  }

  String get nextStopLabel {
    final i = nextStopIndex;
    if (i == null) return 'Rota concluída';
    final s = _stops[i];
    final who = s.customer.isNotEmpty ? s.customer : s.label;
    final bairro = s.neighborhood.isNotEmpty ? ' • ${s.neighborhood}' : '';
    return '${i + 1}. $who$bairro';
  }

  double get progress => totalStops == 0 ? 0 : deliveredCount / totalStops;

  void addStop(RouteStopEntry entry) {
    final withOrder = entry.copyWith(orderLabel: '${_stops.length + 1}');
    _stops.add(withOrder);
    _status[_stops.length - 1] = StopStatus.pending;
    notifyListeners();
  }

  void _renumberAndReset() {
    for (var i = 0; i < _stops.length; i++) {
      _stops[i] = _stops[i].copyWith(orderLabel: '${i + 1}');
    }
    _status.clear();
    _arrivedAt.clear();
    for (var i = 0; i < _stops.length; i++) {
      _status[i] = StopStatus.pending;
    }
  }

  void removeStopAt(int index) {
    if (index < 0 || index >= _stops.length) return;
    _stops.removeAt(index);
    _renumberAndReset();
    notifyListeners();
  }

  void move(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _stops.length) return;
    final item = _stops.removeAt(oldIndex);
    _stops.insert(newIndex.clamp(0, _stops.length), item);
    _renumberAndReset();
    notifyListeners();
  }

  void setStops(List<RouteStopEntry> entries) {
    _stops
      ..clear()
      ..addAll(entries);
    _renumberAndReset();
    notifyListeners();
  }

  void clear() {
    _stops.clear();
    _status.clear();
    _arrivedAt.clear();
    _result = null;
    _error = null;
    _lastCompletedCount = 0;
    _area = null;
    _areaLabel = null;
    notifyListeners();
  }

  void clearRoute() {
    _result = null;
    _error = null;
    notifyListeners();
  }

  void confirmDelivery(int index) {
    if (index < 0 || index >= _stops.length) return;
    if (statusOf(index) == StopStatus.delivered) return;
    _status[index] = StopStatus.delivered;
    _arrivedAt[index] = DateTime.now();
    notifyListeners();
  }

  /// Valida a posição do caminhão contra cada cliente.
  /// Retorna true quando uma entrega foi confirmada nesta chamada.
  bool updatePosition(
    LatLng position, {
    Duration dwellThreshold = const Duration(seconds: 45),
    DateTime? now,
  }) {
    if (_stops.isEmpty) return false;
    final clock = now ?? DateTime.now();
    var changed = false;
    var delivered = false;

    for (var i = 0; i < _stops.length; i++) {
      if (statusOf(i) == StopStatus.delivered) continue;
      final stop = _stops[i];
      final d = _distance.as(LengthUnit.Meter, position, stop.point);
      if (d <= stop.radiusMeters) {
        if (statusOf(i) == StopStatus.pending) {
          _status[i] = StopStatus.arrived;
          _arrivedAt[i] = clock;
          changed = true;
        } else {
          final since = _arrivedAt[i];
          if (since != null && clock.difference(since) >= dwellThreshold) {
            _status[i] = StopStatus.delivered;
            changed = true;
            delivered = true;
          }
        }
      } else if (statusOf(i) == StopStatus.arrived) {
        _status[i] = StopStatus.pending;
        _arrivedAt.remove(i);
        changed = true;
      }
    }

    if (changed) notifyListeners();
    return delivered;
  }

  bool consumeCompletionEvent() {
    if (!allDelivered) return false;
    if (_lastCompletedCount == deliveredCount) return false;
    _lastCompletedCount = deliveredCount;
    return true;
  }

  /// Calcula a rota partindo da posicao atual [origin] para cada parada
  /// na ordem definida. A ultima parada e o destino final.
  Future<bool> plan(
    LatLng origin, {
    double? truckHeight,
    double? truckWeight,
    double? truckWidth,
    double? truckLength,
    int? axleCount,
    bool hazmat = false,
  }) async {
    if (_stops.isEmpty) {
      _error = 'Adicione pelo menos um destino.';
      notifyListeners();
      return false;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final destination = _stops.last.point;
      final waypoints =
          _stops.sublist(0, _stops.length - 1).map((e) => e.point).toList();
      _result = await _service.route(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
        truckHeight: truckHeight,
        truckWeight: truckWeight,
        truckWidth: truckWidth,
        truckLength: truckLength,
        axleCount: axleCount,
        hazmat: hazmat,
      );
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _result = null;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String exportRouteJson() {
    return jsonEncode({
      'type': 'truck_route',
      'stops': _stops.map((s) => s.toJson()).toList(),
    });
  }

  Map<String, dynamic> exportRouteSummary() {
    return {
      'totalStops': totalStops,
      'distanceKm': _result == null ? 0 : _result!.distanceKm,
      'etaText': _result?.etaText ?? '',
      'stops': _stops.map((s) => s.toJson()).toList(),
    };
  }

  void importRouteJson(String raw) {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) return;
    final list = data['stops'];
    if (list is! List) return;
    final entries = list
        .whereType<Map>()
        .map((e) => RouteStopEntry.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.point.latitude != 0 && e.point.longitude != 0)
        .toList();
    if (entries.isEmpty) return;
    setStops(entries);
  }
}
