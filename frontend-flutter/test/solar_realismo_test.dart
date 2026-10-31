import 'package:flutter_test/flutter_test.dart';

import 'package:gps_camioneiro_pro/core/utils/moon.dart';
import 'package:gps_camioneiro_pro/core/utils/solar.dart';

void main() {
  group('sol e lua em tempo real', () {
    test('calcula altura e azimute do sol', () {
      final dia = calcularSolar(
        latitude: -22.9,
        longitude: -43.2,
        agora: DateTime.utc(2026, 10, 30, 15),
      );
      expect(dia.ehDia, isTrue);
      expect(dia.elevacaoGraus, greaterThan(0));
      expect(dia.azimuteGraus, inInclusiveRange(0, 360));
      expect(dia.nascerDoSol, isNotNull);
      expect(dia.porDoSol, isNotNull);
    });

    test('noite nao escurece o mapa de dia', () {
      expect(fatorEscuridao(elevacaoGraus: 30), 0);
      final crepusculo = fatorEscuridao(elevacaoGraus: 0);
      expect(crepusculo, greaterThan(0));
      expect(crepusculo, lessThan(0.3));
      final noite = fatorEscuridao(elevacaoGraus: -30);
      expect(noite, greaterThan(crepusculo));
      expect(noite, lessThanOrEqualTo(0.6));
    });

    test('lua cheia clareia a noite', () {
      final nova = fatorEscuridao(elevacaoGraus: -30, iluminacaoLua: 0);
      final cheia = fatorEscuridao(elevacaoGraus: -30, iluminacaoLua: 100);
      expect(cheia, lessThan(nova));
    });

    test('fase da lua fica em faixa valida', () {
      final lua = calcularLua(agora: DateTime.utc(2026, 10, 30));
      expect(lua.iluminacao, inInclusiveRange(0, 100));
      expect(lua.idadeDias, inInclusiveRange(0, 29.6));
      expect(lua.emoji, isNotEmpty);
    });
  });
}
