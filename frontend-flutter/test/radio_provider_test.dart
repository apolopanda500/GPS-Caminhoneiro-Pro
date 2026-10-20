import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';

Map<String, dynamic> _estacao(String nome, {String uuid = 'u1'}) => {
      'name': nome,
      'url': 'https://exemplo.com/$nome.mp3',
      'url_resolved': 'https://exemplo.com/$nome.mp3',
      'stationuuid': uuid,
      'tags': 'pop',
      'bitrate': 128,
      'votes': 3,
      'clickcount': 9,
    };

RadioService _servico(List<Map<String, dynamic>> itens, {int status = 200}) {
  return RadioService(
    cliente: MockClient((req) async {
      if (status != 200) return http.Response('erro', status);
      return http.Response(jsonEncode(itens), 200);
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AudioProvider - lista de estacoes', () {
    test('estado inicial: lista vazia e sem erro', () {
      final p = AudioProvider(servico: _servico([]));
      expect(p.estacoes, isEmpty);
      expect(p.erroRadio, '');
      expect(p.carregandoEstacoes, isFalse);
    });

    test('carregarPopulares preenche a lista', () async {
      final p = AudioProvider(servico: _servico([_estacao('A'), _estacao('B')]));
      final ok = await p.carregarPopulares();
      expect(ok, isTrue);
      expect(p.estacoes.length, 2);
      expect(p.estacoes.first.nome, 'A');
      expect(p.carregandoEstacoes, isFalse);
    });

    test('buscarEstacoes preenche a lista pelo nome', () async {
      final p = AudioProvider(servico: _servico([_estacao('Nova FM')]));
      final ok = await p.buscarEstacoes('nova');
      expect(ok, isTrue);
      expect(p.estacoes.first.nome, 'Nova FM');
    });

    test('falha na API registra erro e esvazia o carregamento', () async {
      final p = AudioProvider(servico: _servico([], status: 500));
      final ok = await p.carregarPopulares();
      expect(ok, isFalse);
      expect(p.erroRadio, isNotEmpty);
      expect(p.carregandoEstacoes, isFalse);
    });

    test('setTag alterna a selecao e recarrega', () async {
      final p = AudioProvider(servico: _servico([_estacao('A')]));
      await p.setTag('pop');
      expect(p.tagSelecionada, 'pop');
      expect(p.filtro, FiltroRadio.tags);
      await p.setTag('pop');
      expect(p.tagSelecionada, '');
      expect(p.filtro, FiltroRadio.todas);
    });

    test('setOrdenacao troca a ordenacao atual', () async {
      final p = AudioProvider(servico: _servico([_estacao('A')]));
      await p.setOrdenacao(OrdenacaoRadio.votadas);
      expect(p.ordenacao, OrdenacaoRadio.votadas);
    });
  });

  group('AudioProvider - favoritos e recentes', () {
    test('alternarFavorita marca e desmarca', () async {
      final p = AudioProvider(servico: _servico([]));
      final e = EstacaoRadio(nome: 'X', url: 'https://x.com/a.mp3', uuid: 'u');
      expect(p.ehFavorita(e), isFalse);
      await p.alternarFavorita(e);
      expect(p.ehFavorita(e), isTrue);
      expect(p.favoritos.length, 1);
      await p.alternarFavorita(e);
      expect(p.ehFavorita(e), isFalse);
      expect(p.favoritos, isEmpty);
    });

    test('favoritos sao persistidos entre instancias', () async {
      final e = EstacaoRadio(nome: 'X', url: 'https://x.com/a.mp3', uuid: 'u');
      final p1 = AudioProvider(servico: _servico([]));
      await p1.alternarFavorita(e);

      final p2 = AudioProvider(servico: _servico([]));
      await p2.carregarFavoritosERecentes();
      expect(p2.ehFavorita(e), isTrue);
    });

    test('lista de favoritos e imutavel para fora', () async {
      final p = AudioProvider(servico: _servico([]));
      final e = EstacaoRadio(nome: 'X', url: 'https://x.com/a.mp3', uuid: 'u');
      await p.alternarFavorita(e);
      expect(() => p.favoritos.add(e), throwsUnsupportedError);
    });
  });
}



