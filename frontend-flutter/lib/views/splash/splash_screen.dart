import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/core/audio/voice_service.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/utils/permission_service.dart';
import 'package:gps_camioneiro_pro/data/models/driver_model.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/views/auth/login_screen.dart';
import 'package:gps_camioneiro_pro/views/map/map_screen.dart';
import 'package:gps_camioneiro_pro/views/onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 1), _iniciar);
  }

  Future<void> _iniciar() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    unawaited(VoiceService.instance.carregarPreferencia());

    final primeiroAcesso = !prefs.containsKey('primeiro_acesso_v1');
    if (primeiroAcesso) {
      if (!mounted) return;
      await PermissionService.pedirComConfirmacao(context);
      await prefs.setBool('primeiro_acesso_v1', true);
    } else if (!prefs.containsKey('permissoes_pedidas_v1')) {
      if (!mounted) return;
      await PermissionService.pedirComConfirmacao(context);
    }
    if (!mounted) return;

    // Espera a sessao salva ser lida: sem isso o app pedia login toda vez.
    final auth = context.read<AuthProvider>();
    await auth.ensureLoaded();
    if (!mounted) return;

    final DriverModel? driver = auth.driver;
    final settings = context.read<SettingsProvider>();
    final perfilPronto = settings.perfilPronto || _perfilJaCriado(driver);

    final route = driver == null
        ? MaterialPageRoute<void>(builder: (_) => const LoginScreen())
        : !perfilPronto
            ? MaterialPageRoute<void>(builder: (_) => const OnboardingScreen())
            : MaterialPageRoute<void>(
                builder: (_) => MapScreen(
                  driverId: driver.driverId,
                  driverName: driver.name ?? 'Motorista',
                ),
              );
    if (!mounted) return;
    Navigator.pushReplacement(context, route);
  }

  /// Perfil ja configurado no servidor (mesmo que a flag local nao exista,
  /// por exemplo depois de atualizar o app).
  bool _perfilJaCriado(DriverModel? driver) {
    if (driver == null) return false;
    if ((driver.name ?? '').trim().isEmpty) return false;
    if (driver.role == 'ajudante') return true;
    return (driver.truckModel ?? '').isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kDarkBlack,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_transit, size: 100, color: kEmergencyRed),
            SizedBox(height: 24),
            Text(
              'GPS CAMINHONEIRO PRO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Rede Veicular V2X • Chat da Estrada • Alertas em Tempo Real',
              textAlign: TextAlign.center,
              style: TextStyle(color: kLightText, fontSize: 14),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: kEmergencyRed),
          ],
        ),
      ),
    );
  }
}
