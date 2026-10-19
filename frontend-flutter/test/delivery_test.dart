import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';
import 'package:gps_camioneiro_pro/core/network/directions_service.dart';
import 'package:gps_camioneiro_pro/providers/route_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/chat_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/peer_profile_panel.dart';

RouteStopEntry _stop(String cliente, String bairro, double lat, double lon) {
  return RouteStopEntry(
    label: 'Rua $cliente',
    point: LatLng(lat, lon),
    neighborhood: bairro,
    customer: cliente,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RouteStopEntry', () {
    test('toJson/fromJson preserva cliente, bairro e raio', () {
      const s = RouteStopEntry(
        label: 'Rua das Flores, 120',
        point: LatLng(-22.6, -43.7),
        neighborhood: 'Sabugo',
        customer: 'Mercado Silva',
        note: '8 pedidos',
        radiusMeters: 150,
      );
      final back = RouteStopEntry.fromJson(s.toJson());
      expect(back.label, 'Rua das Flores, 120');
      expect(back.neighborhood, 'Sabugo');
      expect(back.customer, 'Mercado Silva');
      expect(back.note, '8 pedidos');
      expect(back.radiusMeters, 150);
      expect(back.point.latitude, closeTo(-22.6, 1e-9));
      expect(back.point.longitude, closeTo(-43.7, 1e-9));
    });

    test('fromJson usa defaults seguros', () {
      final s = RouteStopEntry.fromJson({'label': 'x'});
      expect(s.neighborhood, '');
      expect(s.customer, '');
      expect(s.radiusMeters, 120);
      expect(s.point.latitude, 0);
    });
  });

  group('RouteProvider entregas', () {
    late RouteProvider provider;

    setUp(() {
      provider = RouteProvider();
    });

    test('addStop numera clientes na ordem de inserção', () {
      provider.addStop(_stop('A', 'Sabugo', -22.60, -43.70));
      provider.addStop(_stop('B', 'Sabugo', -22.61, -43.71));
      provider.addStop(_stop('C', 'Centro', -22.62, -43.72));
      expect(provider.totalStops, 3);
      expect(provider.stops[0].orderLabel, '1');
      expect(provider.stops[2].orderLabel, '3');
      expect(provider.nextStopIndex, 0);
      expect(provider.nextStopLabel, contains('A'));
      expect(provider.nextStopLabel, contains('Sabugo'));
    });

    test('entrada no raio marca arrived e dwell confirma entregue', () {
      provider.addStop(_stop('A', 'Sabugo', -22.60, -43.70));
      final t0 = DateTime(2026, 10, 19, 10, 0, 0);
      provider.updatePosition(const LatLng(-22.6001, -43.7001), now: t0);
      expect(provider.statusOf(0), StopStatus.arrived);
      expect(provider.deliveredCount, 0);

      provider.updatePosition(
        const LatLng(-22.6001, -43.7001),
        now: t0.add(const Duration(seconds: 10)),
      );
      expect(provider.statusOf(0), StopStatus.arrived);

      provider.updatePosition(
        const LatLng(-22.6001, -43.7001),
        now: t0.add(const Duration(seconds: 60)),
      );
      expect(provider.statusOf(0), StopStatus.delivered);
      expect(provider.deliveredCount, 1);
      expect(provider.progress, 1.0);
      expect(provider.allDelivered, isTrue);
    });

    test('sair do raio antes do dwell volta para pendente', () {
      provider.addStop(_stop('A', 'Sabugo', -22.60, -43.70));
      final t0 = DateTime(2026, 10, 19, 10, 0, 0);
      provider.updatePosition(const LatLng(-22.60, -43.70), now: t0);
      expect(provider.statusOf(0), StopStatus.arrived);
      provider.updatePosition(const LatLng(-22.90, -43.90), now: t0.add(const Duration(seconds: 5)));
      expect(provider.statusOf(0), StopStatus.pending);
    });

    test('confirmação manual entrega e não duplica', () {
      provider.addStop(_stop('A', 'Sabugo', -22.60, -43.70));
      provider.addStop(_stop('B', 'Centro', -22.61, -43.71));
      provider.confirmDelivery(0);
      provider.confirmDelivery(0);
      expect(provider.deliveredCount, 1);
      expect(provider.nextStopIndex, 1);
      expect(provider.pendingCount, 1);
      provider.confirmDelivery(1);
      expect(provider.allDelivered, isTrue);
    });

    test('consumeCompletionEvent dispara apenas uma vez', () {
      provider.addStop(_stop('A', 'Sabugo', -22.60, -43.70));
      provider.confirmDelivery(0);
      expect(provider.consumeCompletionEvent(), isTrue);
      expect(provider.consumeCompletionEvent(), isFalse);
    });

    test('removeStopAt reordena e zera status', () {
      provider.addStop(_stop('A', 'Sabugo', -22.60, -43.70));
      provider.addStop(_stop('B', 'Centro', -22.61, -43.71));
      provider.confirmDelivery(0);
      provider.removeStopAt(0);
      expect(provider.totalStops, 1);
      expect(provider.deliveredCount, 0);
      expect(provider.stops.first.orderLabel, '1');
    });

    test('exporta e importa rota em JSON', () {
      provider.addStop(_stop('A', 'Sabugo', -22.60, -43.70));
      provider.addStop(_stop('B', 'Centro', -22.61, -43.71));
      final raw = provider.exportRouteJson();

      final outro = RouteProvider();
      outro.importRouteJson(raw);
      expect(outro.totalStops, 2);
      expect(outro.stops[1].customer, 'B');
      expect(outro.stops[1].neighborhood, 'Centro');
      expect(outro.deliveredCount, 0);
    });

    test('importar JSON inválido não altera paradas', () {
      provider.addStop(_stop('A', 'Sabugo', -22.60, -43.70));
      provider.importRouteJson('{"stops": []}');
      expect(provider.totalStops, 1);
    });

    test('clear remove paradas e resultado', () {
      provider.addStop(_stop('A', 'Sabugo', -22.60, -43.70));
      provider.clear();
      expect(provider.totalStops, 0);
      expect(provider.hasRoute, isFalse);
      expect(provider.allDelivered, isFalse);
    });
  });

  group('SettingsProvider atualização diária do mapa', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('mapa começa vencido e respeita 12 horas', () async {
      final s = SettingsProvider();
      await s.load();
      expect(s.mapUpdateDue(), isTrue);

      final base = DateTime(2026, 10, 19, 8, 0);
      await s.markMapUpdated(now: base);
      expect(s.mapUpdateDue(now: base.add(const Duration(hours: 11))), isFalse);
      expect(s.mapUpdateDue(now: base.add(const Duration(hours: 12))), isTrue);
    });

    test('virada de dia força atualização', () async {
      final s = SettingsProvider();
      await s.load();
      final base = DateTime(2026, 10, 19, 23, 0);
      await s.markMapUpdated(now: base);
      expect(s.mapUpdateDue(now: DateTime(2026, 10, 20, 0, 5)), isTrue);
    });

    test('cache version e label são gerados', () async {
      final s = SettingsProvider();
      await s.load();
      expect(s.mapCacheVersion, 0);
      expect(s.lastMapUpdateLabel, 'nunca atualizado');
      await s.markMapUpdated(now: DateTime(2026, 10, 19, 9, 5));
      expect(s.mapCacheVersion, greaterThan(0));
      expect(s.lastMapUpdateLabel, '19/10 09:05');
    });
  });

  group('SettingsProvider expediente e qualidade', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('inicia com expediente ativo e encerra pausando GPS', () async {
      final s = SettingsProvider();
      await s.load();
      expect(s.trackingEnabled, isTrue);

      await s.endDay();
      expect(s.trackingEnabled, isFalse);
      expect(s.dayStartedLabel, 'Expediente encerrado');

      await s.startDay(now: DateTime(2026, 10, 19, 6, 30));
      expect(s.trackingEnabled, isTrue);
      expect(s.dayStartedLabel, 'Em expediente desde 06:30');
    });

    test('perfis de qualidade ajustam FPS e 3D', () async {
      final s = SettingsProvider();
      await s.load();

      await s.setRenderQuality(RenderQuality.economy);
      expect(s.targetFps, 30);
      expect(s.buildings3d, isFalse);

      await s.setRenderQuality(RenderQuality.ultra);
      expect(s.targetFps, 120);
      expect(s.buildings3d, isTrue);
    });

    test('expediente encerrado persiste entre sessões', () async {
      final s = SettingsProvider();
      await s.load();
      await s.endDay();

      final s2 = SettingsProvider();
      await s2.load();
      expect(s2.trackingEnabled, isFalse);
    });
  });

  group('Constantes e ícones', () {
    test('estilos de rua claros e escuros são URLs do OpenFreeMap', () {
      expect(AppConstants.styleStreetsUrl, startsWith('https://tiles.openfreemap.org/styles/'));
      expect(AppConstants.styleStreetsLightUrl, startsWith('https://tiles.openfreemap.org/styles/'));
      expect(AppConstants.styleStreetsUrl, isNot(AppConstants.styleStreetsLightUrl));
    });

    test('lista de ícones de caminhão é única e não vazia', () {
      expect(AppConstants.truckIcons, isNotEmpty);
      expect(AppConstants.truckIcons.toSet().length, AppConstants.truckIcons.length);
      expect(AppConstants.truckIcons.first, '🚚');
    });
  });

  group('PeerProfilePanel', () {
    testWidgets('exibe ações de interação e dispara ligação', (tester) async {
      var ligou = false;
      var sinal = false;
      var vibrou = false;
      var mensagem = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PeerProfilePanel(
            peerTruck: const {
              'driverId': 'p1',
              'name': 'João',
              'truckIcon': '🚛',
              'cargoType': 'Carga Geral',
              'truckModel': 'Volvo FH',
            },
            currentDriverId: 'me',
            onSendReaction: (_) {},
            onOpenChat: () {},
            onMessage: () => mensagem = true,
            onSignal: () => sinal = true,
            onVibration: () => vibrou = true,
            onCall: () => ligou = true,
          ),
        ),
      ));

      expect(find.text('Mensagem'), findsOneWidget);
      expect(find.text('Sinal'), findsOneWidget);
      expect(find.text('Vibrar'), findsOneWidget);
      expect(find.text('Ligar'), findsOneWidget);
      expect(find.text('João'), findsOneWidget);

      await tester.tap(find.text('Ligar'));
      await tester.tap(find.text('Sinal'));
      await tester.tap(find.text('Vibrar'));
      await tester.tap(find.text('Mensagem'));

      expect(ligou, isTrue);
      expect(sinal, isTrue);
      expect(vibrou, isTrue);
      expect(mensagem, isTrue);
    });

    testWidgets('envia saudação rápida', (tester) async {
      String? enviado;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PeerProfilePanel(
            peerTruck: const {'driverId': 'p1', 'name': 'Maria'},
            currentDriverId: 'me',
            onSendReaction: (e) => enviado = e,
            onOpenChat: () {},
            onMessage: () {},
            onSignal: () {},
            onVibration: () {},
            onCall: () {},
          ),
        ),
      ));

      await tester.tap(find.text('👋'));
      expect(enviado, '👋');
    });
  });

  group('ChatPanel', () {
    testWidgets('emoji rápido envia mensagem', (tester) async {
      final enviadas = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ChatPanel(
            driverId: 'me',
            driverName: 'Eu',
            messages: const [],
            peerName: 'João',
            onSend: enviadas.add,
          ),
        ),
      ));

      expect(find.text('RÁDIO PX • João'), findsOneWidget);
      await tester.tap(find.text('🚨'));
      expect(enviadas, ['🚨']);
    });
  });

  group('RouteResult trânsito', () {
    RouteResult build({double duration = 600, double free = 600}) {
      return RouteResult(
        polyline: const [LatLng(0, 0)],
        distanceMeters: 1000,
        durationSeconds: duration,
        staticDurationSeconds: free,
        summary: 'Via',
      );
    }

    test('sem atraso mostra trânsito livre', () {
      final r = build();
      expect(r.trafficDelaySeconds, 0);
      expect(r.hasTrafficDelay, isFalse);
      expect(r.trafficText, 'Trânsito livre');
      expect(r.etaText, '10min');
    });

    test('calcula atraso em minutos', () {
      final r = build(duration: 900, free: 600);
      expect(r.trafficDelaySeconds, 300);
      expect(r.hasTrafficDelay, isTrue);
      expect(r.trafficText, '+5 min de trânsito');
    });

    test('ETA com horas', () {
      final r = build(duration: 3900, free: 3900);
      expect(r.etaText, '1h 5min');
    });

    test('provedor pesado é marcado', () {
      const r = RouteResult(
        polyline: [],
        distanceMeters: 0,
        durationSeconds: 0,
        summary: '',
        provider: 'ors-hgv',
        heavyVehicle: true,
      );
      expect(r.heavyVehicle, isTrue);
      expect(r.provider, 'ors-hgv');
    });
  });
}
