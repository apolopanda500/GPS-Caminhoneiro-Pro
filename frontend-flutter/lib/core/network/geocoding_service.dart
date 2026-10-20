import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';

class GeoResult {
  final String displayName;
  final double latitude;
  final double longitude;

  /// Distancia (em km) do ponto de referencia, quando houver.
  final double? distanceKm;

  /// Bairro / cidade / estado, quando o servico informar.
  final String? region;

  /// Estado (sigla ou nome) devolvido pelo servico, quando houver.
  final String? state;

  GeoResult(
      {required this.displayName,
      required this.latitude,
      required this.longitude,
      this.distanceKm,
      this.region,
      this.state});

  factory GeoResult.fromJson(Map<String, dynamic> json) => GeoResult(
        displayName: json['display_name'] ?? '',
        latitude: double.parse(json['lat'].toString()),
        longitude: double.parse(json['lon'].toString()),
      );
}

/// Siglas dos estados brasileiros e o nome completo usado pelos geocoders.
const Map<String, String> kEstadosBrasil = {
  'AC': 'Acre',
  'AL': 'Alagoas',
  'AP': 'Amapá',
  'AM': 'Amazonas',
  'BA': 'Bahia',
  'CE': 'Ceará',
  'DF': 'Distrito Federal',
  'ES': 'Espírito Santo',
  'GO': 'Goiás',
  'MA': 'Maranhão',
  'MT': 'Mato Grosso',
  'MS': 'Mato Grosso do Sul',
  'MG': 'Minas Gerais',
  'PA': 'Pará',
  'PB': 'Paraíba',
  'PR': 'Paraná',
  'PE': 'Pernambuco',
  'PI': 'Piauí',
  'RJ': 'Rio de Janeiro',
  'RN': 'Rio Grande do Norte',
  'RS': 'Rio Grande do Sul',
  'RO': 'Rondônia',
  'RR': 'Roraima',
  'SC': 'Santa Catarina',
  'SP': 'São Paulo',
  'SE': 'Sergipe',
  'TO': 'Tocantins',
};

