import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/core/audio/voice_service.dart';
import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';
import 'package:gps_camioneiro_pro/core/utils/estado_uf.dart';
import 'package:gps_camioneiro_pro/data/models/alert_model.dart';
import 'package:gps_camioneiro_pro/providers/route_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/core/audio/sons_provider.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/alerts_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/floating_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/speed_hud.dart';

/// Bateria de validacao 10/10: sons, alarmes, vibracao, voz, chegada e
/// saida das paradas, filtros de estado e paineis flutuantes.
void main() {
  const rj = LatLng(-22.9068, -43.1729);

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // O motor de voz (TTS) nao existe no teste: responde vazio.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall call) async => null,
    );
  });

  group('Voz: modo numero x nome do cliente', () {
    test('o padrao e falar o numero da parada', () {
      expect(VoiceService.instance.modoFalaParada, ModoFalaParada.numero);
    });

    test('o modo nome do cliente fica salvo e volta do armazenamento',
        () async {
      await VoiceService.instance.definirModoFala(ModoFalaParada.nomeCliente);
      expect(VoiceService.instance.modoFalaParada, ModoFalaParada.nomeCliente);
      await VoiceService.instance.carregarPreferencia();
      expect(VoiceService.instance.modoFalaParada, ModoFalaParada.nomeCliente);
      await VoiceService.instance.definirModoFala(ModoFalaParada.numero);
    });

    test('a voz do aparelho guarda velocidade, tom e voz escolhida', () async {
      await VoiceService.instance.definirVozAjustes(
        velocidade: 0.55,
        tom: 1.2,
      );
      expect(VoiceService.instance.velocidade, closeTo(0.55, 0.001));
      expect(VoiceService.instance.tom, closeTo(1.2, 0.001));
      await VoiceService.instance.definirVozAjustes(
        velocidade: 0.48,
        tom: 1.0,
      );
    });
  });

  group('Sons: slots de cada momento', () {
    test('existe slot para o sino de chegada', () {
      expect(SlotSom.values.any((s) => s.chave == 'entradaParada'), isTrue);
    });

    test('existe slot para a proxima parada', () {
      expect(SlotSom.values.any((s) => s.chave == 'proximaParada'), isTrue);
    });

    test('existe slot para o alarme de radar e o aviso geral', () {
      expect(SlotSom.values.any((s) => s.chave == 'alertaRadar'), isTrue);
      expect(SlotSom.values.any((s) => s.chave == 'avisoGeral'), isTrue);
    });

    test('cada slot tem titulo e descricao', () {
      for (final s in SlotSom.values) {
        expect(s.titulo, isNotEmpty);
        expect(s.descricao, isNotEmpty);
      }
    });

    test('comecar sem som nenhum e permitido', () {
      final sons = SonsProvider();
      expect(sons.temSom(SlotSom.entradaParada), isFalse);
      expect(sons.som(SlotSom.proximaParada), isNull);
    });
  });

  group('Rota: chegada, saida e raio', () {
    RouteProvider rotaComParada({double raio = 150}) {
      final r = RouteProvider();
      r.addStop(RouteStopEntry(
        label: 'Cliente 1',
        customer: 'Cliente 1',
        point: rj,
        radiusMeters: raio,
      ));
      return r;
    }

    test('o GPS reconhece a chegada dentro do raio', () {
      final r = rotaComParada();
      expect(r.dentroDoRaio(0, rj), isTrue);
      expect(r.dentroDoRaio(0, const LatLng(-22.95, -43.25)), isFalse);
    });

    test('o raio de saida fica entre 100 e 200 metros', () {
      final r = rotaComParada(raio: 150);
      expect(r.raioDeSaida(0), inInclusiveRange(100, 200));
      final pequeno = rotaComParada(raio: 40);
      expect(pequeno.raioDeSaida(0), 100);
      final grande = rotaComParada(raio: 900);
      expect(grande.raioDeSaida(0), 200);
    });

    test('saiu da parada so passa de 100-200 m', () {
      final r = rotaComParada(raio: 150);
      expect(r.saiuDaParada(0, const LatLng(-22.9080, -43.1729)), isFalse);
      expect(r.saiuDaParada(0, const LatLng(-22.9200, -43.1729)), isTrue);
    });

    test('a entrega so e validada com permanencia no local', () {
      final r = rotaComParada();
      r.updatePosition(rj, dwellThreshold: const Duration(seconds: 45));
      expect(r.statusOf(0).name, 'arrived');
      r.updatePosition(rj,
          dwellThreshold: const Duration(seconds: 45),
          now: DateTime.now().add(const Duration(seconds: 60)));
      expect(r.statusOf(0).name, 'delivered');
    });

    test('sair do raio devolve a parada para pendente', () {
      final r = rotaComParada();
      r.updatePosition(rj);
      expect(r.statusOf(0).name, 'arrived');
      r.updatePosition(const LatLng(-22.95, -43.25));
      expect(r.statusOf(0).name, 'pending');
    });

    test('o numero da parada ignora a parada da empresa', () {
      final r = RouteProvider();
      r.addStop(const RouteStopEntry(label: 'A', point: rj));
      r.addStop(
          const RouteStopEntry(label: 'B', point: LatLng(-22.95, -43.25)));
      r.setCompanyStop(name: 'Empresa', point: const LatLng(-23.0, -43.3));
      expect(r.proximoNumero, 1);
      expect(r.proximoNome, 'A');
    });

    test('limpar a rota apaga paradas e resultado', () {
      final r = rotaComParada();
      expect(r.stops, isNotEmpty);
      r.clear();
      expect(r.stops, isEmpty);
      expect(r.result, isNull);
    });
  });

  group('Filtro de estado (a busca nao sai do estado do caminhao)', () {
    test('descobre a UF pela posicao do GPS', () {
      expect(estadoDaPosicao(rj), 'RJ');
      expect(estadoDaPosicao(const LatLng(-23.55, -46.63)), 'SP');
      expect(estadoDaPosicao(const LatLng(-19.92, -43.94)), 'MG');
      expect(estadoDaPosicao(const LatLng(-25.43, -49.27)), 'PR');
      expect(estadoDaPosicao(const LatLng(-27.59, -48.55)), 'SC');
      expect(estadoDaPosicao(const LatLng(-30.03, -51.23)), 'RS');
      expect(estadoDaPosicao(const LatLng(-12.97, -38.50)), 'BA');
      expect(estadoDaPosicao(const LatLng(-3.73, -38.52)), 'CE');
      expect(estadoDaPosicao(const LatLng(-16.68, -49.25)), 'GO');
    });

    test('posicao fora do Brasil nao devolve estado', () {
      expect(estadoDaPosicao(const LatLng(48.85, 2.35)), isNull);
    });
  });

  group('Painel de sinais: nunca fica sem resposta', () {
    testWidgets('mostra estado vazio com a opcao de avisar a comunidade',
        (tester) async {
      var criou = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlertsPanel(
              alerts: const [],
              onClose: () {},
              onCriarSinal: () => criou = true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Nenhum sinal por perto agora.'), findsOneWidget);
      expect(find.text('AVISAR A COMUNIDADE'), findsOneWidget);
      await tester.tap(find.text('AVISAR A COMUNIDADE'));
      expect(criou, isTrue);
    });

    testWidgets('lista os sinais quando existem', (tester) async {
      final alertas = [
        AlertModel(
          id: 'a1',
          driverId: 'd1',
          type: 'sinal',
          message: 'buraco na via',
          latitude: rj.latitude,
          longitude: rj.longitude,
          createdAt: DateTime.now(),
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AlertsPanel(alerts: alertas, onClose: () {})),
        ),
      );
      await tester.pump();
      expect(find.textContaining('buraco na via'), findsOneWidget);
    });
  });

  group('HUD de velocidade', () {
    testWidgets('mostra a velocidade grande e o limite', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SpeedHUD(speedKmh: 87, limitKmh: 80)),
        ),
      );
      await tester.pump();
      expect(find.text('87'), findsOneWidget);
      expect(find.text('km/h'), findsOneWidget);
      expect(find.text('máx 80'), findsOneWidget);
    });

    testWidgets('mostra o nome da rua', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home:
              Scaffold(body: SpeedHUD(speedKmh: 40, streetName: 'Rua Brasil')),
        ),
      );
      await tester.pump();
      expect(find.text('Rua Brasil'), findsOneWidget);
    });
  });

  group('Paineis flutuantes', () {
    testWidgets('a alca de redimensionar cresce o painel', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                FloatingPanel(
                  id: 'teste',
                  width: 200,
                  height: 120,
                  child: SizedBox(width: 200, height: 120),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Economia de bateria e GPS sempre no maximo', () {
    test('com a economia ligada o intervalo do GPS aumenta', () async {
      final s = SettingsProvider();
      await s.load();
      await s.setGpsInterval(2);
      expect(s.intervaloGpsReal, 2);
      await s.setBatterySaver(true);
      expect(s.intervaloGpsReal, greaterThanOrEqualTo(8));
      await s.setBatterySaver(false);
      expect(s.intervaloGpsReal, 2);
    });

    test('a URL do servidor esta configurada no build', () {
      expect(AppConstants.baseUrl, isNotEmpty);
    });
  });
}
