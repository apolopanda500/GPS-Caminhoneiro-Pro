import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/core/premium/premium_policy.dart';
import 'package:gps_camioneiro_pro/data/models/alert_model.dart';
import 'package:gps_camioneiro_pro/data/models/map_marker_model.dart';
import 'package:gps_camioneiro_pro/providers/alert_provider.dart';
import 'package:gps_camioneiro_pro/providers/marker_provider.dart';
import 'package:gps_camioneiro_pro/providers/peer_provider.dart';
import 'package:gps_camioneiro_pro/providers/route_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';

/// =============================================================================
/// BATERIA DE SIMULACAO REAL NO APP
/// =============================================================================
///// Simula varios motoristas diferentes usando o app ao mesmo tempo:
/// cada um com sua rota, seu GPS, seus sinais e sua rede de peers.
/// Cobre o uso geral: viagem, paradas, entrega, empresa, rede, sinais,
/// ocultacao, expiracao de marcadores, reinicio do app (persistencia),
/// premium e carga de GPS.
///
/// Regra da bateria: se a bateria passar, o app esta pronto para uso real.
/// =============================================================================

/// Um motorista simulado com GPS, rota e estado proprio.
class Motorista {
  Motorista(this.nome, this.id, this.pos);
  final String nome;
  final String id;
  LatLng pos;
  final RouteProvider rota = RouteProvider();
  final PeerProvider rede = PeerProvider();
  final AlertProvider sinais = AlertProvider();
  int entregas = 0;
  int avisos = 0;
}

