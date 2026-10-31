import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationHandler {
  static Future<bool> requestPermissions() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Permissao REAL de localizacao em segundo plano (sempre).
  /// No Android 10+ o usuario precisa escolher "Permitir o tempo todo".
  static Future<bool> requestBackgroundLocation() async {
    final local = await Permission.location.request();
    if (!local.isGranted) return false;
    final sempre = await Permission.locationAlways.request();
    return sempre.isGranted;
  }

  /// Permissao de notificacoes (necessaria para o servico em primeiro plano).
  static Future<bool> requestNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
  }

  static Stream<Position> positionStream({
    int intervalMilliseconds = 100,
    bool highAccuracy = true,
    bool economia = false,
  }) {
    if (economia) {
      // Modo economia de bateria de verdade: GPS de baixo consumo, uma
      // posicao a cada 20 s e so quando andar 50 m. O suficiente para o
      // caminhao aparecer no mapa e a rota seguir, gastando o minimo.
      return Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 50,
          intervalDuration: const Duration(seconds: 20),
          forceLocationManager: true,
        ),
      );
    }
    return Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: highAccuracy
            ? LocationAccuracy.bestForNavigation
            : LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: Duration(milliseconds: intervalMilliseconds),
        forceLocationManager: false,
      ),
    );
  }
}
