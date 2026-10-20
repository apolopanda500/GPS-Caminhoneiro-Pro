import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';

class GeoResult {
  final String displayName;
  final double latitude;
  final double longitude;

  GeoResult(
      {required this.displayName,
      required this.latitude,
      required this.longitude});

  factory GeoResult.fromJson(Map<String, dynamic> json) => GeoResult(
        displayName: json['display_name'] ?? '',
        latitude: double.parse(json['lat'].toString()),
        longitude: double.parse(json['lon'].toString()),
      );
}

/// Busca de endereços/ruas: Nominatim (OpenStreetMap) e, se houver chave,
/// TomTom Geocoding (resposta mais rapida e precisa).
class GeocodingService {
  static const String _endpoint = 'https://nominatim.openstreetmap.org/search';
  static const String _userAgent =
      'gps-camioneiro-pro/1.0 (contato@gpscamioneiro.app)';

  Future<List<GeoResult>> search(String query, {int limit = 5}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    if (AppConstants.trafficConfigured) {
      final tomtom = await _searchTomTom(q, limit: limit);
      if (tomtom.isNotEmpty) return tomtom;
    }

    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'q': q,
      'format': 'jsonv2',
      'limit': '$limit',
      'addressdetails': '0',
      'accept-language': 'pt-BR',
    });

    final resp = await http.get(uri, headers: {
      'User-Agent': _userAgent
    }).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];

    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as List<dynamic>;
    return data
        .whereType<Map<String, dynamic>>()
        .map(GeoResult.fromJson)
        .toList(growable: false);
  }

  /// Geocoding do TomTom (usa a mesma chave de trafego/rotas).
  Future<List<GeoResult>> _searchTomTom(String query, {int limit = 5}) async {
    try {      final uri = Uri.https('api.tomtom.com', '/search/2/geocode/${Uri.encodeComponent(query)}.json', {
        'key': AppConstants.tomTomTrafficApiKey,
        'language': 'pt-BR',
        'limit': '$limit',
      });
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return [];
      final data =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? const [];
      return results.whereType<Map<String, dynamic>>().map((r) {
        final pos = (r['position'] as Map?)?.cast<String, dynamic>() ?? {};
        final endereco = (r['address'] as Map?)?.cast<String, dynamic>() ?? {};
        final nome = [
          endereco['streetName'],
          endereco['municipalitySubdivision'],
          endereco['municipality'],
          endereco['countrySubdivision'],
        ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
        return GeoResult(
          displayName: nome.isEmpty
              ? (r['freeformAddress']?.toString() ?? query)
              : nome,
          latitude: (pos['lat'] as num?)?.toDouble() ?? 0,
          longitude: (pos['lon'] as num?)?.toDouble() ?? 0,
        );
      }).toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  /// Contorno (anel externo) de um bairro/região para destacar no mapa.
  Future<List<List<double>>?> searchPolygon(String query,
      {int limit = 1}) async {
    final q = query.trim();
    if (q.isEmpty) return null;

    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'q': q,
      'format': 'jsonv2',
      'limit': '$limit',
      'polygon_geojson': '1',
      'accept-language': 'pt-BR',
    });

    final resp = await http.get(uri, headers: {
      'User-Agent': _userAgent
    }).timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) return null;

    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as List<dynamic>;
    for (final item in data.whereType<Map<String, dynamic>>()) {
      final geometry = item['geojson'];
      if (geometry is! Map) continue;
      final ring = _outerRing(Map<String, dynamic>.from(geometry));
      if (ring != null && ring.length >= 3) return ring;
    }
    return null;
  }

  List<List<double>>? _outerRing(Map<String, dynamic> geometry) {
    final type = geometry['type']?.toString();
    final coords = geometry['coordinates'];
    if (type == 'Polygon' && coords is List && coords.isNotEmpty) {
      return _ring(coords.first);
    }
    if (type == 'MultiPolygon' && coords is List && coords.isNotEmpty) {
      final firstPolygon = coords.first;
      if (firstPolygon is List && firstPolygon.isNotEmpty) {
        return _ring(firstPolygon.first);
      }
    }
    return null;
  }

  List<List<double>>? _ring(dynamic raw) {
    if (raw is! List) return null;
    final ring = <List<double>>[];
    for (final point in raw) {
      if (point is List && point.length >= 2) {
        final lon = (point[0] as num).toDouble();
        final lat = (point[1] as num).toDouble();
        ring.add([lon, lat]);
      }
    }
    return ring.isEmpty ? null : ring;
  }
}
