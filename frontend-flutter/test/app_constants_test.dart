import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    test('URLs base e socket estão definidas', () {
      expect(AppConstants.baseUrl, isNotEmpty);
      expect(AppConstants.socketUrl, isNotEmpty);
    });

    test('serverConfigured é false enquanto a URL for o placeholder', () {
      expect(AppConstants.baseUrl.contains('seu-servidor'), isTrue);
      expect(AppConstants.serverConfigured, isFalse);
    });

    test('raios de alerta e chat corretos', () {
      expect(AppConstants.alertRadiusMeters, 2000);
      expect(AppConstants.chatRadiusMeters, 5000);
      expect(AppConstants.chatRadiusMeters, greaterThan(AppConstants.alertRadiusMeters));
    });

    test('lista de tipos de alerta contém os essenciais', () {
      expect(AppConstants.alertTypes, containsAll([
        'radar',
        'ponte_baixa',
        'policia',
        'balanca',
        'perigo',
      ]));
    });

    test('emojis de estrada não vazios', () {
      expect(AppConstants.roadEmojis, isNotEmpty);
      expect(AppConstants.roadEmojis.length, 4);
    });
  });
}
