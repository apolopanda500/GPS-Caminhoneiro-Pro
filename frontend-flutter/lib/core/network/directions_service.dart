import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';

class RouteResult {
  final List<LatLng> polyline;
  final double distanceMeters;
  final double durationSeconds;
  final double staticDurationSeconds;
  final String summary;
  final String provider;
  final bool heavyVehicle;

  const RouteResult({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    this.staticDurationSeconds = 0,
    required this.summary,
    this.provider = 'google',
    this.heavyVehicle = false,
  });

  double get distanceKm => distanceMeters / 1000;

  Duration get duration => Duration(seconds: durationSeconds.round());

  double get trafficDelaySeconds {
    final delay = durationSeconds - staticDurationSeconds;
    return delay > 0 ? delay : 0;
  }

  bool get hasTrafficDelay => trafficDelaySeconds >= 60;

  String get trafficText {
    if (!hasTrafficDelay) return 'Trânsito livre';
    final minutes = (trafficDelaySeconds / 60).round();
    return '+$minutes min de trânsito';
  }

  String get etaText {
    final d = duration;
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}min';
    return '${d.inMinutes}min';
  }
}

/// Rotas rodoviárias com paradas.
/// Preferência: OpenRouteService `driving-hgv` (restrições reais de caminhão).
/// Alternativa: Google Routes API com trânsito em tempo real (sem dimensões).
class DirectionsService {
  final http.Client _client;

  DirectionsService({http.Client? client}) : _client = client ?? http.Client();