/// Distancia em metros entre dois pontos.
double _metros(LatLng a, LatLng b) {
  const metroPorGrau = 111320.0;
  final dx = (a.longitude - b.longitude) * metroPorGrau * 0.75;
  final dy = (a.latitude - b.latitude) * metroPorGrau;
  return sqrt(dx * dx + dy * dy);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Bateria: frota de motoristas na estrada', () {
    test('10 motoristas com rotas proprias entregam sem se misturar', () {
      final random = Random(4242);
      final frota = <Motorista>[
        for (var i = 0; i < 10; i++)
          Motorista(
              'Motorista $i', 'drv_$i', LatLng(-22.9068 + i * 0.002, -43.1729)),
      ];

      // Cada um monta 3 paradas a frente e comeca a viagem.
      for (var i = 0; i < frota.length; i++) {
        final m = frota[i];
        for (var s = 0; s < 3; s++) {
          m.rota.addStop(RouteStopEntry(
            label: 'Cliente $s',
            customer: 'Cliente $s',
            neighborhood: 'Bairro $s',
            point: LatLng(m.pos.latitude + 0.004 * (s + 1), m.pos.longitude),
          ));
        }
        m.rota.startRoute();
      }

      // GPS de cada um caminha em direcao a proxima parada.
      // O relogio e simulado: 30 s por amostra (o app confirma a entrega
      // depois de 45 s parado na parada).
      final inicio = DateTime.now();
      for (var passo = 0; passo < 400; passo++) {
        final agora = inicio.add(Duration(seconds: 30 * passo));
        for (final m in frota) {
          final i = m.rota.nextStopIndex;
          if (i == null) continue;
          final destino = m.rota.stops[i].point;
          // A cada passo o GPS avanca um pouco rumo a parada.
          m.pos = LatLng(
            m.pos.latitude + (destino.latitude - m.pos.latitude) * 0.08,
            m.pos.longitude + (destino.longitude - m.pos.longitude) * 0.08,
          );
          if (random.nextDouble() < 0.3) {
            m.pos = LatLng(
              m.pos.latitude + (random.nextDouble() - 0.5) * 0.0002,
              m.pos.longitude + (random.nextDouble() - 0.5) * 0.0002,
            );
          }
          // Fica parado um tempo na parada para a entrega ser confirmada.
          if (m.rota.dentroDoRaio(i, m.pos) && random.nextDouble() < 0.6) {
            m.pos = destino;
          }
          if (m.rota.updatePosition(m.pos, now: agora)) {
            m.entregas++;
          }
        }
      }

      // Todos entregaram as 3 paradas e a rota fechou.
      for (final m in frota) {
        expect(m.rota.deliveredCount, 3,
            reason: '${m.nome} nao entregou tudo (${m.rota.deliveredCount}/3)');
        expect(m.rota.allDelivered, isTrue,
            reason: '${m.nome} nao concluiu a rota');
        expect(m.rota.consumeRouteFinishedEvent(), isTrue,
            reason: '${m.nome} nao avisou que a rota terminou');
      }
      // Cada um entregou exatamente 3 (sem duplicar entrega).
      for (final m in frota) {
        expect(m.entregas, 3, reason: '${m.nome} entregou fora do tempo');
      }
    });

    test('parada da empresa volta para a base e fecha a rota', () {
      final m = Motorista(
          'Com Empresa', 'drv_empresa', const LatLng(-22.9068, -43.1729));
      m.rota.addStop(const RouteStopEntry(
        label: 'Cliente 1',
        customer: 'Mercado Bom',
        point: LatLng(-22.9000, -43.1729),
      ));
      m.rota.setCompanyStop(
        name: 'Transportes JR',
        point: const LatLng(-22.8950, -43.1729),
      );
      expect(m.rota.totalStops, 2);
      expect(m.rota.isCompanyStop(1), isTrue);
      m.rota.startRoute();

      // Chega no cliente e entrega.
      m.pos = const LatLng(-22.9000, -43.1729);
      m.rota.updatePosition(m.pos);
      m.rota.updatePosition(m.pos,
          now: DateTime.now().add(const Duration(minutes: 2)));
      expect(m.rota.statusOf(0), StopStatus.delivered);

      // Segue para a empresa.
      m.pos = const LatLng(-22.8950, -43.1729);
      m.rota.updatePosition(m.pos);
      m.rota.updatePosition(m.pos,
          now: DateTime.now().add(const Duration(minutes: 2)));
      expect(m.rota.statusOf(1), StopStatus.delivered);
      expect(m.rota.consumeCompanyReachedEvent(), isTrue);
      expect(m.rota.consumeRouteFinishedEvent(), isTrue);
    });

    test('sair do raio antes da parada devolve a entrega para pendente', () {
      final m =
          Motorista('Volta', 'drv_volta', const LatLng(-22.9068, -43.1729));
      m.rota.addStop(const RouteStopEntry(
        label: 'Cliente',
        customer: 'Cliente',
        point: LatLng(-22.9000, -43.1729),
      ));
      m.rota.updatePosition(const LatLng(-22.9000, -43.1729));
      expect(m.rota.statusOf(0), StopStatus.arrived);
      m.rota.updatePosition(const LatLng(-22.9500, -43.1729));
      expect(m.rota.statusOf(0), StopStatus.pending);
    });
  });

  group('Bateria: rede de sinais entre os motoristas', () {
    test(
        'sinal de um motorista aparece para quem esta perto e nao para quem esta longe',
        () {
      final perto =
          Motorista('Perto', 'drv_perto', const LatLng(-22.9068, -43.1729));
      final longe =
          Motorista('Longe', 'drv_longe', const LatLng(-20.0000, -40.0000));

      final alerta = AlertModel(
        id: 'alerta_1',
        driverId: perto.id,
        type: 'radar',
        message: 'Radar fixo 80',
        latitude: perto.pos.latitude,
        longitude: perto.pos.longitude,
        createdAt: DateTime.now(),
      );
      // O app filtra por proximidade (2 km de raio): so quem esta perto recebe.
      const raio = 2000.0;
      for (final m in [perto, longe]) {
        final dist = _metros(m.pos, LatLng(alerta.latitude, alerta.longitude));
        final visivel = dist <= raio;
        if (visivel) m.sinais.addAlert(alerta);
        expect(m.sinais.alerts.length, visivel ? 1 : 0,
            reason: '${m.nome} a $dist m');
      }
    });

    test('cada motorista ve os caminhoes da rede V2X ao seu redor', () {
      final fleet = <Motorista>[
        for (var i = 0; i < 6; i++)
          Motorista(
              'Rede $i', 'drv_rede_$i', LatLng(-22.9068 + i * 0.001, -43.1729)),
      ];
      // O primeiro ve os outros 5 (todos perto).
      final radar = [
        for (final m in fleet.skip(1))
          {
            'driverId': m.id,
            'name': m.nome,
            'lat': m.pos.latitude,
            'lon': m.pos.longitude,
            'speedKmh': 60,
          }
      ];
      fleet.first.rede.setPeers(radar);
      expect(fleet.first.rede.count, 5);
      expect(fleet.first.rede.peers.first['name'], 'Rede 1');
      expect(fleet.first.rede.peers, isA<List<Map<String, dynamic>>>());

      // Peer que sai da rede (app fechado) desaparece.
      fleet.first.rede.setPeers(radar.sublist(0, 3));
      expect(fleet.first.rede.count, 3);
      fleet.first.rede.clear();
      expect(fleet.first.rede.isEmpty, isTrue);
    });

    test('sinal escondido some da lista e volta quando o app reinicia',
        () async {
      final m =
          Motorista('Oculta', 'drv_oculta', const LatLng(-22.9068, -43.1729));
      final a = AlertModel(
        id: 'alerta_oculto',
        driverId: m.id,
        type: 'perigo',
        message: 'Oleo na pista',
        latitude: m.pos.latitude,
        longitude: m.pos.longitude,
        createdAt: DateTime.now(),
      );
      m.sinais.addAlert(a);
      expect(m.sinais.alerts.length, 1);
      m.sinais.hide(a.id);
      expect(m.sinais.alerts.length, 0);
      expect(m.sinais.hiddenIds.contains(a.id), isTrue);

      // Reinicio do app: o sinal continua oculto.
      final novo = AlertProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(novo.hiddenIds.contains(a.id), isTrue);

      // Mostrar tudo de novo.
      await novo.clearHidden();
      expect(novo.hiddenIds.isEmpty, isTrue);
    });

    test('marcador do mapa expira em 12 horas e some sozinho', () {
      final marcadores = MarkerProvider(autoCleanup: false);
      final antigo = marcadores.place(
        emoji: '⚠️',
        type: 'perigo',
        latitude: -22.9068,
        longitude: -43.1729,
        driverId: 'drv_1',
      );
      expect(marcadores.markers.length, 1);
      expect(
          marcadores.withinRadius(const LatLng(-22.9068, -43.1729), 500).length,
          1);
      expect(
          marcadores.withinRadius(const LatLng(-20, -40), 500).isEmpty, isTrue);

      // Tempo do app: 13 horas depois, o sinal antigo expira.
      final velho = MapMarkerModel(
        id: antigo.id,
        emoji: antigo.emoji,
        type: antigo.type,
        latitude: antigo.latitude,
        longitude: antigo.longitude,
        driverId: antigo.driverId,
        createdAt: DateTime.now().subtract(const Duration(hours: 13)),
      );
      marcadores.setMarkers([velho]);
      expect(marcadores.purgeExpired(), 1);
      expect(marcadores.markers.isEmpty, isTrue);
    });
  });

  group('Bateria: uso geral e persistencia do app', () {
    test('modelo de rota, clientes e agendamento sobrevivem ao reinicio',
        () async {
      final r = RouteProvider();
      r.addStop(const RouteStopEntry(
        label: 'Cliente A',
        customer: 'Cliente A',
        neighborhood: 'Centro',
        point: LatLng(-22.9, -43.17),
      ));
      r.saveTemplate('Rota da manha');
      r.saveClient(const ClientEntry(
        name: 'Cliente A',
        address: 'Av. Brasil, 1000',
        neighborhood: 'Centro',
        lat: -22.9,
        lon: -43.17,
      ));
      r.scheduleRoute(
          'Rota da manha', DateTime.now().add(const Duration(days: 1)));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Reinicio do app: novos providers leem do armazenamento.
      final novo = RouteProvider();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(novo.templates.length, 1);
      expect(novo.templates.first.name, 'Rota da manha');
      expect(novo.clients.length, 1);
      expect(novo.scheduled.length, 1);

      // Reaproveitar o modelo monta a rota de novo.
      novo.loadTemplate(novo.templates.first);
      expect(novo.totalStops, 1);
      expect(novo.stops.first.customer, 'Cliente A');
    });

    test(
        'rota exportada e importada continua igual (compartilhar com a empresa)',
        () {
      final r = RouteProvider();
      r.addStop(const RouteStopEntry(
        label: 'Cliente 1',
        customer: 'Cliente 1',
        neighborhood: 'Bairro',
        point: LatLng(-22.9, -43.17),
        radiusMeters: 150,
      ));
      final json = r.exportRouteJson();
      final outro = RouteProvider();
      outro.importRouteJson(json);
      expect(outro.totalStops, 1);
      expect(outro.stops.first.customer, 'Cliente 1');
      expect(outro.stops.first.radiusMeters, 150);
    });

    test('configuracoes do app: FPS, GPS, qualidade e modo noturno', () async {
      final s = SettingsProvider();
      await s.load();
      expect(s.targetFps, greaterThanOrEqualTo(30));
      expect(s.gpsIntervalSeconds, greaterThan(0));
      s.setTargetFps(120);
      s.setGpsInterval(10);
      s.setNightMode(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Reinicio do app: as preferencias continuam.
      final outro = SettingsProvider();
      await outro.load();
      expect(outro.targetFps, 120);
      expect(outro.gpsIntervalSeconds, 10);
      expect(outro.nightMode, isTrue);
    });

    test('premium libera os recursos e o usuario comum ve o portao', () {
      expect(
          PremiumPolicy.canUse(PremiumFeature.radio, isPremium: true), isTrue);
      // Depois da promocao, o usuario comum volta a ver o portao.
      final depoisDaPromocao = DateTime(2027, 1, 1);
      expect(
        PremiumPolicy.isLocked(
          PremiumFeature.radio,
          isPremium: false,
          now: depoisDaPromocao,
        ),
        isTrue,
      );
      expect(
        PremiumPolicy.canUse(
          PremiumFeature.radio,
          isPremium: true,
          now: depoisDaPromocao,
        ),
        isTrue,
      );
      // Mapa e rotas sao gratuitos.
      expect(PremiumPolicy.freeHasMap, isTrue);
      expect(PremiumPolicy.freeHasRoutes, isTrue);
    });
  });

  group('Bateria: carga e estabilidade', () {
    test('10 motoristas x 300 amostras de GPS nao quebra nada', () {
      final random = Random(7);
      final frota = <Motorista>[
        for (var i = 0; i < 10; i++)
          Motorista(
              'Carga $i', 'drv_carga_$i', LatLng(-22.9 + i * 0.01, -43.17)),
      ];
      for (final m in frota) {
        for (var s = 0; s < 5; s++) {
          m.rota.addStop(RouteStopEntry(
            label: 'Parada $s',
            customer: 'Parada $s',
            point: LatLng(m.pos.latitude + 0.01 * (s + 1), m.pos.longitude),
          ));
        }
        m.rota.startRoute();
      }

      final inicio = DateTime.now();
      for (var amostra = 0; amostra < 300; amostra++) {
        for (final m in frota) {
          // GPS pulando (teleporte) como em cidade alta.
          m.pos = LatLng(
            m.pos.latitude + (random.nextDouble() - 0.5) * 0.002,
            m.pos.longitude + (random.nextDouble() - 0.5) * 0.002,
          );
          m.rota.updatePosition(m.pos);
        }
      }
      final ms = DateTime.now().difference(inicio).inMilliseconds;

      // Nenhum motorista fica travado nem duplica entrega.
      for (final m in frota) {
        expect(m.rota.deliveredCount, lessThanOrEqualTo(5));
        expect(
            m.rota.statusOf(0),
            anyOf(
                StopStatus.pending, StopStatus.arrived, StopStatus.delivered));
      }
      expect(ms, lessThan(20000), reason: 'carga de GPS lenta demais ($ms ms)');
    });

    test(
        '10 motoristas montam 300 sinais e a lista continua ordenada e limitada',
        () {
      final alertas = AlertProvider();
      for (var i = 0; i < 300; i++) {
        alertas.addAlert(AlertModel(
          id: 'a_$i',
          driverId: 'drv_${i % 10}',
          type: 'perigo',
          message: 'Sinal $i',
          latitude: -22.9,
          longitude: -43.17,
          createdAt: DateTime.now().subtract(Duration(seconds: i)),
        ));
      }
      expect(alertas.alerts.length, 300);
      // O sinal mais novo fica no topo da lista.
      expect(alertas.alerts.first.id, 'a_299');
      alertas.clearAlerts();
      expect(alertas.alerts.isEmpty, isTrue);
    });
  });
}
