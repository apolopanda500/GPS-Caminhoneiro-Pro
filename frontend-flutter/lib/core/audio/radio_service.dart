import 'dart:convert';

import 'package:http/http.dart' as http;

import 'radio_models.dart';

/// Cliente da API Radio-Browser com fallback automatico entre espelhos.
///
/// A API oficial nao expoe mais o endpoint `bygeo` (responde 404), por isso a
/// busca geografica e feita pedindo `has_geo_info=true` e ordenando por
/// distancia calculada localmente.
class RadioService {
  RadioService({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  static const espelhos = <String>[
    'https://de1.api.radio-browser.info',
    'https://de2.api.radio-browser.info',
    'https://all.api.radio-browser.info',
  ];

  static const userAgent = 'GPS-Caminhoneiro-Pro/1.0 (Flutter)';

  final http.Client _cliente;

  Map<String, String> get _headers => {
        'User-Agent': userAgent,
        'Accept': 'application/json',
      };

  /// Executa a requisicao em cada espelho ate obter sucesso.
  Future<http.Response> _get(
    String caminho, {
    Map<String, String>? query,
  }) async {
    for (final base in espelhos) {
      try {
        final uri = Uri.parse('$base$caminho').replace(
          queryParameters: {...?query},
        );
        final resp = await _cliente
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 12));
        if (resp.statusCode == 200) return resp;
      } catch (_) {}
    }
    throw const RadioException(
      'Nao foi possivel falar com o servidor de radio. Verifique a internet.',
    );
  }

  List<EstacaoRadio> _parse(Object? corpo) {
    if (corpo is! List) return const [];
    final resultado = <EstacaoRadio>[];
    for (final item in corpo) {
      if (item is! Map) continue;
      final estacao = EstacaoRadio.fromJson(Map<String, dynamic>.from(item));
      if (estacao.url.isNotEmpty && estacao.url.startsWith('http')) {
        resultado.add(estacao);
      }
    }
    return resultado;
  }

  /// Busca estacoes do Brasil aplicando os filtros informados.
  Future<List<EstacaoRadio>> buscar({
    String nome = '',
    String tag = '',
    String estado = '',
    String codec = '',
    int bitrateMinimo = 0,
    OrdenacaoRadio ordenacao = OrdenacaoRadio.popular,
    int limite = 60,
    bool apenasComGeo = false,
  }) async {
    final query = <String, String>{
      'countrycode': 'BR',
      'limit': '$limite',
      'hidebroken': 'true',
      'order': ordenacao.parametro,
      'reverse': 'true',
    };
    if (nome.trim().isNotEmpty) query['name'] = nome.trim();
    if (tag.trim().isNotEmpty) query['tag'] = tag.trim();
    if (estado.trim().isNotEmpty) query['state'] = estado.trim();
    if (codec.trim().isNotEmpty) query['codec'] = codec.trim();
    if (bitrateMinimo > 0) query['bitrate'] = '$bitrateMinimo';
    if (apenasComGeo) query['has_geo_info'] = 'true';

    final resp = await _get('/json/stations/search', query: query);
    return _parse(jsonDecode(resp.body));
  }

  /// Estacoes mais clicadas do Brasil.
  Future<List<EstacaoRadio>> maisClicadas({int limite = 40}) => buscar(
        ordenacao: OrdenacaoRadio.popular,
        limite: limite,
      );

  /// Tags mais usadas pelas estacoes brasileiras.
  Future<List<String>> tagsBrasil({int limite = 24}) async {
    try {
      final estacoes = await buscar(limite: 300);
      final contagem = <String, int>{};
      for (final estacao in estacoes) {
        for (final tag in estacao.listaTags) {
          contagem[tag] = (contagem[tag] ?? 0) + 1;
        }
      }
      final ordenadas = contagem.keys.toList()
        ..sort((a, b) => (contagem[b] ?? 0).compareTo(contagem[a] ?? 0));
      return ordenadas.take(limite).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Reporta o clique na estacao, ajudando a populace o catalogo.
  Future<void> reportarClique(EstacaoRadio estacao) async {
    try {
      await _cliente
          .get(
            Uri.parse(
              '${espelhos.first}/json/url/${Uri.encodeComponent(estacao.url)}',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  void dispose() => _cliente.close();
}

/// Erro de comunicacao com a API de radio.
class RadioException implements Exception {
  final String mensagem;
  const RadioException(this.mensagem);

  @override
  String toString() => mensagem;
}