/// Texto sem acentos e em minusculas, para comparar nomes de estado.
String _semAcento(String texto) {
  const mapa = {
    'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };
  final base = texto.toLowerCase();
  final buffer = StringBuffer();
  for (final r in base.runes) {
    final c = String.fromCharCode(r);
    buffer.write(mapa[c] ?? c);
  }
  return buffer.toString();
}

/// Descobre o estado a partir da sigla (RJ) ou do nome completo.
String? _estadoDoTexto(String? texto) {
  if (texto == null || texto.trim().isEmpty) return null;
  final limpo = texto.trim();
  final porSigla = kEstadosBrasil[limpo.toUpperCase()];
  if (porSigla != null) return porSigla;
  final alvo = _semAcento(limpo);
  for (final entrada in kEstadosBrasil.entries) {
    if (_semAcento(entrada.value) == alvo) return entrada.value;
  }
  return limpo;
}

/// Nome completo do estado usado na consulta (evita que o geocoder interprete
/// a sigla como outra coisa).
String _nomeDoEstado(String? texto) => _estadoDoTexto(texto) ?? '';


/// Busca de enderecos/ruas: prioriza o que esta perto de voce.
///
/// O servico usa a sua posicao como referencia (bias), limita os resultados a
/// uma regiao proxima e ordena por distancia - assim a lista traz a sua
/// cidade e os bairros vizinhos em vez de outros estados.
class GeocodingService {
  static const String _endpoint = 'https://nominatim.openstreetmap.org/search';
  static const String _userAgent =
      'gps-camioneiro-pro/1.0 (contato@gpscamioneiro.app)';

  /// Raio (em km) usado para cortar resultados muito longe.
  static const double raioPadraoKm = 120;

  /// Distancia em km entre dois pontos (formula de haversine).
  static double _distanciaKm(LatLng a, LatLng b) {
    const raioTerraKm = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return raioTerraKm * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  static double _rad(double grau) => grau * math.pi / 180.0;

  /// Ordena por distancia e corta o que estiver longe demais.
  List<GeoResult> _priorizar(
    List<GeoResult> resultados,
    LatLng? referencia,
    double raioKm,
  ) {
    if (referencia == null) return resultados;

    final comDistancia = resultados
        .map((r) => GeoResult(
              displayName: r.displayName,
              latitude: r.latitude,
              longitude: r.longitude,
              distanceKm: _distanciaKm(
                  referencia, LatLng(r.latitude, r.longitude)),
              region: r.region,
              state: r.state,
            ))
        .toList()
      ..sort((a, b) => (a.distanceKm ?? 1e9).compareTo(b.distanceKm ?? 1e9));

    final dentro = comDistancia
        .where((r) => (r.distanceKm ?? 0) <= raioKm)
        .toList();
    // Se nada estiver perto, mantem os resultados (para nao sumir com a busca).
    return dentro.isNotEmpty ? dentro : comDistancia;
  }

  Future<List<GeoResult>> search(
    String query, {
    int limit = 12,
    LatLng? near,
    String? cityName,
    String? stateName,
    double raioKm = raioPadraoKm,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    // Cada motor ganha uma cota igual: assim os 4 contribuem com a lista
    // (sem isso o primeiro ja estoura o limite e os outros nem rodam).
    final cotaPorMotor = (limit / 2).ceil().clamp(4, limit);

    final engines = <Future<List<GeoResult>> Function()>[
      () => _searchTomTom(q,
          limit: cotaPorMotor, near: near, cityName: cityName, stateName: stateName),
      () => _searchPhoton(q,
          limit: cotaPorMotor, near: near, stateName: stateName),
      () => _searchArcGis(q,
          limit: cotaPorMotor, near: near, stateName: stateName),
      () => _searchNominatim(q,
          limit: cotaPorMotor, near: near, cityName: cityName, stateName: stateName),
    ];

    var lista = <GeoResult>[];
    for (final engine in engines) {
      try {
        final parte = await engine();
        if (parte.isNotEmpty) {
          lista = [...lista, ...parte];
        }
      } catch (_) {
        // Motor indisponivel: tenta o proximo.
      }
    }

    final semDuplicado = _removerDuplicados(lista);
    final priorizados = _priorizar(semDuplicado, near, raioKm);
    return _filtrarPorEstado(priorizados, stateName, limit);
  }

  /// Tira resultados repetidos (mesmo lugar devolvido por motores diferentes).
  List<GeoResult> _removerDuplicados(List<GeoResult> resultados) {
    final vistos = <String>{};
    final saida = <GeoResult>[];
    for (final r in resultados) {
      final chave =
          '${r.displayName.toLowerCase()}|${r.latitude.toStringAsFixed(4)}|'
          '${r.longitude.toStringAsFixed(4)}';
      final chavePonto =
          '${r.latitude.toStringAsFixed(4)}|${r.longitude.toStringAsFixed(4)}';
      if (vistos.contains(chave) || vistos.contains(chavePonto)) continue;
      vistos.add(chave);
      vistos.add(chavePonto);
      saida.add(r);
    }
    return saida;
  }

  /// Mantem **so** os resultados do estado escolhido (ex.: RJ).
  ///
  /// Os geocoders devolvem o nome completo do estado ("Rio de Janeiro"), e a
  /// regiao escolhida no app costuma ser a sigla ("RJ"): por isso a
  /// comparacao aceita as duas formas. Resultado de outro estado e
  /// descartado - nao ha mistura de estados na lista.
  List<GeoResult> _filtrarPorEstado(
    List<GeoResult> resultados,
    String? stateName,
    int limit,
  ) {
    if (stateName == null || stateName.trim().isEmpty) {
      return resultados.take(limit).toList();
    }
    final estado = _estadoDoTexto(stateName);
    if (estado == null) return resultados.take(limit).toList();

    final alvo = _semAcento(estado);
    String? sigla;
    for (final entrada in kEstadosBrasil.entries) {
      if (_semAcento(entrada.value) == alvo) {
        sigla = entrada.key;
        break;
      }
    }

    bool pertence(GeoResult r) {
      final alvos = <String>[alvo];
      if (sigla != null) alvos.add(_semAcento(sigla));
      for (final parte in [r.state, r.region]) {
        if (parte == null || parte.isEmpty) continue;
        final normal = _semAcento(parte);
        for (final a in alvos) {
          if (normal.contains(a)) return true;
        }
      }
      return false;
    }

    return resultados.where(pertence).take(limit).toList();
  }

  /// Photon (Komoot): busca rapida e sem chave, otima para ruas.
  Future<List<GeoResult>> _searchPhoton(
    String query, {
    int limit = 12,
    LatLng? near,
    String? stateName,
  }) async {
    try {
      final estado = _nomeDoEstado(stateName);
      final termos = <String>[
        query,
        if (estado.isNotEmpty) estado,
      ].join(', ');
      // O Photon rejeita parametros desconhecidos (HTTP 400); os aceitos sao
      // q, limit, lang, lat, lon, bbox, countrycode, entre outros.
      final params = <String, String>{
        'q': termos,
        'limit': '$limit',
        'lang': 'default',
        'countrycode': 'BR',
      };
      if (near != null) {
        params['lat'] = '${near.latitude}';
        params['lon'] = '${near.longitude}';
        params['location_bias_scale'] = '0.5';
      }
      final uri = Uri.https('photon.komoot.io', '/api', params);
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return [];
      final data =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? const [];
      return features.whereType<Map<String, dynamic>>().map((f) {
        final props = (f['properties'] as Map?)?.cast<String, dynamic>() ?? {};
        final coords = (f['geometry']?['coordinates'] as List?) ?? const [];
        final bairro = props['district']?.toString() ?? '';
        final cidade = props['city']?.toString() ??
            props['county']?.toString() ??
            props['state_district']?.toString() ??
            '';
        final estadoResultado = props['state']?.toString() ?? '';
        final nome = [
          props['name'],
          props['street'],
          bairro,
          cidade,
          estadoResultado,
        ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
        return GeoResult(
          displayName: nome.isEmpty ? query : nome,
          latitude: coords.length >= 2 ? (coords[1] as num).toDouble() : 0,
          longitude: coords.isNotEmpty ? (coords[0] as num).toDouble() : 0,
          region: [bairro, cidade, estadoResultado]
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .join(' - '),
          state: estadoResultado.isEmpty ? null : estadoResultado,
        );
      }).toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  /// ArcGIS World Geocoding: sem chave e boa cobertura de municipios.
  Future<List<GeoResult>> _searchArcGis(
    String query, {
    int limit = 12,
    LatLng? near,
    String? stateName,
  }) async {
    try {
      final estado = _nomeDoEstado(stateName);
      final termos = <String>[
        query,
        if (estado.isNotEmpty) estado,
      ].join(', ');
      final params = <String, String>{
        'f': 'json',
        'singleLine': termos,
        'maxLocations': '$limit',
        'outFields':
            'Match_addr,Addr_type,City,Region,RegionAbbr,Neighborhood,Postal',
        'countryCode': 'BRA',
      };
      if (near != null) {
        params['location'] = '${near.longitude},${near.latitude}';
        params['distance'] = '100';
      }
      // O host geocode-api exige token; o geocode.arcgis.com aceita anonimo.
      final uri = Uri.https(
        'geocode.arcgis.com',
        '/arcgis/rest/services/World/GeocodeServer/findAddressCandidates',
        params,
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return [];
      final data =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final candidatos = data['candidates'] as List<dynamic>? ?? const [];
      return candidatos.whereType<Map<String, dynamic>>().map((c) {
        final loc = (c['location'] as Map?)?.cast<String, dynamic>() ?? {};
        final attrs = (c['attributes'] as Map?)?.cast<String, dynamic>() ?? {};
        final cidade = attrs['City']?.toString() ?? '';
        final estadoResultado = attrs['Region']?.toString() ?? '';
        final sigla = attrs['RegionAbbr']?.toString() ?? '';
        return GeoResult(
          displayName: attrs['Match_addr']?.toString() ?? query,
          latitude: (loc['y'] as num?)?.toDouble() ?? 0,
          longitude: (loc['x'] as num?)?.toDouble() ?? 0,
          region: [cidade, estadoResultado]
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .join(' - '),
          state: estadoResultado.isEmpty
              ? (sigla.isEmpty ? null : sigla)
              : estadoResultado,
        );
      }).toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  /// Geocoding do TomTom (usa a mesma chave de trafego/rotas).
  Future<List<GeoResult>> _searchTomTom(
    String query, {
    int limit = 8,
    LatLng? near,
    String? cityName,
    String? stateName,
  }) async {
    try {
      // Reforca a consulta com a cidade/estado para o servico nao trazer
      // homonimos de outros estados.
      final estado = _nomeDoEstado(stateName);
      final termos = <String>[
        query,
        if (cityName != null && cityName.isNotEmpty) cityName,
        if (estado.isNotEmpty) estado,
        'Brasil',
      ].join(', ');
      final uri = Uri.https(
        'api.tomtom.com',
        '/search/2/geocode/${Uri.encodeComponent(termos)}.json',
        {
          'key': AppConstants.tomTomTrafficApiKey,
          'language': 'pt-BR',
          'countrySet': 'BR',
          'limit': '$limit',
          if (near != null) 'lat': '${near.latitude}',
          if (near != null) 'lon': '${near.longitude}',
        },
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return [];
      final data =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? const [];
      return results.whereType<Map<String, dynamic>>().map((r) {
        final pos = (r['position'] as Map?)?.cast<String, dynamic>() ?? {};
        final endereco = (r['address'] as Map?)?.cast<String, dynamic>() ?? {};
        final bairro = endereco['neighbourhood']?.toString() ?? '';
        final cidade =
            endereco['municipalitySubdivision']?.toString() ??
                endereco['municipality']?.toString() ??
                '';
        final estado = endereco['countrySubdivision']?.toString() ?? '';
        final nome = [
          endereco['streetName'],
          bairro,
          cidade,
          estado,
        ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
        return GeoResult(
          displayName: nome.isEmpty
              ? (r['freeformAddress']?.toString() ?? query)
              : nome,
          latitude: (pos['lat'] as num?)?.toDouble() ?? 0,
          longitude: (pos['lon'] as num?)?.toDouble() ?? 0,
          region: [bairro, cidade, estado]
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .join(' - '),
          state: estado.isEmpty ? null : estado,
        );
      }).toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  /// Nominatim (OpenStreetMap) com viewbox em torno de voce.
  Future<List<GeoResult>> _searchNominatim(
    String query, {
    int limit = 8,
    LatLng? near,
    String? cityName,
    String? stateName,
  }) async {
    try {
      final estado = _nomeDoEstado(stateName);
      final termos = <String>[
        query,
        if (cityName != null && cityName.isNotEmpty) cityName,
        if (estado.isNotEmpty) estado,
      ].join(', ');

      final params = <String, String>{
        'q': termos,
        'format': 'jsonv2',
        'limit': '$limit',
        'addressdetails': '1',
        'accept-language': 'pt-BR',
        'countrycodes': 'br',
      };
      if (near != null) {
        // +-0,6 grau (~66 km) de bias, sem limitar rigidamente.
        params['viewbox'] = '${near.longitude - 0.6},${near.latitude + 0.6},'
            '${near.longitude + 0.6},${near.latitude - 0.6}';
        params['bounded'] = '0';
      }

      final uri = Uri.parse(_endpoint).replace(queryParameters: params);
      final resp = await http.get(uri, headers: {
        'User-Agent': _userAgent
      }).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return [];

      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as List<dynamic>;
      return data.whereType<Map<String, dynamic>>().map((item) {
        final endereco = (item['address'] as Map?)?.cast<String, dynamic>() ?? {};
        final bairro = endereco['neighbourhood']?.toString() ??
            endereco['suburb']?.toString() ??
            '';
        final cidade = endereco['city']?.toString() ??
            endereco['town']?.toString() ??
            endereco['municipality']?.toString() ??
            endereco['village']?.toString() ??
            '';
        final estado = endereco['state']?.toString() ?? '';
        return GeoResult(
          displayName: item['display_name']?.toString() ?? query,
          latitude: double.tryParse(item['lat']?.toString() ?? '0') ?? 0,
          longitude: double.tryParse(item['lon']?.toString() ?? '0') ?? 0,
          region: [bairro, cidade, estado]
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .join(' - '),
          state: estado.isEmpty ? null : estado,
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
