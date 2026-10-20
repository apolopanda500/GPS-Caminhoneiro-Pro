import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/navigation_provider.dart';
import 'package:gps_camioneiro_pro/providers/alert_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/providers/marker_provider.dart';
import 'package:gps_camioneiro_pro/providers/map_layers_provider.dart';
import 'package:gps_camioneiro_pro/providers/peer_provider.dart';
import 'package:gps_camioneiro_pro/providers/trip_provider.dart';
import 'package:gps_camioneiro_pro/providers/route_provider.dart';
import 'package:gps_camioneiro_pro/providers/group_provider.dart';
import 'package:gps_camioneiro_pro/providers/weather_provider.dart';
import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';
import 'package:gps_camioneiro_pro/core/audio/voice_service.dart';
import 'package:gps_camioneiro_pro/core/audio/sons_provider.dart';
import 'package:gps_camioneiro_pro/views/splash/splash_screen.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final audio = AudioProvider();
  final sons = SonsProvider();
  audio.tocadorEntrada = () => sons.tocar(SlotSom.entradaParada);
  audio.carregarPreferencias();
  sons.carregar();
  // A voz abaixa o radio enquanto fala e devolve o volume depois.
  VoiceService.instance.antesDeFalar = () => audio.abaixarRadio();
  VoiceService.instance.depoisDeFalar = () => audio.restaurarRadio();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadSession()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
        ChangeNotifierProvider(create: (context) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => MarkerProvider()),
        ChangeNotifierProvider(create: (_) => PeerProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()..load()),
        ChangeNotifierProvider(create: (_) => RouteProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => MapLayersProvider()),
        ChangeNotifierProvider.value(value: audio),
        ChangeNotifierProvider.value(value: sons),
      ],
      child: const GpsCamioneiroProApp(),
    ),
  );
}

class GpsCamioneiroProApp extends StatelessWidget {
  const GpsCamioneiroProApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final accent = settings.overlayColor;
    return MaterialApp(
      title: 'GPS Caminhoneiro Pro',
      debugShowCheckedModeBanner: false,
      theme: appLightTheme(accent: accent),
      darkTheme: appTheme(accent: accent),
      themeMode:
          settings.nightMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
