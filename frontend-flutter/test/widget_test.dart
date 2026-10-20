import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/alert_provider.dart';
import 'package:gps_camioneiro_pro/providers/navigation_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/views/auth/login_screen.dart';
import 'package:gps_camioneiro_pro/views/splash/splash_screen.dart';
import 'package:gps_camioneiro_pro/views/config/truck_setup_screen.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/speed_hud.dart';

Widget _wrap(Widget child, {SettingsProvider? settings}) {
  final s = settings ?? SettingsProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ChangeNotifierProvider(create: (_) => AlertProvider()),
      ChangeNotifierProvider.value(value: s),
    ],
    child: MaterialApp(home: child),
  );
}

/// Cria um SettingsProvider com o perfil ja configurado (login vai direto
/// para a configuracao do caminhao, sem passar pelo onboarding).
Future<SettingsProvider> _perfilPronto() async {
  final s = SettingsProvider();
  await s.load();
  await s.setPerfilConfigurado(true);
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'primeiro_acesso_v1': true,
      'permissoes_pedidas_v1': 'x',
      'audio_musica': false,
      'settings.perfilPronto': true,
    });
  });

  testWidgets('SpeedHUD renderiza a velocidade', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SpeedHUD(speedKmh: 82))));
    expect(find.text('82 km/h'), findsOneWidget);
    expect(find.byIcon(Icons.speed), findsOneWidget);
  });

  testWidgets('SplashScreen mostra marca e indicador', (tester) async {
    await tester.pumpWidget(_wrap(const SplashScreen()));
    expect(find.text('GPS CAMINHONEIRO PRO'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('SplashScreen navega para o Login após 2s', (tester) async {
    await tester.pumpWidget(_wrap(const SplashScreen()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('LoginScreen renderiza campos e botão', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('ENTRAR'), findsOneWidget);
    expect(find.text('Criar conta'), findsOneWidget);
    expect(find.text('CANCELAR'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('LoginScreen CANCELAR limpa os campos', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.enterText(find.byType(TextField).at(0), 'motorista@teste.com');
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.tap(find.text('CANCELAR'));
    await tester.pump();
    final email = tester.widget<TextField>(find.byType(TextField).at(0));
    final senha = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(email.controller!.text, isEmpty);
    expect(senha.controller!.text, isEmpty);
  });

  testWidgets('LoginScreen abre diálogo de cadastro funcional', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();
    expect(find.text('CADASTRAR'), findsOneWidget);
    expect(find.text('Nome do motorista'), findsOneWidget);
  });

  testWidgets('LoginScreen autentica (offline) e vai para Configurar Caminhão', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const LoginScreen(), settings: await _perfilPronto()));

    await tester.enterText(find.byType(TextField).at(0), 'motorista@teste.com');
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.tap(find.text('ENTRAR'));
    await tester.pumpAndSettle();

    expect(find.text('Configurar Caminhão'), findsOneWidget);
    expect(find.text('Salvar e Iniciar Navegação V2X'), findsOneWidget);
  });

  testWidgets('LoginScreen abre o diálogo de recuperar senha', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    expect(find.text('Esqueci minha senha'), findsOneWidget);
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();
    expect(find.text('Recuperar senha'), findsOneWidget);
    expect(find.text('ENVIAR CÓDIGO'), findsOneWidget);
  });

  testWidgets('TruckSetupScreen renderiza todos os campos e HAZMAT', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const TruckSetupScreen()));
    expect(find.text('DADOS DO MOTORISTA'), findsOneWidget);
    expect(find.text('Altura (m)'), findsOneWidget);
    expect(find.text('Carga perigosa (HAZMAT)'), findsOneWidget);
    expect(find.text('Salvar e Iniciar Navegação V2X'), findsOneWidget);
  });
}
