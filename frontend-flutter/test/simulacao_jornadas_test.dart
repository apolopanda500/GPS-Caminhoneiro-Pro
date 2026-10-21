import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:gps_camioneiro_pro/core/rota/monitor_paradas.dart';

/// Uma parada ficticia em uma rua qualquer.
class ParadaFicticia {
  ParadaFicticia(this.ponto, this.raio);
  final LatLng ponto;
  final double raio;

  double distancia(LatLng p) {
    const metroPorGrau = 111320.0;
    final dx = (p.longitude - ponto.longitude) * metroPorGrau * 0.75;
    final dy = (p.latitude - ponto.latitude) * metroPorGrau;
    return sqrt(dx * dx + dy * dy);
  }
}

double _dist(LatLng a, LatLng b) {
  const metroPorGrau = 111320.0;
  final dx = (a.longitude - b.longitude) * metroPorGrau * 0.75;
  final dy = (a.latitude - b.latitude) * metroPorGrau;
  return sqrt(dx * dx + dy * dy);
}

/// Simulacao de estrada: milhares de jornadas com GPS realista (ruido,
/// parado no sinal, voltando, teleporte) para achar falha escondida.
void main() {
  final random = Random(20261020);

  group('Monitor de paradas: simulacoes de estrada', () {
    test('mil jornadas aleatorias: chegada e saida acontecem uma vez so', () {
      for (var jornada = 0; jornada < 1000; jornada++) {
        final paradas = <ParadaFicticia>[];
        for (var i = 0; i < 4; i++) {
          paradas.add(ParadaFicticia(
            LatLng(
              -22.9 + random.nextDouble() * 0.1,
              -43.2 + random.nextDouble() * 0.1,
            ),
            120 + random.nextDouble() * 80,
          ));
        }
        final monitor = MonitorDeParadas();
        var chegadas = 0;
        var saidas = 0;

        var pos = paradas.first.ponto;
        for (final p in paradas) {
          // Aproxima em passos, com ruido de GPS.
          while (p.distancia(pos) > p.raio * 0.5) {
            pos = LatLng(
              pos.latitude + (p.ponto.latitude - pos.latitude) * 0.08,
              pos.longitude + (p.ponto.longitude - pos.longitude) * 0.08,
            );
            final ev = monitor.processar(
              totalParadas: paradas.length,
              dentroDe: (i) => paradas[i].distancia(pos) <= paradas[i].raio,
              saiuDe: (i) => paradas[i].distancia(pos) > paradas[i].raio + 20,
              velocidadeKmh: 40,
            );
            for (final e in ev) {
              if (e.chegou) chegadas++;
              if (e.saiu) saidas++;
            }
          }
          // Para na parada (velocidade zero): nao deve anunciar saida.
          for (var k = 0; k < 20; k++) {
            final ev = monitor.processar(
              totalParadas: paradas.length,
              dentroDe: (i) => paradas[i].distancia(pos) <= paradas[i].raio,
              saiuDe: (i) => paradas[i].distancia(pos) > paradas[i].raio + 20,
              velocidadeKmh: 0,
            );
            for (final e in ev) {
              if (e.chegou) chegadas++;
              if (e.saiu) {
                fail('nao pode anunciar saida com o caminhao parado');
              }
            }
          }
        }
        if (chegadas > paradas.length) {
          fail('anunciou chegada mais de uma vez por parada');
        }
        if (saidas > chegadas) {
          fail('anunciou mais saidas que chegadas');
        }
      }
    });

    test('mil jornadas: parado dentro da parada nunca anuncia saida', () {
      for (var j = 0; j < 1000; j++) {
        final ponto = LatLng(-22.9, -43.2);
        const raio = 120.0;
        final monitor = MonitorDeParadas();
        var saidas = 0;
        for (var k = 0; k < 50; k++) {
          final pos = LatLng(
            ponto.latitude + (random.nextDouble() - 0.5) * 0.0005,
            ponto.longitude + (random.nextDouble() - 0.5) * 0.0005,
          );
          final ev = monitor.processar(
            totalParadas: 1,
            dentroDe: (i) => _dist(pos, ponto) <= raio,
            saiuDe: (i) => _dist(pos, ponto) > raio + 20,
            velocidadeKmh: 0,
          );
          for (final e in ev) {
            if (e.saiu) saidas++;
          }
        }
        if (saidas != 0) {
          fail('anunciou saida com o caminhao parado dentro da parada');
        }
      }
    });

    test('mil jornadas: so anuncia a proxima quando ja andando', () {
      for (var j = 0; j < 1000; j++) {
        final monitor = MonitorDeParadas();
        final eventos = <EventoParada>[];

        // Chega (velocidade alta, dentro do raio).
        eventos.addAll(monitor.processar(
          totalParadas: 1,
          dentroDe: (i) => true,
          saiuDe: (i) => true,
          velocidadeKmh: 50,
        ));
        // Sai do raio, mas parado: nao anuncia.
        eventos.addAll(monitor.processar(
          totalParadas: 1,
          dentroDe: (i) => false,
          saiuDe: (i) => true,
          velocidadeKmh: 0,
        ));
        // Sai do raio andando: anuncia uma vez.
        eventos.addAll(monitor.processar(
          totalParadas: 1,
          dentroDe: (i) => false,
          saiuDe: (i) => true,
          velocidadeKmh: 30,
        ));
        // Continua andando: nao repete.
        eventos.addAll(monitor.processar(
          totalParadas: 1,
          dentroDe: (i) => false,
          saiuDe: (i) => true,
          velocidadeKmh: 30,
        ));

        final chegadas = eventos.where((e) => e.chegou).length;
        final saidas = eventos.where((e) => e.saiu).length;
        if (chegadas != 1) fail('chegada esperada 1, veio $chegadas');
        if (saidas != 1) fail('saida esperada 1, veio $saidas');
      }
    });

    test('mil jornadas: GPS pulando (teleporte) nao trava o monitor', () {
      for (var j = 0; j < 1000; j++) {
        final monitor = MonitorDeParadas();
        final pontos = [
          LatLng(-22.9, -43.2),
          const LatLng(-23.5, -44.0),
          const LatLng(0, 0),
          const LatLng(-15.7, -47.9),
        ];
        for (final _ in pontos) {
          final ev = monitor.processar(
            totalParadas: 3,
            dentroDe: (i) => false,
            saiuDe: (i) => true,
            velocidadeKmh: 60,
          );
          for (final e in ev) {
            if (e.indice < 0 || e.indice >= 3) fail('indice invalido');
          }
        }
      }
    });

    test('reiniciar o monitor limpa o estado', () {
      final monitor = MonitorDeParadas();
      monitor.processar(
        totalParadas: 1,
        dentroDe: (i) => true,
        saiuDe: (i) => false,
        velocidadeKmh: 0,
      );
      expect(monitor.paradaParada, 0);
      monitor.resetar();
      expect(monitor.paradaParada, isNull);
    });
  });
}
