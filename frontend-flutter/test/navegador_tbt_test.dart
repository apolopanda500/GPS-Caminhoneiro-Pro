import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:gps_camioneiro_pro/core/rota/navegador_tbt.dart';
import 'package:gps_camioneiro_pro/core/rota/manobra.dart';
import 'package:gps_camioneiro_pro/core/network/directions_service.dart';
import 'package:gps_camioneiro_pro/core/audio/voice_service.dart';
import 'package:gps_camioneiro_pro/core/gps/filtro_kalman.dart';

List<String> falada = <String>[];

Future<Object?>? _canalResponde(MethodCall call) => Future<Object?>.value(
    _tts(call));

Object? _tts(MethodCall call) {
  if (call.method == 'speak') {
    final args = call.arguments;
    if (args is Map) {
      final mapa = args.cast<String, dynamic>();
      falada.add(mapa['text']?.toString() ?? '');
    } else if (args is String) {
      falada.add(args);
    }
    return true;
  }
  if (call.method == 'getVoices' || call.method == 'getLanguages') {
    return jsonEncode([]);
  }
  return '1';
}

const MethodChannel _canal = MethodChannel('flutter_tts');

RouteResult rotaSerie(double espaco, int n, String texto) {
  final manobras = <Manobra>[];
  for (var i = 0; i < n; i++) {
    manobras.add(Manobra(
      posicao: LatLng(-22.90 - i * espaco / 111320, -43.20),
      tipo: 'esquerda',
      texto: texto,
      distancia: espaco,
      acumulado: espaco * i,
    ));
  }
  return RouteResult(
    polyline: [
      LatLng(-22.90, -43.20),
      LatLng(-22.90 - n * espaco / 111320, -43.20),
    ],
    distanceMeters: espaco * n,
    durationSeconds: espaco * n / 15,
    staticDurationSeconds: espaco * n / 15,
    summary: 'teste',
    manobras: manobras,
  );
}

const String _textoPrimeira = 'Vire a esquerda na Rua Teste';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    falada = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, _canalResponde);
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
    expect(normalizarManobra('left'), 'esquerda');
    expect(normalizarManobra('continue'), 'reto');
  });

  test('kalman filtra e extrapola o tunel', () {
    final filtro = FiltroKalman();
    var pos = const LatLng(-22.90, -43.20);
    for (var i = 0; i < 6; i++) {
      pos = LatLng(pos.latitude + 0.0009, pos.longitude);
      final f = filtro.filtrar(pos, 8);
      expect((f.pos.latitude - pos.latitude).abs(), lessThan(0.005));
    }
    final a10s = filtro.prevista(desdeUltimoGps: const Duration(seconds: 10));
    expect(a10s.estimada, isTrue);
    expect(a10s.pos.latitude, greaterThan(pos.latitude));
    final a40s = filtro.prevista(desdeUltimoGps: const Duration(seconds: 40));
    expect(a40s.precisao, greaterThan(a10s.precisao));
  });

  test('navegador acompanha progresso e troca de manobra', () async {
    final total = 2000.0;
    final espaco = 1000.0;
    final nav = NavegadorTbt(voz: VoiceService.instance);
    final rota = rotaSerie(espaco, 2, _textoPrimeira);
    nav.definirRota(rota);
    expect(nav.ativa, isTrue);
    await Future<void>.delayed(Duration.zero);
    final faladasAntes = falada.length;

    final p0 = rota.manobras[0].posicao;
    var snap = nav.atualizar(p0);
    expect(snap.proxima!.tipo, 'esquerda');
    expect(snap.distanciaProxima, closeTo(espaco, 6.0));

    for (var i = 1; i <= 60; i++) {
      snap = nav.atualizar(LatLng(p0.latitude + i * 20 / 111320, p0.longitude));
    }
    expect(snap.proxima!.acumulado, greaterThan(900));
    expect(falada.length, greaterThanOrEqualTo(faladasAntes));
    expect(nav.restanteAoDestino, lessThanOrEqualTo(total));
  });

  test('navegador fala prepare/agora nos umbrais da proxima manobra',
      () async {
    final nav = NavegadorTbt(voz: VoiceService.instance);
    final rota = rotaSerie(2000, 3, _textoPrimeira);
    nav.definirRota(rota);
    await Future<void>.delayed(const Duration(seconds: 1));
    falada.clear();

    void andar(double metros) {
      var lat = rota.manobras[0].posicao.latitude;
      for (var i = 0; i < 40; i++) {
        lat += metros / 40 / 111320;
        nav.atualizar(LatLng(lat, -43.20));
      }
    }

    andar(1150);
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(falada.any((f) => f.contains('Prepare-se')), isTrue);
    falada.clear();

    andar(400);
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(falada.any((f) => f.contains('Agora')), isTrue);
  });
}
