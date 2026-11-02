import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';
import 'package:gps_camioneiro_pro/core/rota/manobra.dart';

List<LatLng> decodificarPolyline(String encoded) {
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

Map<String, List<Manobra>> extrairManobrasGoogle(Map<String, dynamic> route) {
  final legs = (route['legs'] as List? ?? const []);
  final saida = <List<Manobra>>[];
  for (final leg0 in legs) {
    if (leg0 is! Map) continue;
    final leg = leg0.cast<String, dynamic>();
    final steps = leg['steps'] as List? ?? const [];
    final manobras = <Manobra>[];
    double acumulado = 0;
    for (final s in steps) {
      if (s is! Map) continue;
      final st = s.cast<String, dynamic>();
      final encoded = (st['polyline']?['encodedPolyline'] as String?) ?? '';
      final geo = decodificarPolyline(encoded);
      if (geo.isEmpty) continue;
      final nav = (st['navigationInstruction'] as Map?)?.cast<String, dynamic>()
          ?? const {};
      final texto = (nav['instructions'] as String?) ?? '';
      final manobra = Manobra(
        posicao: geo.first,
        tipo: normalizarManobra((nav['maneuver'] as String?) ?? 'STRAIGHT'),
        texto: texto,
        distancia: (st['distanceMeters'] as num?)?.toDouble() ?? 0,
        geometria: geo,
        acumulado: acumulado,
      );
      acumulado += manobra.distancia;
      manobras.add(manobra);
    }
    if (manobras.isNotEmpty) saida.add(manobras);
  }
  return {'manobras': saida.expand((e) => e).toList()};
}

List<List<Manobra>> extrairManobrasOsrm(Map<String, dynamic> rota) {
  final legs = rota['legs'] as List? ?? const [];
  final manobras = <Manobra>[];
  double acumulado = 0;
  for (final l in legs) {
    if (l is! Map) continue;
    final leg = l.cast<String, dynamic>();
    final steps = leg['steps'] as List? ?? const [];
    for (final s in steps) {
      if (s is! Map) continue;
      final st = s.cast<String, dynamic>();
      final geo = (st['geometry'] as Map?)?.cast<String, dynamic>();
      final coords = (geo?['coordinates'] as List?) ?? const [];
      final pontos = coords
          .whereType<List>()
          .where((c) => c.length >= 2)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      if (pontos.isEmpty) continue;
      final m = (st['maneuver'] as Map?)?.cast<String, dynamic>() ?? const {};
      var texto = ((m['modifier'] as String?) ?? m['type'] ?? '')
          .toString().replaceAll('_', ' ');
      final nomeVia = (st['name'] as String?) ?? '';
      if (nomeVia.isNotEmpty) texto += ' para $nomeVia';
      final intersec = st['intersections'] as List? ?? const [];
      var faixas = const <FaixaRota>[];
      for (final inter in intersec.reversed) {
        final lanes = ((inter is Map ? inter : const {})
            .cast<String, dynamic>()['lanes'] as List?) ?? const [];
        if (lanes.isNotEmpty) {
          faixas = [
            for (final ln in lanes)
              if (ln is Map)
                FaixaRota(
                  eValida: (ln['valid'] as bool?) ?? false,
                  indicacao: ((ln['indications'] as List?) ?? const [])
                      .join('+'),
                ),
          ];
          break;
        }
      }
      final manobra = Manobra(
        posicao: pontos.first,
        tipo: normalizarManobra(
            '${m['type'] ?? ''} ${m['modifier'] ?? ''}'),
        texto: texto,
        distancia: (st['distance'] as num?)?.toDouble() ?? 0,
        geometria: pontos,
        faixas: faixas,
        acumulado: acumulado,
      );
      acumulado += manobra.distancia;
      manobras.add(manobra);
    }
  }
  return [manobras];
}

List<List<Manobra>> extrairManobrasOrs(
    Map<String, dynamic> properties, List<LatLng> polyline) {
  final lista = properties['instructions'] as List? ?? const [];
  final wayPoints = properties['way_points'] as List? ?? const [];
  final manobras = <Manobra>[];
  double acumulado = 0;
  for (var i = 0; i < lista.length; i++) {
    final ins = (lista[i] as Map?)?.cast<String, dynamic>();
    if (ins == null) continue;
    final ini = (wayPoints[i] as num?)?.toInt() ?? 0;
    final fim = i + 1 < wayPoints.length
        ? (wayPoints[i + 1] as num?)?.toInt() ?? 0
        : polyline.length - 1;
    if (ini >= polyline.length) break;
    final fimClamp = fim.clamp(ini, polyline.length - 1);
    final geo = polyline.sublist(ini, fimClamp + 1);
    final manobra = Manobra(
      posicao: polyline[ini],
      tipo: normalizarManobra((ins['type'] as String?) ?? 'continue'),
      texto: ((ins['text'] as String?) ?? '')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .trim(),
      distancia: (ins['distance'] as num?)?.toDouble() ?? 0,
      geometria: geo,
      acumulado: acumulado,
    );
    acumulado += manobra.distancia;
    manobras.add(manobra);
  }
  return [manobras];
}

class RouteResult {
  final List<LatLng> polyline;
  final double distanceMeters;
  final double durationSeconds;
  final double staticDurationSeconds;
  final String summary;
  final String provider;
  final bool heavyVehicle;
  final List<Manobra> manobras;

  const RouteResult({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    this.staticDurationSeconds = 0,
    required this.summary,
    this.provider = 'google',
    this.heavyVehicle = false,
    this.manobras = const [],
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

/// Rotas rodoviÃ¡rias com paradas.
/// PreferÃªncia: OpenRouteService `driving-hgv` (restriÃ§Ãµes reais de caminhÃ£o).
/// Alternativa: Google Routes API com trÃ¢nsito em tempo real (sem dimensÃµes).
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
    final body = <String, dynamic>{
      'routePlanningLocations': {
        'origin': jsonDecode(_pontoTomTom(origin)),
        'destination': jsonDecode(_pontoTomTom(destination)),
        if (waypoints.isNotEmpty)
          'waypoints': {
            'type': 'MultiPoint',
            'coordinates': [
              for (final w in waypoints) [w.longitude, w.latitude],
            ],
          },
      },
      'travelMode': 'car',
      'traffic': 'live',
      'routeType': 'fast',
      'avoids': const ['ferries'],
      if (truckWeight != null)
        'vehicleWeightInKilograms': (truckWeight * 1000).round(),
    };

    final resp = await _client
        .post(
          Uri.parse(
              'https://api.tomtom.com/maps/orbis/routing/routes/calculate?apiVersion=3'),
          headers: {
            'Content-Type': 'application/json',
            'TomTom-Api-Key': AppConstants.tomTomTrafficApiKey,
            'TomTom-Api-Version': '3',
            'Attributes': 'routes',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));
    if (resp.statusCode != 200) {
      throw Exception(
          'Falha ao calcular rota no TomTom (HTTP ${resp.statusCode}).');
    }
    final data =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final rotas = data['routes'] as List<dynamic>? ?? const [];
    if (rotas.isEmpty) {
      throw Exception('Nao existe rota entre esses pontos.');
    }
    final rota = rotas.first as Map<String, dynamic>;
    final pernas = rota['legs'] as List<dynamic>? ?? const [];
    final polyline = <LatLng>[];
    for (final perna in pernas) {
      final path = (perna as Map)['path'] as Map?;
      final coords = (path?['coordinates'] as List?) ?? const [];
      for (final c in coords) {
        if (c is List && c.length >= 2) {
          polyline
              .add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
        }
      }
    }
    if (polyline.isEmpty) {
      throw Exception('TomTom nao devolveu o desenho da rota.');
    }
    final resumo = (rota['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final distance = (resumo['lengthInMeters'] as num?)?.toDouble() ?? 0;
    final duration =
        (resumo['travelDurationInSeconds'] as num?)?.toDouble() ?? 0;
    final atraso =
        (resumo['trafficDelayDurationInSeconds'] as num?)?.toDouble() ?? 0;

    return RouteResult(
      polyline: polyline,
      distanceMeters: distance,
      durationSeconds: duration,
      staticDurationSeconds: (duration - atraso).clamp(0, double.infinity),
      summary: atraso >= 60
          ? 'Rota com transito ao vivo (+${(atraso / 60).round()} min de atraso)'
          : 'Rota com transito ao vivo',
      provider: 'tomtom-orbis',
      heavyVehicle: truckWeight != null,
    );
  }

  static String _pontoTomTom(LatLng p) =>
      '{"type":"Point","coordinates":[${p.longitude},${p.latitude}]}';

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
      if (hazmat) 'hazmat': true,
    };
    final body = <String, dynamic>{
      'coordinates': [
        [origin.longitude, origin.latitude],
        for (final w in waypoints) [w.longitude, w.latitude],
        [destination.longitude, destination.latitude],
      ],
      'preference': 'recommended',
      'instructions': true,
      'instructions_format': 'text',
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
          'Falha ao calcular rota de caminhÃ£o (HTTP ${resp.statusCode}).');
    }

    final data =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? const [];
    if (features.isEmpty) {
      throw Exception('Nenhuma rota de caminhÃ£o encontrada.');
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
    final manobras =
        extrairManobrasOrs(properties, polyline).expand((e) => e).toList();

    return RouteResult(
      polyline: polyline,
      distanceMeters: distance,
      durationSeconds: duration,
      staticDurationSeconds: duration,
      summary:
          hazmat ? 'Rota HGV â€¢ cargas perigosas' : 'Rota para veÃ­culos pesados',
      provider: 'ors-hgv',
      heavyVehicle: true,
      manobras: manobras,
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
                'routes.duration,routes.staticDuration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.description,routes.legs.steps.distanceMeters,routes.legs.steps.polyline.encodedPolyline,routes.legs.steps.navigationInstruction.instructions,routes.legs.steps.navigationInstruction.maneuver',
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
    final polyline = decodificarPolyline(encoded);

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
      manobras:
          extrairManobrasGoogle(route0)['manobras'] ?? const [],
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
      '?overview=full&geometries=geojson&steps=true',
    );
    final resp = await _client.get(uri).timeout(const Duration(seconds: 20));
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
    final manobras = extrairManobrasOsrm(rota).expand((e) => e).toList();
    return RouteResult(
      polyline: polyline,
      distanceMeters: distance,
      durationSeconds: duration,
      staticDurationSeconds: duration,
      summary: 'Rota de carro (OSRM)',
      provider: 'osrm',
      heavyVehicle: false,
      manobras: manobras,
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
        return 'NÃ£o existe rota entre esses pontos.';
      case 'REQUEST_DENIED':
        return 'Chave do Google Directions invÃ¡lida ou sem permissÃ£o.';
      case 'OVER_QUERY_LIMIT':
        return 'Limite de uso da API atingido.';
      case 'NOT_FOUND':
        return 'Um dos endereÃ§os nÃ£o foi localizado.';
      case 'INVALID_REQUEST':
        return 'Pedido de rota invÃ¡lido.';
      default:
        return 'NÃ£o foi possÃ­vel calcular a rota ($status).';
    }
  }

}

