import 'package:flutter_test/flutter_test.dart';

import 'package:gps_camioneiro_pro/core/network/weather_layers.dart';

void main() {
  group('WeatherLayers tiles', () {
    test('radar usa modelo XYZ real para o MapLibre', () {
      final url = WeatherLayers.templateRadar('https://tiles.exemplo/radar');
      expect(url, contains('{z}/{x}/{y}'));
      expect(url, isNot(contains('/0/0/0/')));
      expect(url, endsWith('/2/1_1.png'));
    });

    test('nuvens usam modelo XYZ real para o MapLibre', () {
      final url = WeatherLayers.templateInfrarrojo('https://tiles.exemplo/sat');
      expect(url, contains('{z}/{x}/{y}'));
      expect(url, isNot(contains('/0/0/0/')));
      expect(url, endsWith('/0/0_0.png'));
    });

    test('respeita o zoom maximo entregue pelo RainViewer', () {
      expect(WeatherLayers.maxZoomTiles, 7);
    });
  });
}
