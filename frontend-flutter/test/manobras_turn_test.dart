import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:gps_camioneiro_pro/core/rota/manobra.dart';
import 'package:gps_camioneiro_pro/core/network/directions_service.dart';

String encode(List<LatLng> pontos) {
  var lat = 0, lng = 0;
  final sb = StringBuffer();
  for (final p in pontos) {
    final la = (p.latitude * 1e5).round();
    final ln = (p.longitude * 1e5).round();
    int di = la - lat, dn = ln - lng;
    lat = la;
    lng = ln;
    for (final d in [di, dn]) {
      var v = d < 0 ? ~(d << 1) : (d << 1);
      while (v >= 0x20) {
        sb.write(String.fromCharCode(((0x20 | (v & 0x1f)) + 63).toUnsigned(8)));
        v >>= 5;
      }
      sb.write(String.fromCharCode((v + 63).toUnsigned(8)));
    }
  }
  return sb.toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodificarPolyline ida e volta', () {
    final pontos = [LatLng(-22.9068, -43.1729), LatLng(-22.9145, -43.0946)];
    final codificada = encode(pontos);
    final decodificada = decodificarPolyline(codificada);
    expect(decodificada.length, pontos.length);
    expect((decodificada[0].latitude - pontos[0].latitude).abs(), lessThan(1e-4));
    expect((decodificada[1].longitude - pontos[1].longitude).abs(), lessThan(1e-4));
  });

  test('normalizarManobra traduz Google, OSRM e ORS', () {
    expect(normalizarManobra('TURN_LEFT'), 'esquerda');
    expect(normalizarManobra('TURN_SLIGHT_RIGHT'), 'levemente_direita');
    expect(normalizarManobra('UTURN'), 'retorno');
    expect(normalizarManobra('ROUNDABOUT'), 'rotatoria');
    expect(normalizarManobra('DEPART'), 'partida');
    expect(normalizarManobra('ARRIVE'), 'chegada');
    expect(normalizarManobra('NAME_CHANGE'), 'reto');
    expect(normalizarManobra('turn left'), 'esquerda');
    expect(normalizarManobra('continue'), 'reto');
  });

  test('extrairManobrasGoogle monta passos com polylines por step', () {
    final route = {
      'legs': [
        {
          'steps': [
            {
              'distanceMeters': 150,
              'polyline': {'encodedPolyline': encode([LatLng(-22.90, -43.17), LatLng(-22.90, -43.16)])},
              'navigationInstruction': {
                'maneuver': 'DEPART',
                'instructions': 'Siga na direção norte na BR-101',
              },
            },
            {
              'distanceMeters': 300,
              'polyline': {'encodedPolyline': encode([LatLng(-22.90, -43.16), LatLng(-22.89, -43.15)])},
              'navigationInstruction': {
                'maneuver': 'TURN_RIGHT',
                'instructions': 'Vire à direita na Rua X',
              },
            },
          ],
        },
      ],
    };
    final manobras = extrairManobrasGoogle(route)['manobras']!;
    expect(manobras.length, 2);
    expect(manobras[0].tipo, 'partida');
    expect(manobras[0].acumulado, 0);
    expect(manobras[1].tipo, 'direita');
    expect(manobras[1].acumulado, 150);
    expect(manobras[1].geometria.length, 2);
  });

  test('extrairManobrasOrs usa way_points na geometria', () {
    final properties = {
      'instructions': [
        {'type': 'left', 'text': 'Vire à esquerda', 'distance': 1000.0},
        {'type': 'arrive', 'text': 'Chegou', 'distance': 200.0},
      ],
      'way_points': [0, 5, 10],
    };
    final polyline = [
      ...List.generate(5, (i) => LatLng(-22.90 + i * 0.01, -43.17)),
      ...List.generate(5, (i) => LatLng(-22.90 + (5 + i) * 0.01, -43.16)),
    ];
    final manobras = extrairManobrasOrs(properties, polyline).expand((e) => e).toList();
    expect(manobras.length, 2);
    expect(manobras[0].tipo, 'esquerda');
    expect(manobras[0].distancia, 1000.0);
    expect(manobras[1].tipo, 'chegada');
    expect(manobras[0].geometria.length, 6);
  });

  test('extrairManobrasOsrm extrai faixas validadas', () {
    final rota = {
      'legs': [
        {
          'steps': [
            {
              'geometry': {'coordinates': [[-43.17, -22.90], [-43.16, -22.89]]},
              'maneuver': {'type': 'turn', 'modifier': 'right'},
              'name': 'BR-040',
              'distance': 500.0,
              'intersections': [
                {
                  'lanes': [
                    {'valid': false, 'indications': ['straight', 'left']},
                    {'valid': true, 'indications': ['right']},
                  ],
                },
              ],
            },
          ],
        },
      ],
    };
    final manobras = extrairManobrasOsrm(rota).expand((e) => e).toList();
    expect(manobras.length, 1);
    expect(manobras[0].tipo, 'direita');
    expect(manobras[0].texto, 'right para BR-040');
    expect(manobras[0].faixas.length, 2);
    expect(manobras[0].faixas.last.eValida, isTrue);
    expect(manobras[0].faixas.first.indicacao, 'straight+left');
  });
}
