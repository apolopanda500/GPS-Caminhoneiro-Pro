class AppConstants {
  // Valores injetados no build: --dart-define-from-file=keys.json
  // Exemplo em keys.example.json. Nunca commite o keys.json.
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://seu-servidor.onrender.com',
  );
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: baseUrl,
  );

  // Enquanto a URL acima não for configurada, o app roda em modo local/offline.
  static const bool serverConfigured = baseUrl != 'https://seu-servidor.onrender.com';

  // Google Routes API (trânsito em tempo real + ETA).
  static const String googleDirectionsApiKey =
      String.fromEnvironment('GOOGLE_ROUTES_KEY', defaultValue: '');
  static const bool directionsConfigured = googleDirectionsApiKey != '';

  // OpenRouteService: rota específica para caminhões (altura, peso, eixos, HAZMAT).
  // https://openrouteservice.org/dev/#/signup
  static const String openRouteServiceApiKey =
      String.fromEnvironment('ORS_KEY', defaultValue: '');
  static const bool orsConfigured = openRouteServiceApiKey != '';

  // Estilos MapLibre (camera 3D: rotacao e inclinacao).
  static const String styleSatellite = 'assets/map_styles/style_satellite.json';
  // Estilo vetorial da OpenFreeMap (gratuito, sem chave, atualizado semanalmente).
  static const String styleStreetsUrl = 'https://tiles.openfreemap.org/styles/dark';
  static const String styleStreetsLightUrl = 'https://tiles.openfreemap.org/styles/bright';

  // Icones de caminhao que cada motorista escolhe para si.
  static const List<String> truckIcons = [
    '🚚', '🚛', '🚜', '🛻', '🚐', '🚌',
    '🐂', '🐎', '🦅', '🐺', '🦁', '🐉',
    '⭐', '🔥', '⚡', '🛡️', '💀', '👑',
  ];

  static const int alertRadiusMeters = 2000;
  static const int chatRadiusMeters = 5000;

  static const List<String> alertTypes = [
    'texto_livre',
    'radar',
    'ponte_baixa',
    'policia',
    'balanca',
    'perigo',
  ];

  static const List<String> roadEmojis = ["👋", "👍", "☕", "⚠️"];

  // Sinais/emojis no mapa são TEMPORÁRIOS: expiram e o mapa é limpo sozinho.
  static const Duration markerTtl = Duration(hours: 12);
  static const Duration markerCleanupInterval = Duration(minutes: 5);
}