  Future<RouteResult> route({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    double? truckHeight,
    double? truckWeight,
    double? truckWidth,
    double? truckLength,
    int? axleCount,
    bool hazmat = false,
  }) async {
    final erros = <String>[];

    // 1) OpenRouteService: rota para veiculos pesados (altura, peso, eixos).
    if (AppConstants.orsConfigured) {
      try {
        return await _routeHgv(
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
      } catch (e) {
        erros.add(e.toString());
      }
    }

    // 2) TomTom: rota de caminhao COM transito ao vivo.
    if (AppConstants.trafficConfigured) {
      try {
        return await _routeTomTom(
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
      } catch (e) {
        erros.add(e.toString());
      }
    }

    // 3) Google Routes (trafego em tempo real).
    if (AppConstants.directionsConfigured) {
      try {
        return await _routeGoogle(
            origin: origin, destination: destination, waypoints: waypoints);
      } catch (e) {
        erros.add(e.toString());
      }
    }

    // 4) OSRM publico (sem chave): garantia que sempre da para calcular.
    try {
      return await _routeOsrm(
          origin: origin, destination: destination, waypoints: waypoints);
    } catch (e) {
      erros.add(e.toString());
    }

    throw Exception(
        'Nao foi possivel calcular a rota. ${erros.isEmpty ? '' : erros.join(' | ')}');
  }

  /// TomTom Routing: perfil de caminhao e transito ao vivo (eta real).
  Future<RouteResult> _routeTomTom({
    required LatLng origin,
    required LatLng destination,
    required List<LatLng> waypoints,
    double? truckHeight,
    double? truckWeight,
    double? truckWidth,
    double? truckLength,
    int? axleCount,
    required bool hazmat,
  }) async {
    final locais = [
      '${origin.longitude},${origin.latitude}',
      for (final w in waypoints) '${w.longitude},${w.latitude}',
      '${destination.longitude},${destination.latitude}',
    ].join('|');

    final params = <String, String>{
      'key': AppConstants.tomTomTrafficApiKey,
      'travelMode': 'TRUCK',
      'traffic': 'true',
      'language': 'pt-BR',
      'computeTravelTimeForAll': 'true',
      if (truckHeight != null) 'vehicleHeight': truckHeight.toString(),
      if (truckWeight != null) 'vehicleWeight': truckWeight.toString(),
      if (truckWidth != null) 'vehicleWidth': truckWidth.toString(),
      if (truckLength != null) 'vehicleLength': truckLength.toString(),
      if (axleCount != null) 'axleCount': axleCount.toString(),
    };

    final uri = Uri.https('api.tomtom.com', '/routing/1/calculateRoute',
        params..['locations'] = locais);

    final resp =
        await _client.get(uri).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw Exception('Falha ao calcular rota no TomTom (HTTP ${resp.statusCode}).');
    }
    final data =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final rotas = data['routes'] as List<dynamic>? ?? const [];
    if (rotas.isEmpty) {
      throw Exception('Nao existe rota entre esses pontos.');
    }
    final rota = rotas.first as Map<String, dynamic>;
    final pernas = rota['legs'] as List<dynamic>? ?? const [];
    final pontos = <String>[];
    for (final perna in pernas) {
      final p = (perna as Map)['points'] as String? ?? '';
      pontos.add(p);
    }
    final polyline = _decodeTomTom(pontos.join(''));
    final resumo = (rota['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final distance = (resumo['lengthInMeters'] as num?)?.toDouble() ?? 0;
    final duration = (resumo['travelTimeInSeconds'] as num?)?.toDouble() ?? 0;
    final durationSemTrafego =
        (resumo['noTrafficTravelTimeInSeconds'] as num?)?.toDouble() ?? duration;

    return RouteResult(
      polyline: polyline,
      distanceMeters: distance,
      durationSeconds: duration,
      staticDurationSeconds: durationSemTrafego,
      summary: hazmat
          ? 'Rota de caminhao com transito ao vivo (cargas perigosas)'
          : 'Rota de caminhao com transito ao vivo',
      provider: 'tomtom-truck',
      heavyVehicle: true,
    );
  }

  /// Polilinha do TomTom (formato proprio, base64 com ponto de 5 decimais).
  static List<LatLng> _decodeTomTom(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    while (index < encoded.length) {
      final lat = _decodeTomTomValue(encoded, index);
      index += 6;
      if (index > encoded.length) break;
      final lon = _decodeTomTomValue(encoded, index);
      index += 6;
      points.add(LatLng(lat, lon));
    }
    return points;
  }

  static double _decodeTomTomValue(String encoded, int index) {
    var value = 0;
    var shift = 0;
    var i = index;
    while (i < encoded.length) {
      final b = encoded.codeUnitAt(i++) - 63;
      value |= (b & 0x1f) << shift;
      shift += 5;
      if (b < 0x20) break;
    }
    final lat = (value >> 1) ^ -(value & 1);
    return lat / 100000.0;
  }

  Future<RouteResult> _routeHgv({
    required LatLng origin,
    required LatLng destination,
    required List<LatLng> waypoints,
    double? truckHeight,
    double? truckWeight,
    double? truckWidth,
    double? truckLength,
    int? axleCount,
    required bool hazmat,
  }) async {
    final uri = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-hgv/geojson',
    );
    final restrictions = <String, dynamic>{
      if (truckHeight != null) 'height': truckHeight,
      if (truckWeight != null) 'weight': truckWeight,
      if (truckWidth != null) 'width': truckWidth,
      if (truckLength != null) 'length': truckLength,
      if (axleCount != null) 'axleload': (truckWeight ?? 20) / axleCount,
    };
    final body = <String, dynamic>{
      'coordinates': [
        [origin.longitude, origin.latitude],
        for (final w in waypoints) [w.longitude, w.latitude],
        [destination.longitude, destination.latitude],
      ],
      'preference': 'recommended',
      'instructions': false,
      'units': 'm',
      'language': 'pt',
      'options': {
        'avoid_features': ['highways', 'fords', 'ferries'],
        if (restrictions.isNotEmpty)
          'profile_params': {'restrictions': restrictions},
      },
    };

    final resp = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': AppConstants.openRouteServiceApiKey,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode != 200) {
      throw Exception(
          'Falha ao calcular rota de caminhão (HTTP ${resp.statusCode}).');
    }

    final data =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? const [];
    if (features.isEmpty) {
      throw Exception('Nenhuma rota de caminhão encontrada.');
    }

    final feature = features.first as Map<String, dynamic>;
    final properties =
        (feature['properties'] as Map?)?.cast<String, dynamic>() ?? {};
    final summary =
        (properties['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final coords =
        (feature['geometry']?['coordinates'] as List<dynamic>?) ?? const [];

    final polyline = coords
        .whereType<List>()
        .where((c) => c.length >= 2)
        .map((c) => LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ))
        .toList();

    final distance = (summary['distance'] as num?)?.toDouble() ?? 0;
    final duration = (summary['duration'] as num?)?.toDouble() ?? 0;

    return RouteResult(
      polyline: polyline,
      distanceMeters: distance,
      durationSeconds: duration,
      staticDurationSeconds: duration,
      summary:
          hazmat ? 'Rota HGV • cargas perigosas' : 'Rota para veículos pesados',
      provider: 'ors-hgv',
      heavyVehicle: true,
    );
  }

  Future<RouteResult> _routeGoogle({
    required LatLng origin,
    required LatLng destination,
    required List<LatLng> waypoints,
  }) async {
    if (!AppConstants.directionsConfigured) {
      throw Exception(
        'Nenhum provedor de rotas configurado. Configure a chave Google ou OpenRouteService em AppConstants.',
      );
    }

    final uri =
        Uri.https('routes.googleapis.com', '/directions/v2:computeRoutes');
    final body = {
      'origin': {
        'location': {
          'latLng': {'latitude': origin.latitude, 'longitude': origin.longitude}
        }
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': destination.latitude,
            'longitude': destination.longitude
          }
        }
      },
      if (waypoints.isNotEmpty)
        'intermediates': [
          for (final w in waypoints)
            {
              'location': {
                'latLng': {'latitude': w.latitude, 'longitude': w.longitude}
              }
            },
        ],
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE_OPTIMAL',
      'routeModifiers': {'avoidFerries': true},
      'languageCode': 'pt-BR',
      'polylineQuality': 'OVERVIEW',
    };
    final resp = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': AppConstants.googleDirectionsApiKey,
            'X-Goog-FieldMask':
                'routes.duration,routes.staticDuration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.description',
            // Necessario quando a chave do Google e restrita para Android.
            if (AppConstants.androidCertSha1.isNotEmpty)
              'X-Android-Package': AppConstants.androidPackage,
            if (AppConstants.androidCertSha1.isNotEmpty)
              'X-Android-Cert': AppConstants.androidCertSha1,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw Exception('Falha ao calcular a rota (HTTP ${resp.statusCode}).');
    }

