import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/core/network/directions_service.dart';

enum StopStatus { pending, arrived, delivered }

/// Ãrea destacada (contorno de bairro) sobre o mapa.
class RouteAreaHighlight {
  final List<List<double>> ring;
  final String label;
  RouteAreaHighlight({required this.ring, this.label = ''});
}

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

/// Modelo de rota salvo para reuso (mesmos clientes/bairros).
class RouteTemplate {
  final String name;
  final List<RouteStopEntry> stops;
  final DateTime createdAt;

  const RouteTemplate({
    required this.name,
    required this.stops,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'stops': stops.map((s) => s.toJson()).toList(),
      };

  factory RouteTemplate.fromJson(Map<String, dynamic> j) => RouteTemplate(
        name: (j['name'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ??
            DateTime.now(),
        stops: ((j['stops'] as List<dynamic>?) ?? [])
            .whereType<Map>()
            .map((e) => RouteStopEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Cliente salvo (cadastro de quem recebe carga).
class ClientEntry {
  final String name;
  final String address;
  final String neighborhood;
  final double lat;
  final double lon;
  final String note;

  const ClientEntry({
    required this.name,
    required this.address,
    this.neighborhood = '',
    required this.lat,
    required this.lon,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'neighborhood': neighborhood,
        'lat': lat,
        'lon': lon,
        'note': note,
      };

  factory ClientEntry.fromJson(Map<String, dynamic> j) => ClientEntry(
        name: (j['name'] ?? '').toString(),
        address: (j['address'] ?? '').toString(),
        neighborhood: (j['neighborhood'] ?? '').toString(),
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lon: (j['lon'] as num?)?.toDouble() ?? 0,
        note: (j['note'] ?? '').toString(),
      );
}

/// Rota agendada para outro dia (data e hora pre-definidas).
class ScheduledRoute {
  final String id;
  final String name;
  final DateTime when;
  final List<RouteStopEntry> stops;

  const ScheduledRoute({
    required this.id,
    required this.name,
    required this.when,
    required this.stops,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'when': when.toIso8601String(),
        'stops': stops.map((s) => s.toJson()).toList(),
      };

  factory ScheduledRoute.fromJson(Map<String, dynamic> j) => ScheduledRoute(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        when: DateTime.tryParse((j['when'] ?? '').toString()) ?? DateTime.now(),
        stops: ((j['stops'] as List<dynamic>?) ?? [])
            .whereType<Map>()
            .map((e) => RouteStopEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Planejamento e validaÃ§Ã£o de entregas por parada (clientes numerados).
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
  final List<RouteAreaHighlight> _areas = [];
  bool _started = false;
  DateTime? _startedAt;
  int? _companyStopIndex;
  bool _routeFinishedNotified = false;
  bool _companyReachedNotified = false;
  List<RouteTemplate> _templates = [];
  List<ClientEntry> _clients = [];
  List<ScheduledRoute> _scheduled = [];

  static const _kTemplates = 'route.templates';
  static const _kClients = 'route.clients';
  static const _kScheduled = 'route.scheduled';

  RouteProvider({DirectionsService? service})
      : _service = service ?? DirectionsService() {
    _load();
  }

  List<ScheduledRoute> get scheduled => List.unmodifiable(_scheduled);

  /// Agenda a rota atual para uma data/hora futura.
  void scheduleRoute(String name, DateTime when) {
    final trimmed = name.trim();
    if (_stops.isEmpty) return;
    _scheduled.insert(
      0,
      ScheduledRoute(
        id: 'sch_${DateTime.now().millisecondsSinceEpoch}',
        name: trimmed.isEmpty ? 'Rota agendada' : trimmed,
        when: when,
        stops: List<RouteStopEntry>.from(_stops),
      ),
    );
    _persist();
    notifyListeners();
  }

  void removeScheduled(String id) {
    _scheduled.removeWhere((s) => s.id == id);
    _persist();
    notifyListeners();
  }

  void applyScheduled(ScheduledRoute scheduled) {
    setStops(scheduled.stops);
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templates = prefs.getString(_kTemplates);
      if (templates != null) {
        _templates = (jsonDecode(templates) as List<dynamic>)
            .whereType<Map>()
            .map((e) => RouteTemplate.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      final clients = prefs.getString(_kClients);
      if (clients != null) {
        _clients = (jsonDecode(clients) as List<dynamic>)
            .whereType<Map>()
            .map((e) => ClientEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      final scheduled = prefs.getString(_kScheduled);
      if (scheduled != null) {
        _scheduled = (jsonDecode(scheduled) as List<dynamic>)
            .whereType<Map>()
            .map((e) => ScheduledRoute.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kTemplates,
        jsonEncode(_templates.map((t) => t.toJson()).toList()),
      );
      await prefs.setString(
        _kClients,
        jsonEncode(_clients.map((c) => c.toJson()).toList()),
      );
      await prefs.setString(
        _kScheduled,
        jsonEncode(_scheduled.map((s) => s.toJson()).toList()),
      );
    } catch (_) {}
  }

  bool get started => _started;
  DateTime? get startedAt => _startedAt;
  int? get companyStopIndex => _companyStopIndex;
  bool isCompanyStop(int index) => index == _companyStopIndex;
  List<RouteTemplate> get templates => List.unmodifiable(_templates);
  List<ClientEntry> get clients => List.unmodifiable(_clients);
  bool get allStopsValidated =>
      _stops.isNotEmpty &&
      List.generate(_stops.length, (i) => i)
          .every((i) => statusOf(i) == StopStatus.delivered);

  void startRoute() {
    _started = true;
    _startedAt = DateTime.now();
    _routeFinishedNotified = false;
    _companyReachedNotified = false;
    notifyListeners();
  }

  void stopRoute() {
    _started = false;
    notifyListeners();
  }

  /// Marca a empresa como ultima parada da rota.
  void setCompanyStop({required String name, required LatLng point}) {
    if (_companyStopIndex != null && _companyStopIndex! < _stops.length) {
      _stops[_companyStopIndex!] =
          _stops[_companyStopIndex!].copyWith(label: name, point: point);
      notifyListeners();
      return;
    }
    final withOrder = RouteStopEntry(
      label: name,
      point: point,
      neighborhood: 'Empresa',
      customer: name,
      note: 'Retorno Ã  empresa',
      radiusMeters: 150,
      orderLabel: '${_stops.length + 1}',
    );
    _stops.add(withOrder);
    _status[_stops.length - 1] = StopStatus.pending;
    _companyStopIndex = _stops.length - 1;
    notifyListeners();
  }

  void removeCompanyStop() {
    final index = _companyStopIndex;
    if (index == null || index >= _stops.length) return;
    _stops.removeAt(index);
    _companyStopIndex = null;
    _renumberAndReset();
    notifyListeners();
  }

  /// Salva a rota atual como modelo reutilizavel.
  void saveTemplate(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _stops.isEmpty) return;
    _templates.removeWhere((t) => t.name.toLowerCase() == trimmed.toLowerCase());
    _templates.insert(
      0,
      RouteTemplate(
        name: trimmed,
        stops: List<RouteStopEntry>.from(_stops),
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void loadTemplate(RouteTemplate template) {
    setStops(template.stops);
  }

  void deleteTemplate(String name) {
    _templates.removeWhere((t) => t.name == name);
    notifyListeners();
  }

  void saveClient(ClientEntry client) {
    _clients.removeWhere((c) =>
        c.name.toLowerCase() == client.name.toLowerCase() &&
        (c.lat - client.lat).abs() < 0.0005);
    _clients.insert(0, client);
    notifyListeners();
  }

  void deleteClient(String name) {
    _clients.removeWhere((c) => c.name == name);
    notifyListeners();
  }

  void loadStopsFromClients(List<ClientEntry> selected) {
    setStops(selected
        .map((c) => RouteStopEntry(
              label: c.name,
              point: LatLng(c.lat, c.lon),
              neighborhood: c.neighborhood,
              customer: c.name,
              note: c.note,
            ))
        .toList());
  }

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

  List<List<double>>? get highlightedArea => _areas.isEmpty ? null : _areas.first.ring;
  String? get highlightedAreaLabel =>
      _areas.isEmpty ? null : _areas.first.label;

  List<RouteAreaHighlight> get highlightedAreas => List.unmodifiable(_areas);

  void setHighlightedArea(List<List<double>>? ring, {String? label}) {
    _areas.clear();
    if (ring != null) _areas.add(RouteAreaHighlight(ring: ring, label: label ?? ''));
    notifyListeners();
  }

  void addHighlightedArea(List<List<double>> ring, {String? label}) {
    _areas.removeWhere((a) => a.label.isNotEmpty && a.label == label);
    _areas.add(RouteAreaHighlight(ring: ring, label: label ?? ''));
    notifyListeners();
  }

  void addHighlightedAreas(List<RouteAreaHighlight> areas) {
    for (final a in areas) {
      _areas.removeWhere((old) => old.label.isNotEmpty && old.label == a.label);
      _areas.add(a);
    }
    notifyListeners();
  }

  void clearHighlightedArea() {
    _areas.clear();
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
    if (i == null) return 'Rota concluÃ­da';
    final s = _stops[i];
    final who = s.customer.isNotEmpty ? s.customer : s.label;
    final bairro = s.neighborhood.isNotEmpty ? ' â€¢ ${s.neighborhood}' : '';
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
    _areas.clear();
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

  /// Valida a posiÃ§Ã£o do caminhÃ£o contra cada cliente.
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

  /// True uma unica vez quando todas as paradas de cliente foram validadas.
  bool consumeRouteFinishedEvent() {
    if (!_started) return false;
    if (_routeFinishedNotified) return false;
    final clients = List.generate(_stops.length, (i) => i)
        .where((i) => i != _companyStopIndex)
        .toList();
    if (clients.isEmpty) return false;
    final done = clients.every((i) => statusOf(i) == StopStatus.delivered);
    if (!done) return false;
    _routeFinishedNotified = true;
    return true;
  }

  /// True uma unica vez quando o caminhÃ£o chega na empresa.
  bool consumeCompanyReachedEvent() {
    if (!_started) return false;
    if (_companyReachedNotified) return false;
    final index = _companyStopIndex;
    if (index == null) return false;
    if (statusOf(index) != StopStatus.delivered) return false;
    _companyReachedNotified = true;
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
