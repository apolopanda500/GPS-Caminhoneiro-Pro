import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';
import 'package:gps_camioneiro_pro/providers/alert_provider.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/navigation_provider.dart';
import 'package:gps_camioneiro_pro/providers/route_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/providers/trip_provider.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/chat_panel.dart';

Widget _app(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ChangeNotifierProvider(create: (_) => AlertProvider()),
      ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
      ChangeNotifierProvider(create: (_) => RouteProvider()),
      ChangeNotifierProvider(create: (_) => TripProvider()),
      ChangeNotifierProvider(create: (_) => AudioProvider()),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
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

  testWidgets('chat abre, envia e nao estoura excecao', (tester) async {
    var enviados = 0;
    await tester.pumpWidget(_app(ChatPanel(
      driverId: 'drv_1',
      driverName: 'Teste',
      messages: const [
        {'driverName': 'Joao', 'message': 'Ola'},
      ],
      onSend: (_) => enviados++,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Ola'), findsOneWidget);

    // Digitar e enviar
    await tester.enterText(find.byType(TextField), 'Bom dia');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(enviados, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat com lista grande de mensagens nao estoura', (tester) async {
    final mensagens = List.generate(
        80, (i) => {'driverName': 'Motorista $i', 'message': 'Mensagem $i'});
    await tester.pumpWidget(_app(ChatPanel(
      driverId: 'drv_1',
      driverName: 'Teste',
      messages: mensagens,
      onSend: (_) {},
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('emoji do chat envia mensagem', (tester) async {
    var enviados = 0;
    await tester.pumpWidget(_app(ChatPanel(
      driverId: 'drv_1',
      driverName: 'Teste',
      messages: const [],
      onSend: (_) => enviados++,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🚨'));
    await tester.pump();
    expect(enviados, 1);
    expect(tester.takeException(), isNull);
  });
}
