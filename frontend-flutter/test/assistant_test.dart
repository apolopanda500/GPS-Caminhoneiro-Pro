import 'package:flutter_test/flutter_test.dart';

import 'package:gps_camioneiro_pro/core/ai/assistant_engine.dart';

void main() {
  group('Assistente da estrada', () {
    test('responde sobre a rota', () {
      final r = AssistantEngine.responder(
        pergunta: 'como esta minha rota?',
        totalParadas: 4,
        entregasFeitas: 1,
        rotaResumo: '32 km',
      );
      expect(r, contains('4 parada'));
      expect(r, contains('1 ja entregada'));
      expect(r, contains('32 km'));
    });

    test('avisa quando nao ha rota', () {
      final r = AssistantEngine.responder(pergunta: 'minha rota');
      expect(r, contains('ainda nao montou rota'));
    });

    test('lista os sinais ativos', () {
      final r = AssistantEngine.responder(
        pergunta: 'tem algum sinal perto?',
        alertas: const ['[SINAL] curva perigosa', '[ACIDENTE] na BR-101'],
      );
      expect(r, contains('curva perigosa'));
      expect(r, contains('ACIDENTE'));
    });

    test('avisa quando nao ha sinais', () {
      final r = AssistantEngine.responder(pergunta: 'alerta de acidente');
      expect(r, contains('Nenhum sinal ativo'));
    });

    test('compara velocidade com o limite', () {
      final r = AssistantEngine.responder(
        pergunta: 'qual o limite de velocidade?',
        velocidade: 95,
        limiteVelocidade: 80,
        rua: 'BR-101',
      );
      expect(r, contains('95 km/h'));
      expect(r, contains('80 km/h'));
      expect(r, contains('ACIMA DO LIMITE'));
      expect(r, contains('BR-101'));
    });

    test('informa o clima', () {
      final r = AssistantEngine.responder(
        pergunta: 'esta chovendo?',
        clima: 'Chuva forte a 12 km da sua posicao.',
      );
      expect(r, contains('Chuva forte'));
    });

    test('explica como pedir ajuda', () {
      final r = AssistantEngine.responder(pergunta: 'preciso de guincho');
      expect(r, contains('Sinalizar'));
    });

    test('responde a pergunta vazia com as opcoes', () {
      final r = AssistantEngine.responder(pergunta: '');
      expect(r, contains('rota'));
    });
  });
}
