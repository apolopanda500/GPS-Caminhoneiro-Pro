import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';

String _json(List<Map<String, dynamic>> itens) => jsonEncode(itens);

Map<String, dynamic> _estacao({
  String nome = 'Radio Teste',
  String url = 'https://exemplo.com/stream.mp3',
  String uuid = 'uuid-1',
  String tags = 'pop,rock',
  int bitrate = 128,
  int clicks = 10,
  int votes = 5,
  double? lat = -23.55,
  double? lon = -46.63,
}) =>
    {
      'name': nome,
      'url': url,
      'url_resolved': url,
      'stationuuid': uuid,
      'tags': tags,
      'codec': 'MP3',
      'bitrate': bitrate,
      'state': 'State of Sao Paulo',
      'country': 'Brazil',
      'countrycode': 'BR',
      'votes': votes,
      'clickcount': clicks,
      'geo_lat': lat,
      'geo_long': lon,
    };

RadioService _servicoMock(List<Map<String, dynamic>> itens,
    {int status = 200}) {
  final cliente = MockClient((req) async {
    if (status != 200) return http.Response('erro', status);
    return http.Response(_json(itens), 200,
        headers: {'content-type': 'application/json'});
  });
  return RadioService(cliente: cliente);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EstacaoRadio', () {
    test('fromJson le os campos principais da API', () {
      final e = EstacaoRadio.fromJson(_estacao());
      expect(e.nome, 'Radio Teste');
      expect(e.url, 'https://exemplo.com/stream.mp3');
      expect(e.tags, 'pop,rock');
      expect(e.bitrate, 128);
      expect(e.votes, 5);
      expect(e.clickcount, 10);
    });

    test('listaTags normaliza e remove vazios', () {
      final e = EstacaoRadio.fromJson(_estacao(tags: ' Pop , ROCK ,, '));
      expect(e.listaTags, ['pop', 'rock']);
    });

    test('chave usa uuid e cai para a url', () {
      expect(EstacaoRadio.fromJson(_estacao()).chave, 'uuid-1');
      final semUuid = EstacaoRadio.fromJson(_estacao(uuid: ''));
      expect(semUuid.chave, semUuid.url);
    });

    test('distanciaKm retorna null sem coordenadas', () {
      final e = EstacaoRadio.fromJson(_estacao(lat: null, lon: null));
      expect(e.distanciaKm(0, 0), isNull);
    });

    test('distanciaKm calcula a distancia entre pontos', () {
      final e = EstacaoRadio.fromJson(_estacao(lat: -23.55, lon: -46.63));
      final d = e.distanciaKm(-23.55, -46.63);
      expect(d, isNotNull);
      expect(d!, lessThan(1));
    });
  });

  group('RadioService', () {
    test('buscar monta a query com pais e ordenacao', () async {
      Uri? vista;
      final cliente = MockClient((req) async {
        vista = req.url;
        return http.Response(_json([_estacao()]), 200);
      });
      final servico = RadioService(cliente: cliente);
      await servico.buscar(nome: 'nova', tag: 'rock');
      expect(vista!.queryParameters['countrycode'], 'BR');
      expect(vista!.queryParameters['name'], 'nova');
      expect(vista!.queryParameters['tag'], 'rock');
      expect(vista!.queryParameters['hidebroken'], 'true');
      expect(vista!.queryParameters['order'], 'clickcount');
    });

    test('buscar descarta estacoes sem url http', () async {
      final servico = _servicoMock([
        _estacao(nome: 'Boa'),
        _estacao(nome: 'Ruim', url: 'ftp://x.com/a.mp3'),
      ]);
      final lista = await servico.buscar();
      expect(lista.length, 1);
      expect(lista.first.nome, 'Boa');
    });

    test('buscar lanca RadioException quando todos os espelhos falham', () {
      final servico = _servicoMock([], status: 500);
      expect(servico.buscar(), throwsA(isA<RadioException>()));
    });

    test('tagsBrasil conta as tags mais frequentes', () async {
      final servico = _servicoMock([
        _estacao(tags: 'pop,rock'),
        _estacao(tags: 'pop'),
        _estacao(tags: 'pop,sertanejo'),
      ]);
      final tags = await servico.tagsBrasil();
      expect(tags.first, 'pop');
      expect(tags, contains('rock'));
    });
  });
}
