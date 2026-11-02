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

  /// Tipo de nuvem (limpo, poucas, parcial, nublado, encoberto, chuva...).
  final String? tipo;

  /// Chuva (mm) associada ao ponto, quando existir.
  final double chuva;

  const Ponto(this.lat, this.lon, this.valor, {this.tipo, this.chuva = 0});
}

/// Resultado de uma unica consulta ao Open-Meteo: todas as camadas de clima
/// (chuva, temperatura, nuvens e vento) para a mesma grade ao redor do
/// caminhao. Uma chamada so deixa o clima completo e economiza dados.
class ClimaGrade {
  final List<Ponto> precipitacao;
  final List<Ponto> temperatura;
  final List<Ponto> nuvens;
  final List<Map<String, double>> vento;

  const ClimaGrade({
    this.precipitacao = const [],
    this.temperatura = const [],
    this.nuvens = const [],
    this.vento = const [],
  });

  bool get vazio =>
      precipitacao.isEmpty && temperatura.isEmpty && nuvens.isEmpty;
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

  /// Zoom maximo REAL dos tiles de clima (radar/satelite). Acima disso o
  /// MapLibre amplia o ultimo tile, entao a camada continua visivel mesmo
  /// com o mapa bem de perto (estrada/cabine).
  static const int maxZoomTiles = 7;

  /// Zoom maximo em que o clima aparece no mapa. Soma ate o zoom de rua para
  /// o motorista continuar vendo chuva/nuvens, mas SOME antes do zoom muito
  /// perto (zoom de cabine/rua) para nao atrapalhar a visao da via.
  static const double maxZoomCamada = 14.0;

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

  /// Clima completo em uma unica chamada ao Open-Meteo.
  ///
  /// Busca, para a mesma grade ao redor do caminhao: probabilidade e volume
  /// de chuva, temperatura, cobertura de nuvens, tipo de tempo (weather_code)
  /// e vento (velocidade + direcao). A grade 7x7 com passo de ~3 km deixa os
  /// simbolos visiveis tambem no zoom de estrada.
  static Future<ClimaGrade> gradeClima(double lat, double lon) async {
    try {
      const passos = 7;
      const passoGraus = 0.03;
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
        'hourly': 'precipitation_probability,precipitation,cloud_cover,'
            'weather_code,wind_speed_10m,wind_direction_10m,temperature_2m',
        'forecast_days': '1',
        'timezone': 'auto',
      });
      final resp = await http.get(uri, headers: {
        'User-Agent': 'gps-camioneiro-pro/1.0'
      }).timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return const ClimaGrade();
      final dinamico = jsonDecode(utf8.decode(resp.bodyBytes));
      final locais = dinamico is List ? dinamico : [dinamico];

      final agora = DateTime.now();
      final chuva = <Ponto>[];
      final temperatura = <Ponto>[];
      final nuvens = <Ponto>[];
      final vento = <Map<String, double>>[];

      for (var i = 0; i < locais.length; i++) {
        final local = locais[i];
        if (local is! Map) continue;
        final hourly = local['hourly'];
        if (hourly is! Map) continue;
        final times = hourly['time'];
        if (times is! List || times.isEmpty) continue;
        final indice = _indiceAgora(times, agora);
        if (indice < 0) continue;

        final latRet = local['latitude'];
        final lonRet = local['longitude'];
        final pLat = latRet is num ? latRet.toDouble() : lats[i];
        final pLon = lonRet is num ? lonRet.toDouble() : lons[i];

        final prob = _valor(hourly['precipitation_probability'], indice);
        final volume = _valor(hourly['precipitation'], indice);
        final cobertura = _valor(hourly['cloud_cover'], indice);
        final codigo = (_valor(hourly['weather_code'], indice) ?? 0).round();
        final ventoVel = _valor(hourly['wind_speed_10m'], indice);
        final ventoDir = _valor(hourly['wind_direction_10m'], indice);
        final temp = _valor(hourly['temperature_2m'], indice);

        if (prob != null) {
          chuva.add(Ponto(pLat, pLon, prob, chuva: volume ?? 0));
        }
        if (temp != null) {
          temperatura.add(Ponto(pLat, pLon, temp));
        }
        if (cobertura != null) {
          nuvens.add(Ponto(
            pLat,
            pLon,
            cobertura,
            tipo: tipoNuvem(cobertura, volume ?? 0, codigo),
            chuva: volume ?? 0,
          ));
        }
        if (ventoVel != null) {
          vento.add({
            'lat': pLat,
            'lon': pLon,
            'speed': ventoVel,
            'dir': ventoDir ?? 0,
          });
        }
      }
      return ClimaGrade(
        precipitacao: chuva,
        temperatura: temperatura,
        nuvens: nuvens,
        vento: vento,
      );
    } catch (_) {
      return const ClimaGrade();
    }
  }

  /// Classifica o ceu a partir da cobertura de nuvens, chuva e weather_code.
  static String tipoNuvem(double cobertura, double chuva, int codigo) {
    if (codigo >= 95) return 'tempestade';
    if (codigo == 71 ||
        codigo == 73 ||
        codigo == 75 ||
        codigo == 77 ||
        codigo == 85 ||
        codigo == 86) {
      return 'neve';
    }
    if (codigo == 65 || codigo == 67 || codigo == 82) return 'chuva_forte';
    if (codigo == 61 ||
        codigo == 63 ||
        codigo == 66 ||
        codigo == 80 ||
        codigo == 81 ||
        (codigo >= 51 && codigo <= 57) ||
        chuva > 0.1) {
      return 'chuva';
    }
    if (cobertura >= 85) return 'encoberto';
    if (cobertura >= 60) return 'nublado';
    if (cobertura >= 30) return 'parcial';
    if (cobertura >= 10) return 'poucas';
    return 'limpo';
  }

  static int _indiceAgora(List times, DateTime agora) {
    var indice = -1;
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
    return indice;
  }

  static double? _valor(dynamic lista, int indice) {
    if (lista is! List || indice < 0 || indice >= lista.length) return null;
    final v = lista[indice];
    return v is num ? v.toDouble() : null;
  }

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
