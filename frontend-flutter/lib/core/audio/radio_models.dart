import 'package:latlong2/latlong.dart';

/// Uma estacao de radio digital devolvida pela API Radio-Browser.
class EstacaoRadio {
  final String nome;
  final String url;
  final String uuid;
  final String tags;
  final String codec;
  final int bitrate;
  final String country;
  final String state;
  final String language;
  final String favicon;
  final int votes;
  final int clickcount;
  final double? latitude;
  final double? longitude;

  EstacaoRadio({
    required this.nome,
    required this.url,
    this.uuid = '',
    this.tags = '',
    this.codec = '',
    this.bitrate = 0,
    this.country = '',
    this.state = '',
    this.language = '',
    this.favicon = '',
    this.votes = 0,
    this.clickcount = 0,
    this.latitude,
    this.longitude,
  });

  factory EstacaoRadio.fromJson(Map<String, dynamic> j) => EstacaoRadio(
        nome: (j['name'] ?? 'Estacao').toString(),
        url: (j['url_resolved'] ?? j['url'] ?? '').toString(),
        uuid: (j['stationuuid'] ?? '').toString(),
        tags: (j['tags'] ?? '').toString(),
        codec: (j['codec'] ?? '').toString(),
        bitrate: _int(j['bitrate']),
        country: (j['country'] ?? '').toString(),
        state: (j['state'] ?? '').toString(),
        language: (j['language'] ?? '').toString(),
        favicon: (j['favicon'] ?? '').toString(),
        votes: _int(j['votes']),
        clickcount: _int(j['clickcount']),
        latitude: _double(j['geo_lat']),
        longitude: _double(j['geo_long']),
      );

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'url': url,
        'uuid': uuid,
        'tags': tags,
        'codec': codec,
        'bitrate': bitrate,
        'country': country,
        'state': state,
        'language': language,
        'favicon': favicon,
        'votes': votes,
        'clickcount': clickcount,
        'latitude': latitude,
        'longitude': longitude,
      };

  /// Identificador estavel da estacao (uuid) ou, na falta, a propria URL.
  String get chave => uuid.isNotEmpty ? uuid : url;

  /// Lista de tags da estacao, normalizada.
  List<String> get listaTags => tags
      .split(',')
      .map((t) => t.trim().toLowerCase())
      .where((t) => t.isNotEmpty)
      .toList();

  /// Distancia em km a partir de uma coordenada, quando disponivel.
  double? distanciaKm(double lat, double lon) {
    if (latitude == null || longitude == null) return null;
    return const Distance().as(
      LengthUnit.Kilometer,
      LatLng(latitude!, longitude!),
      LatLng(lat, lon),
    );
  }

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? 0;
  }

  static double? _double(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v == null) return null;
    return double.tryParse('$v');
  }
}

/// Como as estacoes devem ser ordenadas na lista.
enum OrdenacaoRadio {
  popular('Mais tocadas', 'clickcount'),
  votadas('Mais votadas', 'votes'),
  nome('Nome (A-Z)', 'name'),
  recentes('Verificadas recentemente', 'lastchecktime');

  const OrdenacaoRadio(this.titulo, this.parametro);

  final String titulo;
  final String parametro;
}

/// Filtro principal da lista de estacoes.
enum FiltroRadio {
  todas('Todas'),
  populares('Populares'),
  tags('Tags'),
  perto('Perto de mim');

  const FiltroRadio(this.titulo);

  final String titulo;
}