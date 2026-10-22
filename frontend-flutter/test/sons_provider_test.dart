import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/core/audio/sons_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SlotSom', () {
    test('cada slot tem titulo e descricao', () {
      for (final slot in SlotSom.values) {
        expect(slot.titulo, isNotEmpty);
        expect(slot.descricao, isNotEmpty);
      }
    });

    test('inclui inicio do app e entrada na parada', () {
      expect(SlotSom.values, contains(SlotSom.inicioApp));
      expect(SlotSom.values, contains(SlotSom.entradaParada));
    });

    test('porChave recupera o slot pelo nome', () {
      expect(SlotSom.porChave('inicioApp'), SlotSom.inicioApp);
      expect(SlotSom.porChave('inexistente'), isNull);
    });
  });

  group('SonsProvider', () {
    test('comeca sem sons em nenhum slot', () {
      final p = SonsProvider();
      expect(p.sons, isEmpty);
      for (final slot in SlotSom.values) {
        expect(p.temSom(slot), isFalse);
        expect(p.som(slot), isNull);
      }
    });

    test('tocar sem som configurado retorna false', () async {
      final p = SonsProvider();
      final tocou = await p.tocar(SlotSom.inicioApp);
      expect(tocou, isFalse);
    });

    test('remover um slot vazio nao falha', () async {
      final p = SonsProvider();
      await p.remover(SlotSom.avisoGeral);
      expect(p.temSom(SlotSom.avisoGeral), isFalse);
    });

    test('ignora registro com arquivo inexistente', () async {
      SharedPreferences.setMockInitialValues({
        'sons.customizados':
            'inicioApp\u001fmeu_som.mp3\u001f/nao/existe/meu_som.mp3',
      });
      final p = SonsProvider();
      await p.carregar(tocarInicio: false);
      expect(p.temSom(SlotSom.inicioApp), isFalse);
    });

    test('restaura som cujo arquivo existe', () async {
      final dir = Directory.systemTemp.createTempSync('sons_test');
      final arquivo = File('${dir.path}/som.mp3')
        ..writeAsBytesSync(const [0, 1, 2, 3]);
      addTearDown(() => dir.deleteSync(recursive: true));

      SharedPreferences.setMockInitialValues({
        'sons.customizados': 'inicioApp\u001fsom.mp3\u001f${arquivo.path}',
      });
      final p = SonsProvider();
      await p.carregar(tocarInicio: false);

      expect(p.temSom(SlotSom.inicioApp), isTrue);
      expect(p.som(SlotSom.inicioApp)!.nome, 'som.mp3');
      expect(p.som(SlotSom.inicioApp)!.caminho, arquivo.path);
    });
  });
}
