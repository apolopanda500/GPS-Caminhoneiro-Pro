import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class SpeedLimitInfo {
  final int? limitKmh;
  final String? streetName;
  final DateTime fetchedAt;

  const SpeedLimitInfo({this.limitKmh, this.streetName, required this.fetchedAt});

  bool get hasLimit => limitKmh != null && limitKmh! > 0;
}

/// Limite de velocidade da via atual, obtido do OpenStreetMap (Overpass API).
/// Sem chave, sem custo. Consulta no maximo 1 vez a cada 5 minutos.
class SpeedLimitService {
  static const _overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const _cacheDuration = Duration(minutes: 5);

  SpeedLimitInfo? _cache;
  Timer? _timer;

  SpeedLimitInfo? get cached => _cache;

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<SpeedLimitInfo> fetch(double lat, double lon) async {
    final now = DateTime.now();
    final cached = _cache;
    if (cached != null && now.difference(cached.fetchedAt) < _cacheDuration) {
      return cached;
    }

    final query = '''
[out:json][timeout:15];
way(around:60,${_coord(lon)},${_coord(lat)})["highway"]["maxspeed"];
out tags 12;
''';

    try {
      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        final elements = (parsed['elements'] as List<dynamic>? ?? []);
        int? best;
        String? name;
        for (final element in elements) {
          final tags = element['tags'] as Map<String, dynamic>?;
          if (tags == null) continue;
          final raw = tags['maxspeed']?.toString();
          final parsedLimit = _parseLimit(raw);
          if (parsedLimit == null) continue;
          if (best == null || parsedLimit > best) {
            best = parsedLimit;
            name = tags['name']?.toString();
          }
        }
        if (best != null) {
          _cache = SpeedLimitInfo(
            limitKmh: best,
            streetName: name,
            fetchedAt: now,
          );
          return _cache!;
        }
      }
    } catch (_) {}

    _cache = SpeedLimitInfo(fetchedAt: now);
    return _cache!;
  }

  static String _coord(double value) => value.toStringAsFixed(6);

  static int? _parseLimit(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.toLowerCase().replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    final value = int.tryParse(cleaned);
    if (value == null || value <= 0 || value > 130) return null;
    return value;
  }
}
