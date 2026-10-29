import 'dart:convert';

import 'package:http/http.dart' as http;

/// Um frame do radar (imagem de um instante).
class FrameRadar {
  final String path;
  final DateTime tempo;
  final bool nowcast;

  const FrameRadar({
    required this.path,
    required this.tempo,
    required this.nowcast,
  });

  String get hora =>
      '${tempo.hour.toString().padLeft(2, '0')}:${tempo.minute.toString().padLeft(2, '0')}';
}

/// Um ponto da grade de previsao (para desenhar sobre o mapa).
class Ponto {
  final double lat;
  final double lon;
  final double valor;

  const Ponto(this.lat, this.lon, this.valor);
}

/// Camadas de clima em tempo real.
///
/// Tudo **sem chave de API**:
/// - **Radar de chuva** (RainViewer): 1200+ radares, 13 frames passados +
///   nowcast (previsao) - e o que permite a animacao do radar.
/// - **Nuvens por infravermelho** (RainViewer/satelite).
/// - **Previsao em grade** (Open-Meteo): precipitacao, vento, temperatura e
///   cobertura de nuvens desenhados como circulos coloridos sobre o mapa.
class WeatherLayers {
  static const String _api =
      'https://api.rainviewer.com/public/weather-maps.json';
  static const String _openMeteo = 'https://api.open-meteo.com/v1/forecast';

  static const int maxZoomTiles = 7;

  /// Timeline completa do radar: 2 horas de passado + nowcast (previsao).
  static Future<List<FrameRadar>> framesRadar() async {
    try {
      final resp =
          await http.get(Uri.parse(_api)).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return const [];
      final data =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final host = (data['host'] ?? '').toString();
      final radar = data['radar'] as Map<String, dynamic>? ?? {};
      final past = radar['past'] as List<dynamic>? ?? const [];
      final nowcast = radar['nowcast'] as List<dynamic>? ?? const [];

      final lista = <FrameRadar>[];
      for (final f in past) {
        if (f is Map && f['path'] != null) {
          lista.add(FrameRadar(
            path: '$host${f['path']}',
            tempo: DateTime.fromMillisecondsSinceEpoch(
                    ((f['time'] as num?)?.toInt() ?? 0) * 1000)
                .toLocal(),
            nowcast: false,
          ));
        }
      }
      for (final f in nowcast) {
        if (f is Map && f['path'] != null) {
          lista.add(FrameRadar(
            path: '$host${f['path']}',
            tempo: DateTime.fromMillisecondsSinceEpoch(
                    ((f['time'] as num?)?.toInt() ?? 0) * 1000)
                .toLocal(),
            nowcast: true,
          ));
        }
      }
      return lista;
    } catch (_) {
      return const [];
    }
  }

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

  /// Grade de previsao do Open-Meteo sobre a posicao do caminhao.
  ///
  /// [campo] pode ser: `precipitation_probability`, `precipitation`,
  /// `wind_speed_10m`, `temperature_2m` ou `cloud_cover`.
  static Future<List<Ponto>> gradePrevisao(
    double lat,
    double lon, {
    String campo = 'precipitation_probability',
    int horas = 1,
  }) async {
    try {
      // Grade 5x5 ao redor do caminhao, com passo de ~9 km (~0.08 grau):
      // o centro da grade e EXATAMENTE o caminhao (i=2 => 0 grau), entao
      // os circulos ficam visiveis no zoom de estrada do app.
      const passos = 5;
      const passoGraus = 0.08;
      final lats = <double>[];
      final lons = <double>[];
      for (var i = 0; i < passos; i++) {
        for (var j = 0; j < passos; j++) {
          lats.add(lat + (i - (passos - 1) / 2) * passoGraus);
          lons.add(lon + (j - (passos - 1) / 2) * passoGraus);
        }
      }

      final uri = Uri.parse(_openMeteo).replace(queryParameters: {
        'latitude': lats.map((v) => v.toStringAsFixed(4)).join(','),
        'longitude': lons.map((v) => v.toStringAsFixed(4)).join(','),
        'hourly': campo,
        'forecast_days': '2',
        'timezone': 'auto',
      });
      final resp = await http.get(uri, headers: {
        'User-Agent': 'gps-camioneiro-pro/1.0'
      }).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return const [];
      final dinamico = jsonDecode(utf8.decode(resp.bodyBytes));
      final locais = dinamico is List ? dinamico : [dinamico];

      final agora = DateTime.now();
      final pontos = <Ponto>[];
      for (var i = 0; i < locais.length; i++) {
        final local = locais[i];
        if (local is! Map) continue;
        final hourly = local['hourly'];
        if (hourly is! Map) continue;
        final valores = hourly[campo];
        final times = hourly['time'];
        if (valores is! List || times is! List) continue;

        var indice = 0;
        var menor = 1e12;
        for (var t = 0; t < times.length; t++) {
          final hora = DateTime.tryParse(times[t].toString());
          if (hora == null) continue;
          final d = hora.difference(agora).inMinutes.abs().toDouble();
          if (d < menor) {
            menor = d;
            indice = t;
          }
        }
        if (indice >= valores.length) continue;
        final v = valores[indice];
        if (v is! num) continue;

        final latRet = local['latitude'];
        final lonRet = local['longitude'];
        pontos.add(Ponto(
          latRet is num ? latRet.toDouble() : lats[i],
          lonRet is num ? lonRet.toDouble() : lons[i],
          v.toDouble(),
        ));
      }
      return pontos;
    } catch (_) {
      return const [];
    }
  }

  /// Modelo de URL XYZ do radar de chuva para o MapLibre.
  static String templateRadar(String path) => '$path/256/{z}/{x}/{y}/2/1_1.png';

  /// Modelo de URL XYZ do infravermelho (nuvens reais).
  static String templateInfrarrojo(String path) =>
      '$path/256/{z}/{x}/{y}/0/0_0.png';

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
