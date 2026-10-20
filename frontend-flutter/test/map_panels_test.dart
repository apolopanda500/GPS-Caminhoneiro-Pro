import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/data/models/alert_model.dart';
import 'package:gps_camioneiro_pro/providers/route_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/alerts_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/floating_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/route_table_panel.dart';

/// Regressao: nenhum painel pode devolver Positioned (o FloatingPanel ja
/// posiciona). Positioned aninhado quebra a tela do mapa em runtime.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget app(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => RouteProvider()),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('painel de sinais dentro do FloatingPanel nao estoura',
      (tester) async {
    await tester.pumpWidget(app(Stack(
      children: [
        FloatingPanel(
          id: 'alerts',
          child: AlertsPanel(
            alerts: [
              AlertModel(
                id: '1',
                driverId: 'drv_1',
                type: 'sinal',
                message: 'Curva perigosa',
                latitude: 0,
                longitude: 0,
                createdAt: DateTime.now(),
              ),
            ],
            onClose: () {},
          ),
        ),
      ],
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Sinais da estrada (1)'), findsOneWidget);
  });

  testWidgets('tabela de rotas dentro do FloatingPanel nao estoura',
      (tester) async {
    await tester.pumpWidget(app(Stack(
      children: [
        FloatingPanel(
          id: 'route',
          width: 320,
          height: 240,
          child: RouteTablePanel(
            onShowRoute: () {},
            onShare: () {},
            onStart: () {},
            onConfirmNext: () {},
            onClose: () {},
          ),
        ),
      ],
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Tabela de rotas'), findsOneWidget);
  });

  testWidgets('FloatingPanel minimiza ao ser solto na borda', (tester) async {
    await tester.pumpWidget(app(const Stack(
      children: [
        FloatingPanel(
          id: 'teste',
          initial: Offset(300, 200),
          minimizedChild: Icon(Icons.check, size: 20),
          child: SizedBox(width: 120, height: 60, child: Text('painel')),
        ),
      ],
    )));
    await tester.pumpAndSettle();
    expect(find.text('painel'), findsOneWidget);

    // arrasta para a borda esquerda
    final gesture = await tester.startGesture(const Offset(360, 230));
    await gesture.moveBy(const Offset(-340, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('painel'), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
