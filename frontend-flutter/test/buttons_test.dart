import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/providers/alert_provider.dart';
import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/map_layers_provider.dart';
import 'package:gps_camioneiro_pro/providers/marker_provider.dart';
import 'package:gps_camioneiro_pro/providers/navigation_provider.dart';
import 'package:gps_camioneiro_pro/providers/peer_provider.dart';
import 'package:gps_camioneiro_pro/providers/route_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/providers/trip_provider.dart';
import 'package:gps_camioneiro_pro/views/auth/login_screen.dart';
import 'package:gps_camioneiro_pro/views/config/truck_setup_screen.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/alerts_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/route_table_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/speed_hud.dart';
import 'package:gps_camioneiro_pro/views/premium/payment_gate.dart';
import 'package:gps_camioneiro_pro/views/settings/appearance_screen.dart';
import 'package:gps_camioneiro_pro/views/settings/settings_screen.dart';

/// Tipos de botao/interacao que o app usa.
final _tiposDeBotao = <Type>[
  ElevatedButton,
  FilledButton,
  OutlinedButton,
  TextButton,
  IconButton,
  FloatingActionButton,
  Switch,
  SwitchListTile,
  Checkbox,
  InkWell,
  Slider,
];

/// Roda [telas] e clica em CADA botao, um por vez, recriando a tela entre os
/// cliques (para nao acumular navegacao). Falha se algum botao estourar
/// excecao.
Future<void> testarTodosOsBotoes(
  WidgetTester tester,
  List<Widget Function()> telas,
) async {
  for (final criaTela in telas) {
    // Descobre quantos botoes a tela tem (com a tela montada).
    await tester.pumpWidget(_app(criaTela()));
    await tester.pumpAndSettle();
    final total = _contarBotoes(tester);

    for (var i = 0; i < total; i++) {
      await tester.pumpWidget(_app(criaTela()));
      await tester.pumpAndSettle();
      final alvo = _botaoPorIndice(tester, i);
      if (alvo == null) continue;
      await tester.tap(alvo, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull,
          reason: 'Botao #$i da tela lancou excecao');
    }
  }
}

int _contarBotoes(WidgetTester tester) {
  var total = 0;
  for (final tipo in _tiposDeBotao) {
    total += tester.widgetList(find.byType(tipo)).length;
  }
  return total;
}

Finder? _botaoPorIndice(WidgetTester tester, int indice) {
  var restante = indice;
  for (final tipo in _tiposDeBotao) {
    final lista = find.byType(tipo);
    final n = lista.evaluate().length;
    if (restante < n) {
      return lista.at(restante);
    }
    restante -= n;
  }
  return null;
}

Widget _app(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ChangeNotifierProvider(create: (_) => AlertProvider()),
      ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
      ChangeNotifierProvider(create: (_) => MarkerProvider()),
      ChangeNotifierProvider(create: (_) => PeerProvider()),
      ChangeNotifierProvider(create: (_) => RouteProvider()),
      ChangeNotifierProvider(create: (_) => TripProvider()),
      ChangeNotifierProvider(create: (_) => AudioProvider()),
      ChangeNotifierProvider(create: (_) => MapLayersProvider()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'primeiro_acesso_v1': true,
      'permissoes_pedidas_v1': 'x',
      'audio_musica': false,
      'audio_estacao': false,
    });
  });

  testWidgets('todos os botoes da tela de login funcionam', (tester) async {
    await tester.pumpWidget(_app(const LoginScreen()));
    await tester.pumpAndSettle();
    expect(_contarBotoes(tester), greaterThanOrEqualTo(4));
    await testarTodosOsBotoes(tester, [() => const LoginScreen()]);
  });

  testWidgets('todos os botoes da configuracao do caminhao funcionam',
      (tester) async {
    await tester.pumpWidget(_app(const TruckSetupScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    await testarTodosOsBotoes(tester, [() => const TruckSetupScreen()]);
  });

  testWidgets('todos os botoes da tela de aparencia funcionam', (tester) async {
    await tester.pumpWidget(_app(const AppearanceScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    await testarTodosOsBotoes(tester, [() => const AppearanceScreen()]);
  });

  testWidgets('todos os botoes do painel de rotas funcionam', (tester) async {
    await tester.pumpWidget(_app(Scaffold(
      body: Stack(
        children: [
          RouteTablePanel(
            onShowRoute: () {},
            onShare: () {},
            onStart: () {},
            onConfirmNext: () {},
            onClose: () {},
          ),
        ],
      ),
    )));
    await tester.pumpAndSettle();
    expect(_contarBotoes(tester), greaterThanOrEqualTo(4));
    await tester.tap(find.byTooltip('Minimizar').first);
    await tester.pump();
    await tester.tap(find.byTooltip('Expandir').first);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('botoes do painel de sinais: minimizar e fechar', (tester) async {
    await tester.pumpWidget(_app(Scaffold(
      body: Stack(
        children: [
          AlertsPanel(
            alerts: const [],
            onClose: () {},
          ),
        ],
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Minimizar').first);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Expandir').first);
    await tester.pump();
    await tester.tap(find.byTooltip('Fechar painel').first);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('HUD de velocidade renderiza sem erro', (tester) async {
    await tester.pumpWidget(
        _app(const Scaffold(body: SpeedHUD(speedKmh: 88, limitKmh: 90))));
    await tester.pumpAndSettle();
    expect(find.text('88'), findsOneWidget);
    expect(find.text('km/h'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('botoes da tela de premium nao estouram', (tester) async {
    await tester
        .pumpWidget(_app(const PaymentGateScreen(driverId: 'drv_teste')));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    await testarTodosOsBotoes(
        tester, [() => const PaymentGateScreen(driverId: 'drv_teste')]);
  });

  testWidgets('botoes das configuracoes nao estouram', (tester) async {
    await tester.pumpWidget(_app(const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    await testarTodosOsBotoes(tester, [() => const SettingsScreen()]);
  });
}
