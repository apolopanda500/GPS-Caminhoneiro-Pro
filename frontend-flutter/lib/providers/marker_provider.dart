import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';
import 'package:gps_camioneiro_pro/data/models/map_marker_model.dart';

/// Guarda os sinais/marcadores que o motorista coloca no mapa.
/// Os sinais são TEMPORÁRIOS: expiram após [ttl] e são removidos
/// automaticamente, mantendo o mapa limpo (limpeza diária/contínua).
class MarkerProvider extends ChangeNotifier {
  final List<MapMarkerModel> _markers = [];
  final String Function()? idGenerator;
  final Duration ttl;
  Timer? _cleanupTimer;

  MarkerProvider({
    this.idGenerator,
    this.ttl = AppConstants.markerTtl,
    bool autoCleanup = true,
  }) {
    if (autoCleanup) {
      _cleanupTimer = Timer.periodic(
        AppConstants.markerCleanupInterval,
        (_) => purgeExpired(),
      );
    }
  }

  List<MapMarkerModel> get markers => List.unmodifiable(_markers);

  /// Remove os sinais expirados. Retorna quantos foram removidos.
  int purgeExpired() {
    final before = _markers.length;
    _markers.removeWhere((m) => m.isExpired(ttl));
    final removed = before - _markers.length;
    if (removed > 0) notifyListeners();
    return removed;
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }

  String _newId() =>
      (idGenerator?.call()) ?? 'mk_${DateTime.now().microsecondsSinceEpoch}';

  void addMarker(MapMarkerModel marker) {
    _markers.insert(0, marker);
    notifyListeners();
  }

  /// Cria e adiciona um marcador, retornando-o.
  MapMarkerModel place({
    required String emoji,
    required String type,
    required double latitude,
    required double longitude,
    String? label,
    String driverId = '',
  }) {
    final marker = MapMarkerModel(
      id: _newId(),
      emoji: emoji,
      type: type,
      label: label,
      latitude: latitude,
      longitude: longitude,
      driverId: driverId,
    );
    addMarker(marker);
    return marker;
  }

  void removeMarker(String id) {
    _markers.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  void setMarkers(List<MapMarkerModel> markers) {
    _markers
      ..clear()
      ..addAll(markers);
    notifyListeners();
  }

  void clear() {
    _markers.clear();
    notifyListeners();
  }

  /// Marcadores dentro de [radiusMeters] do [center] (aproximação por
  /// distância geodésica). Útil para "sinalizar só o que está perto".
  List<MapMarkerModel> withinRadius(LatLng center, double radiusMeters) {
    const distance = Distance();
    return _markers
        .where((m) =>
            distance.as(LengthUnit.Meter, center, LatLng(m.latitude, m.longitude)) <=
            radiusMeters)
        .toList();
  }

  /// Distância em metros entre dois pontos (helper exposto para UI/testes).
  static double metersBetween(LatLng a, LatLng b) {
    const distance = Distance();
    final d = distance.as(LengthUnit.Meter, a, b);
    return double.parse(d.toStringAsFixed(2));
  }

  /// Bearing aproximado (0..360) para orientar emojis no mapa.
  static double bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180 / math.pi;
    return (brng + 360) % 360;
  }
}
