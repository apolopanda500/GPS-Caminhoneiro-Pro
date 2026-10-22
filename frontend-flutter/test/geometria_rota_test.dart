import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:gps_camioneiro_pro/core/rota/geometria_rota.dart';

void main() {
  const a = LatLng(-23.5500, -46.6333);
  final rota = <LatLng>[
    a,
    const LatLng(-23.5500, -46.6300),
    const LatLng(-23.5500, -46.6270),
    const LatLng(-23.5500, -46.6240),
  ];

  group('GeometriaRota', () {
    test('mede a distancia do ponto ate a linha da rota', () {
      final emCima = LatLng(a.latitude + 0.0009, a.longitude);
      final d = GeometriaRota.distanciaAteRota(rota, emCima);
      expect(d, greaterThan(90));
      expect(d, lessThan(110));
    });

    test('ponto sobre a rota tem distancia zero', () {
      final d = GeometriaRota.distanciaAteRota(rota, rota[1]);
      expect(d, lessThan(1));
    });

    test('descarta o trecho ja percorrido e comeca na posicao atual', () {
      const pos = LatLng(-23.5500, -46.6285);
      final resto = GeometriaRota.restante(rota, pos, margemMetros: 20);
      expect(resto.first, pos);
      expect(resto.length, lessThanOrEqualTo(rota.length + 1));
      expect(resto.last.longitude, closeTo(rota.last.longitude, 1e-9));
      expect(resto.any((p) => p.longitude == rota.first.longitude), isFalse);
    });

    test('nao corta nada quando o caminhao esta no inicio', () {
      final resto = GeometriaRota.restante(rota, rota.first);
      expect(resto.length, greaterThanOrEqualTo(rota.length));
      expect(resto.last.longitude, closeTo(rota.last.longitude, 1e-9));
    });

    test('calcula rumo norte, leste e suaviza sem dar a volta', () {
      expect(GeometriaRota.bearing(a, const LatLng(-23.54, -46.6333)),
          closeTo(0, 1));
      expect(GeometriaRota.bearing(a, const LatLng(-23.55, -46.62)),
          closeTo(90, 1));
      final suave = GeometriaRota.suavizarBearing(350, 10, 0.5);
      expect(suave % 360, closeTo(0, 0.001));
    });

    test('desloca um ponto para frente no rumo informado', () {
      final leste = GeometriaRota.deslocar(a, 90, 100);
      expect(leste.longitude, greaterThan(a.longitude));
      expect(GeometriaRota.distancia(a, leste), closeTo(100, 2));
    });
  });
}
