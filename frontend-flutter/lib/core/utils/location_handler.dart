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
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static Stream<Position> positionStream({
    int intervalSeconds = 2,
    bool highAccuracy = true,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: highAccuracy
            ? LocationAccuracy.bestForNavigation
            : LocationAccuracy.medium,
        distanceFilter: 3,
        intervalDuration: Duration(seconds: intervalSeconds),
        forceLocationManager: false,
      ),
    );
  }
}
