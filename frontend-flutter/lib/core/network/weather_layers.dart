import 'dart:convert';

import 'package:http/http.dart' as http;

/// Camadas de clima em tempo real (RainViewer, sem chave).
///
/// - **Radar de chuva**: reflectivity dos radares, 1200+ estacoes no mundo.
/// - **Infravermelho (nuvens)**: temperatura dos topos das nuvens (satelite).
///
/// Os tiles sao XYZ (padrao MapLibre) e a timeline atualiza a cada 10 min.
class WeatherLayers {
  static const String _api = 'https://api.rainviewer.com/public/weather-maps.json';

  /// Ultimo frame de radar (chuva) e de infravermelho (nuvens).
  static Future<Map<String, String?>> framesAtuais() async {
    try {
      final resp =
          await http.get(Uri.parse(_api)).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return {'radar': null, 'infrarrojo': null};
      final data =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final host = (data['host'] ?? '').toString();
      final radar = data['radar'] as Map<String, dynamic>? ?? {};
      final past = radar['past'] as List<dynamic>? ?? const [];
      final nowcast = radar['nowcast'] as List<dynamic>? ?? const [];
      final todos = [...past, ...nowcast];

      String? radarPath;
      String? radarTime;
      for (final f in todos.reversed) {
        if (f is Map && f['path'] != null) {
          radarPath = '$host${f['path']}';
          radarTime = DateTime.fromMillisecondsSinceEpoch(
                  ((f['time'] as num?)?.toInt() ?? 0) * 1000)
              .toLocal()
              .toString();
          break;
        }
      }

      final sat = data['satellite'] as Map<String, dynamic>? ?? {};
      final infrared = sat['infrared'] as List<dynamic>? ?? const [];
      String? irPath;
      for (final f in infrared.reversed) {
        if (f is Map && f['path'] != null) {
          irPath = '$host${f['path']}';
          break;
        }
      }

      return {
        'radar': radarPath,
        'radarTempo': radarTime,
        'infrarrojo': irPath,
      };
    } catch (_) {
      return {'radar': null, 'infrarrojo': null};
    }
  }

  /// URL de tile do radar de chuva (padrao XYZ do MapLibre).
  static String urlRadar(String path, int z, int x, int y) =>
      '$path/256/$z/$x/$y/2/1_1.png';

  /// URL de tile do infravermelho (nuvens).
  static String urlInfrarrojo(String path, int z, int x, int y) =>
      '$path/256/$z/$x/$y/0/0_0.png';

  /// Tiles de relevo (DEM) para o terreno 3D real (AWS Terrain Tiles, gratis).
  static String urlTerreno(int z, int x, int y) =>
      'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/$z/$x/$y.png';
}