    final data =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) {
      throw Exception(_mensagemStatus(
          data['error']?['message']?.toString() ?? 'ZERO_RESULTS'));
    }

    final route0 = routes.first as Map<String, dynamic>;
    final encoded = (route0['polyline']?['encodedPolyline'] as String?) ?? '';
    final polyline = _decode(encoded);

    final distance = _parseDistance(route0['distanceMeters']);
    final duration = _parseDuration(route0['duration']);
    final staticDuration = _parseDuration(route0['staticDuration']);

    return RouteResult(
      polyline: polyline,
      distanceMeters: distance,
      durationSeconds: duration,
      staticDurationSeconds: staticDuration,
      summary: (route0['description'] as String?) ?? '',
      provider: 'google',
      heavyVehicle: false,
    );
  }

  /// OSRM publico: sem chave, sempre disponivel (rota de carro, sem
  /// restricoes de caminhao). Ultimo recurso para nunca falhar a rota.
  Future<RouteResult> _routeOsrm({
    required LatLng origin,
    required LatLng destination,
    required List<LatLng> waypoints,
  }) async {
    final pontos = [
      '${origin.longitude},${origin.latitude}',
      for (final w in waypoints) '${w.longitude},${w.latitude}',
      '${destination.longitude},${destination.latitude}',
    ].join(';');

    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$pontos'
      '?overview=full&geometries=geojson',
    );
    final resp =
        await _client.get(uri).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw Exception('Falha ao calcular rota (OSRM HTTP ${resp.statusCode}).');
    }
    final data =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final rotas = data['routes'] as List<dynamic>? ?? const [];
    if (rotas.isEmpty) {
      throw Exception('Nao existe rota entre esses pontos.');
    }
    final rota = rotas.first as Map<String, dynamic>;
    final geo = (rota['geometry'] as Map?)?.cast<String, dynamic>() ?? {};
    final coords = (geo['coordinates'] as List<dynamic>?) ?? const [];
    final polyline = coords
        .whereType<List>()
        .where((c) => c.length >= 2)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    final distance = (rota['distance'] as num?)?.toDouble() ?? 0;
    final duration = (rota['duration'] as num?)?.toDouble() ?? 0;
    return RouteResult(
      polyline: polyline,
      distanceMeters: distance,
      durationSeconds: duration,
      staticDurationSeconds: duration,
      summary: 'Rota de carro (OSRM)',
      provider: 'osrm',
      heavyVehicle: false,
    );
  }

  double _parseDistance(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    }
    return 0;
  }

  double _parseDuration(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final m = RegExp(r'(\d+)').firstMatch(v);
      if (m != null) return double.tryParse(m.group(1)!) ?? 0;
    }
    return 0;
  }

  String _mensagemStatus(String status) {
    switch (status) {
      case 'ZERO_RESULTS':
        return 'Não existe rota entre esses pontos.';
      case 'REQUEST_DENIED':
        return 'Chave do Google Directions inválida ou sem permissão.';
      case 'OVER_QUERY_LIMIT':
        return 'Limite de uso da API atingido.';
      case 'NOT_FOUND':
        return 'Um dos endereços não foi localizado.';
      case 'INVALID_REQUEST':
        return 'Pedido de rota inválido.';
      default:
        return 'Não foi possível calcular a rota ($status).';
    }
  }

  static List<LatLng> _decode(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
