import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/data/models/driver_model.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/views/auth/login_screen.dart';
import 'package:gps_camioneiro_pro/views/map/map_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      DriverModel? driver;
      try {
        driver = context.read<AuthProvider>().driver;
      } catch (_) {
        driver = null;
      }
      final currentDriver = driver;
      final route = currentDriver == null
          ? MaterialPageRoute<void>(builder: (_) => const LoginScreen())
          : MaterialPageRoute<void>(
              builder: (_) => MapScreen(
                driverId: currentDriver.driverId,
                driverName: currentDriver.name ?? 'Motorista',
              ),
            );
      Navigator.pushReplacement(context, route);
    });
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
              'GPS CAMIONEIRO PRO',
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
