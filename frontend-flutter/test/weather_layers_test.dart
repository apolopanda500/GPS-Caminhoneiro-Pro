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

    test('classifica ceu limpo, nublado, chuva e tempestade', () {
      expect(WeatherLayers.tipoNuvem(5, 0, 0), 'limpo');
      expect(WeatherLayers.tipoNuvem(45, 0, 2), 'parcial');
      expect(WeatherLayers.tipoNuvem(80, 0, 3), 'nublado');
      expect(WeatherLayers.tipoNuvem(95, 0, 3), 'encoberto');
      expect(WeatherLayers.tipoNuvem(90, 0, 63), 'chuva');
      expect(WeatherLayers.tipoNuvem(100, 5, 95), 'tempestade');
      expect(WeatherLayers.tipoNuvem(100, 1, 73), 'neve');
    });
  });
}
