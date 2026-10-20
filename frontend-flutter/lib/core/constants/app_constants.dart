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

  // Chave do Google restrita para Android exige o pacote e o SHA-1 do
  // certificado de assinatura. Informe o SHA-1 em keys.json
  // (APP_ANDROID_CERT_SHA1) para a chave Android-restrita funcionar.
  static const String androidPackage = String.fromEnvironment(
    'APP_ANDROID_PACKAGE',
    defaultValue: 'com.gpscamioneiro.gps_camioneiro_pro',
  );
  static const String androidCertSha1 =
      String.fromEnvironment('APP_ANDROID_CERT_SHA1', defaultValue: '');

  // OpenRouteService: rota específica para caminhões (altura, peso, eixos, HAZMAT).
  // https://openrouteservice.org/dev/#/signup
  static const String openRouteServiceApiKey =
      String.fromEnvironment('ORS_KEY', defaultValue: '');
  static const bool orsConfigured = openRouteServiceApiKey != '';

  // TomTom: camada de transito em tempo real (flow) do mundo todo.
  // Chave gratuita: https://developer.tomtom.com/user/register (2500/dia).
  static const String tomTomTrafficApiKey =
      String.fromEnvironment('TOMTOM_TRAFFIC_KEY', defaultValue: '');
  static const bool trafficConfigured = tomTomTrafficApiKey != '';

  // IA real do Assistente da Estrada (Google Gemini, nivel gratuito).
  // Chave: https://aistudio.google.com/apikey  ->  keys.json: GEMINI_API_KEY
  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String geminiModel = String.fromEnvironment(
      'GEMINI_MODEL',
      defaultValue: 'gemini-3-flash-preview');
  static const bool iaConfigured = geminiApiKey != '';

  // Tipos de ajuda do perfil "ajudante".
  static const List<String> helperTypes = [
    'Ajuda com carga',
    'Mecânica / pneus',
    'Direção na rota',
    'Abastecimento',
    'Alimentação e descanso',
    'Borracharia',
    'Guincho / socorro',
  ];

  // Ícones de pessoa para o perfil "ajudante".
  static const List<String> helperIcons = [
    '🧑‍🔧', '🧑‍🚒', '🧑‍✈️', '👷', '🙋', '🧑‍🏭', '🛠️', '🤝',
  ];

  // Estilos MapLibre (camera 3D: rotacao e inclinacao).
  static const String styleSatellite = 'assets/map_styles/style_satellite.json';
  // Estilos raster locais (funcionam offline do CDN de estilo e nunca ficam brancos).
  static const String styleStreetsLight = 'assets/map_styles/style_streets_light.json';
  static const String styleStreetsDark = 'assets/map_styles/style_streets_dark.json';
  // Estilo vetorial da OpenFreeMap (detalhado, com predios 3D).
  static const String styleStreetsUrl = 'https://tiles.openfreemap.org/styles/dark';
  static const String styleStreetsLightUrl = 'https://tiles.openfreemap.org/styles/bright';

  // Icones de caminhao que cada motorista escolhe para si.
  static const List<String> truckIcons = [
    '🚚', '🚛', '🚜', '🛻', '🚐', '🚙', '🚕', '🚌',
    '🚎', '🚔', '🚑', '🚒', '🛵', '🏍️', '🚲', '🛴',
    '🚂', '🚆', '✈️', '🚁', '🛺', '🐂', '🐎', '🦅',
    '🐺', '🦁', '🐉', '⭐', '🔥', '⚡', '🛡️', '💀',
    '👑', '😎', '🫡',
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
    'pedagio',
    'acidente',
    'obstrucao',
    'zmrc',
    'descanso',
    'estacionamento',
    'combustivel',
    'restaurante',
    'borracharia',
    'ponto_apoio',
    'serra',
    'curva',
    'fiscalizacao',
  ];

  // Emoji oficial de cada tipo de aviso/ponto (usado no mapa e nas listas).
  static const Map<String, String> alertTypeEmoji = {
    'texto_livre': '💬',
    'radar': '📷',
    'ponte_baixa': '🌉',
    'policia': '🚓',
    'balanca': '⚖️',
    'perigo': '⚠️',
    'pedagio': '🧾',
    'acidente': '🚨',
    'obstrucao': '🚧',
    'zmrc': '🚫',
    'descanso': '🛏️',
    'estacionamento': '🅿️',
    'combustivel': '⛽',
    'restaurante': '🍽️',
    'borracharia': '🛞',
    'ponto_apoio': '🏕️',
    'serra': '⛰️',
    'curva': '↩️',
    'fiscalizacao': '👮',
  };

  static String emojiForType(String type) => alertTypeEmoji[type] ?? '⚠️';

  static const List<String> roadEmojis = [
    '👋', '👍', '☕', '⚠️', '🚧', '🚦', '🚸', '🛑', '⛔', '🅿️', '⛽', '📍', '🚜',
  ];

  // Sinais/emojis no mapa são TEMPORÁRIOS: expiram e o mapa é limpo sozinho.
  static const Duration markerTtl = Duration(hours: 12);
  static const Duration markerCleanupInterval = Duration(minutes: 5);
}
