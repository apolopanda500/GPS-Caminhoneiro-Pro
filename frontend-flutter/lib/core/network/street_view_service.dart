import 'dart:convert';

import 'package:http/http.dart' as http;

class StreetPhoto {
  final String id;
  final String thumbUrl;
  final int? capturedAt;
  final double? lat;
  final double? lon;
  final double? compassAngle;
  final String author;

  const StreetPhoto({
    required this.id,
    required this.thumbUrl,
    this.capturedAt,
    this.lat,
    this.lon,
    this.compassAngle,
    this.author = '',
  });

  DateTime? get capturedDate =>
      capturedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(capturedAt! * 1000);
}

/// Imagens de rua (street level) via Mapillary - sem chave funciona apenas
/// com token gratuito (MAPILLARY_TOKEN). Ordena sempre pela captura mais
/// recente e devolve as mais proximas do ponto tocado.
class StreetViewService {
  static const _graphUrl = 'https://graph.mapillary.com/images';

  Future<List<StreetPhoto>> photosNear({
    required double lat,
    required double lon,
    String? token,
    int limit = 12,
  }) async {
    final accessToken = token ?? '';
    if (accessToken.isEmpty) return [];

    const delta = 0.004;
    final bbox = '$lat,$lon,${lat + delta},${lon + delta}';
    final uri = Uri.parse(_graphUrl).replace(queryParameters: {
      'fields':
          'id,thumb_1024_url,captured_at,compass_angle,lat,lon,creator',
      'bbox': bbox,
      'limit': '$limit',
      'access_token': accessToken,
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as List<dynamic>;
      final photos = data
          .whereType<Map<String, dynamic>>()
          .map((json) => StreetPhoto(
                id: json['id']?.toString() ?? '',
                thumbUrl: json['thumb_1024_url']?.toString() ??
                    json['thumb_2048_url']?.toString() ??
                    '',
                capturedAt: json['captured_at'] is int
                    ? json['captured_at'] as int
                    : null,
                lat: (json['lat'] as num?)?.toDouble(),
                lon: (json['lon'] as num?)?.toDouble(),
                compassAngle: (json['compass_angle'] as num?)?.toDouble(),
                author: json['creator']?.toString() ?? '',
              ))
          .where((p) => p.thumbUrl.isNotEmpty)
          .toList();

      photos.sort((a, b) {
        final ca = a.capturedAt ?? 0;
        final cb = b.capturedAt ?? 0;
        if (ca != cb) return cb.compareTo(ca);
        return _distance(a, lat, lon).compareTo(_distance(b, lat, lon));
      });
      return photos;
    } catch (_) {
      return [];
    }
  }

  double _distance(StreetPhoto photo, double lat, double lon) {
    if (photo.lat == null || photo.lon == null) return 1e9;
    final dLat = (photo.lat! - lat) * 111320;
    final dLon = (photo.lon! - lon) * 111320 * 0.75;
    return (dLat * dLat + dLon * dLon);
  }
}
