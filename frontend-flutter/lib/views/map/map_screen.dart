import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';
import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';
import 'package:gps_camioneiro_pro/core/audio/sons_provider.dart';
import 'package:gps_camioneiro_pro/core/audio/voice_service.dart';
import 'package:gps_camioneiro_pro/core/premium/premium_policy.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/network/socket_client.dart';
import 'package:gps_camioneiro_pro/core/network/speed_limit_service.dart';
import 'package:gps_camioneiro_pro/core/network/geocoding_service.dart';
import 'package:gps_camioneiro_pro/core/network/network_status_service.dart';
import 'package:gps_camioneiro_pro/data/models/alert_model.dart';
import 'package:gps_camioneiro_pro/data/models/map_marker_model.dart';
import 'package:gps_camioneiro_pro/data/models/trip_model.dart';
import 'package:gps_camioneiro_pro/core/utils/location_handler.dart';
import 'package:gps_camioneiro_pro/core/utils/confirm.dart';
import 'package:gps_camioneiro_pro/core/database/local_cache.dart';
import 'package:gps_camioneiro_pro/providers/alert_notifier.dart';
import 'package:gps_camioneiro_pro/providers/alert_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/providers/marker_provider.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/weather_provider.dart';
import 'package:gps_camioneiro_pro/providers/peer_provider.dart';
import 'package:gps_camioneiro_pro/providers/trip_provider.dart';
import 'package:gps_camioneiro_pro/providers/route_provider.dart';
import 'package:gps_camioneiro_pro/providers/group_provider.dart';
import 'package:gps_camioneiro_pro/providers/map_layers_provider.dart';
import 'package:gps_camioneiro_pro/views/auth/login_screen.dart';
import 'package:gps_camioneiro_pro/views/map/utils/map_icons.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/report_dialog.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/speed_hud.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/street_view_screen.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/marker_dialog.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/street_search_sheet.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/chat_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/peer_profile_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/route_planner_sheet.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/route_table_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/alerts_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/assistant_sheet.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/map_controls_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/weather_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/radio_fab.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/radio_sheet.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/groups_sheet.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/floating_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/fps_overlay.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/map_menu_sheet.dart';
import 'package:gps_camioneiro_pro/views/history/travel_history_screen.dart';
import 'package:gps_camioneiro_pro/views/contacts/contacts_screen.dart';
import 'package:gps_camioneiro_pro/views/settings/settings_screen.dart';
import 'package:gps_camioneiro_pro/views/profile/profile_screen.dart';
import 'package:gps_camioneiro_pro/views/premium/payment_gate.dart';

class MapScreen extends StatefulWidget {
  final String driverId;
  final String driverName;
  const MapScreen(
      {super.key, required this.driverId, this.driverName = 'Motorista'});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _fallbackCenter = LatLng(-23.55052, -46.633308);

  final SocketClient _socket = SocketClient();
  final List<AlertModel> _activeAlerts = [];
  final List<Map<String, dynamic>> _peerTrucks = [];
  final List<Map<String, dynamic>> _chatMessages = [];

  StreamSubscription? _positionSubscription;
  ml.MapLibreMapController? _mapController;

  String? _styleJsonSat;
  String? _styleJsonStreetsLight;
  bool _styleLoaded = false;
  Set<String> _hiddenIdsSnapshot = {};
  bool _alertProviderHooked = false;
  final Set<String> _imagesAdded = {};

  LatLng _center = _fallbackCenter;
  LatLng? _currentPosition;
  double _zoom = 14;
  double _bearing = 0;
  Timer? _styleFallbackTimer;
  final NetworkStatusService _network = NetworkStatusService();
  StreamSubscription<NetKind>? _networkSub;
  double _speedKmh = 0;

  bool _is3d = false;
  bool _modoEscolherEmpresa = false;
  String _nomeEmpresaPendente = '';
  bool _uiExpanded = true;
  bool _alertsPanelClosed = false;
  bool _routePanelClosed = false;
  bool _chatAberto = false;
  String? _chatPeerName;
  String? _chatPeerId;
  bool _sideRailOpen = false;

  MapLayerMode _layerMode = MapLayerMode.satellite;
  final SpeedLimitService _speedLimitService = SpeedLimitService();
  int? _speedLimitKmh;
  String? _streetName;
  bool _overSpeedWarned = false;
  DateTime _lastSpeedLimitCheck = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _isSatellite => _layerMode == MapLayerMode.satellite;
  bool get _isDetailed => _layerMode == MapLayerMode.detailed;

  double get _contentLeft => 16;
  bool _settingsApplied = false;
  MapLayerMode? _appliedLayer;
  bool _peerBubbleOpen = false;

  MarkerProvider? _markerProvider;
  RouteProvider? _routeProvider;
  SettingsProvider? _settingsProvider;
  TripProvider? _tripProvider;

  DateTime? _tripStart;
  LatLng? _tripStartPos;
  LatLng? _lastTripPos;
  double _tripDistanceMeters = 0;
  RenderQuality? _appliedQuality;
  double _tripMaxSpeed = 0;
  double _tripSpeedSum = 0;
  int _tripSpeedSamples = 0;

  @override
  void initState() {
    super.initState();
    _carregarEstilos();
    _initRealtimeSocket();
    _startLocationStream();
    // No mapa a musica de entrada para (so toca no splash e no login).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AudioProvider>().pararMusica();
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _atualizarMapaSeNecessario());
  }

  Future<void> _atualizarMapaSeNecessario() async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    if (!settings.mapUpdateDue()) return;
    await settings.markMapUpdated();
    if (!mounted) return;
    if (_styleLoaded) {
      _mapController?.setStyle(_styleAtual);
    }
    _showSnackBar('Mapa atualizado com as vias mais recentes.');
  }

  Future<void> _carregarEstilos() async {
    final sat = await rootBundle.loadString(AppConstants.styleSatellite);
    final light = await rootBundle.loadString(AppConstants.styleStreetsLight);
    if (!mounted) return;
    setState(() {
      _styleJsonSat = sat;
      _styleJsonStreetsLight = light;
    });
  }

  String get _styleAtual {
    // O mapa SEMPRE fica claro: o modo noturno affects so a interface
    // (barras, botoes e paineis), nunca o mapa.
    if (_isSatellite) return _styleJsonSat ?? '';
    if (_isDetailed) {
      final settings = context.read<SettingsProvider>();
      final version = settings.mapCacheVersion;
      const base = AppConstants.styleStreetsLightUrl;
      return version == 0 ? base : '$base?v=$version';
    }
    return _styleJsonStreetsLight ?? '';
  }

  String get _truckIcon =>
      context.read<AuthProvider>().driver?.truckIcon ?? '🚚';

  void _initRealtimeSocket() {
    _socket.connectToServer(
      driverId: widget.driverId,
      isPremium: context.read<AuthProvider>().driver?.isPremium ?? false,
      name: widget.driverName,
      truckIcon: _truckIcon,
    );
    _socket.joinTruckNetwork(
      driverId: widget.driverId,
      name: widget.driverName,
      truckIcon: _truckIcon,
    );

    _socket.onConnectionChange((connected) {
      if (!mounted) return;
      setState(() {});
    });

    _socket.onRoadValidationAlerts((data) {
      if (!mounted) return;
      if (data is List && data.isNotEmpty) {
        final alerts = data
            .map((e) => AlertModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        setState(() {
          _adicionarAlerts(alerts);
        });
        _renderMarkers();
      }
    });

    _socket.onReceiveAlertRealtime((data) {
      if (!mounted) return;
      final alert = AlertModel.fromJson(Map<String, dynamic>.from(data));
      bool novo = false;
      setState(() {
        novo = _adicionarAlerts([alert]);
      });
      if (!novo) return;
      LocalCache.saveAlertCache(Map<String, dynamic>.from(data))
          .catchError((_) {});
      _dispararAlarme(alert.type);
      _showSnackBar(
          '⚠️ Novo aviso na via: ${alert.message ?? 'Caminhoneiro alerta!'}');
      _renderMarkers();
    });

    _socket.onTrucksRadarUpdate((data) {
      if (!mounted) return;
      if (data is List) {
        final peers = List<Map<String, dynamic>>.from(data);
        setState(() {
          _peerTrucks
            ..clear()
            ..addAll(peers);
        });
        context.read<PeerProvider>().setPeers(peers);
        _renderMarkers();
      }
    });

    _socket.onReceiveChatMessage((data) {
      if (!mounted) return;
      final msg = Map<String, dynamic>.from(data);
      setState(() {
        _chatMessages.add(msg);
      });
    });

    _socket.onReceiveTruckReaction((data) {
      if (!mounted) return;
      if (data['targetDriverId'] == widget.driverId) {
        _exibirAnimacaoEmojiNaTela(data['fromName'], data['emoji']);
      }
    });

    _socket.onReceivePeerAlert((data) {
      if (!mounted) return;
      if (data['targetDriverId'] != widget.driverId) return;
      if (data['fromDriverId'] == widget.driverId) return;
      _handlePeerAlert(Map<String, dynamic>.from(data));
    });

    _socket.onReceiveSharedRoute((data) {
      if (!mounted) return;
      _handleSharedRoute(Map<String, dynamic>.from(data));
    });

    _socket.onReceiveGroupInvite((data) {
      if (!mounted) return;
      _abrirConviteGrupo(Map<String, dynamic>.from(data));
    });
  }

  /// Convite de grupo recebido: Aceptar (entra via REST) ou ignorar.
  void _abrirConviteGrupo(Map<String, dynamic> data) {
    final groupId = data['groupId']?.toString() ?? '';
    final groupName = data['groupName']?.toString() ?? 'grupo';
    if (groupId.isEmpty) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Convite de grupo'),
        content: Text(
            '${data['fromName'] ?? 'Um caminhoneiro'} te convidou para o comboio "$groupName".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ignorar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              final grupos = context.read<GroupProvider>();
              grupos.join(
                  groupId: groupId,
                  driverId: widget.driverId,
                  auth: context.read<AuthProvider>().authHeaders);
              _showSnackBar('Entrando no grupo $groupName...');
            },
            child: const Text('Aceitar'),
          ),
        ],
      ),
    );
  }

  void _handleSharedRoute(Map<String, dynamic> data) {
    if (data['fromDriverId'] == widget.driverId) return;
    final raw = (data['routeJson'] ?? '').toString();
    if (raw.isEmpty) return;
    final from = (data['fromName'] ?? 'Caminhoneiro').toString();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Rota recebida de $from'),
        content:
            const Text('Deseja importar as paradas e os clientes desta rota?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('DEPOIS'),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                context.read<RouteProvider>().importRouteJson(raw);
                Navigator.pop(dialogContext);
                _showSnackBar('Rota importada. Confira as paradas no mapa.');
                _mostrarRota();
              } catch (_) {
                Navigator.pop(dialogContext);
                _showSnackBar('Não foi possível importar a rota.');
              }
            },
            child: const Text('IMPORTAR'),
          ),
        ],
      ),
    );
  }

  void _handlePeerAlert(Map<String, dynamic> alert) {
    final from = (alert['fromName'] ?? 'Caminhoneiro').toString();
    final kind = (alert['kind'] ?? 'signal').toString();
    switch (kind) {
      case 'call':
        _mostrarChamadaRecebida(alert);
        break;
      case 'vibration':
        HapticFeedback.heavyImpact();
        _showSnackBar('$from pediu atenção por vibração.');
        break;
      case 'signal':
      default:
        HapticFeedback.vibrate();
        _dispararAlarme('danger');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Sinal de $from'),
            content: Text(
              (alert['message'] ?? '').toString().isEmpty
                  ? 'Alerta de estrada recebido. Reduza e confirme a via.'
                  : alert['message'].toString(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ENTENDI'),
              ),
            ],
          ),
        );
        break;
    }
  }

  void _mostrarChamadaRecebida(Map<String, dynamic> alert) {
    final from = (alert['fromName'] ?? 'Caminhoneiro').toString();
    _dispararAlarme('danger');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ligação de $from'),
        content:
            const Text('Chamada de rádio PX na rede de caminhões próxima.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _socket.sendPeerAlert(
                fromDriverId: widget.driverId,
                fromName: widget.driverName,
                targetDriverId: alert['fromDriverId'].toString(),
                kind: 'signal',
                message: 'Chamada recusada, estou dirigindo.',
              );
            },
            child: const Text('RECUSAR'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _socket.sendPeerAlert(
                fromDriverId: widget.driverId,
                fromName: widget.driverName,
                targetDriverId: alert['fromDriverId'].toString(),
                kind: 'signal',
                message: 'Chamada aceita, pode falar no rádio.',
              );
              _openChatPanel(
                  peerName: from,
                  peerDriverId: alert['fromDriverId'].toString());
            },
            child: const Text('ATENDER'),
          ),
        ],
      ),
    );
  }

  Future<void> _startLocationStream() async {
    if (_positionSubscription != null) return;
    final settings = context.read<SettingsProvider>();
    if (!settings.trackingEnabled) return;
    final granted = await LocationHandler.requestPermissions();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Localização negada. O mapa não pode centralizar no caminhão.'),
          duration: Duration(seconds: 6),
        ),
      );
      return;
    }
    if (_positionSubscription != null) return;
    _positionSubscription = LocationHandler.positionStream(
      intervalSeconds: settings.gpsIntervalSeconds,
      highAccuracy: settings.highAccuracy,
    ).listen((pos) {
      final newPos = LatLng(pos.latitude, pos.longitude);
      final isFirst = _currentPosition == null;
      _onTripSample(newPos, pos.speed >= 0 ? pos.speed * 3.6 : 0);
      setState(() {
        _currentPosition = newPos;
        _speedKmh = pos.speed >= 0 ? pos.speed * 3.6 : 0;
        if (_center == _fallbackCenter) _center = newPos;
      });
      _socket.sendLocationUpdate(
          lat: newPos.latitude, lon: newPos.longitude, driverId: widget.driverId);
      _validarEntregas(newPos);
      _verificarLimiteVelocidade(newPos, _speedKmh);
      // Clima em tempo real: busca assim que o GPS define a posicao.
      if (mounted) {
        unawaited(context
            .read<WeatherProvider>()
            .refresh(lat: newPos.latitude, lon: newPos.longitude));
      }
      if (isFirst) {
        _moverCamera(newPos, zoom: 15, bearing: 0, tilt: 0);
      } else {
        _renderMarkers();
      }
    });
  }

  Future<void> _verificarLimiteVelocidade(LatLng pos, double speed) async {
    final agora = DateTime.now();
    if (agora.difference(_lastSpeedLimitCheck) < const Duration(seconds: 45)) {
      _avisarExcessoVelocidade(speed);
      return;
    }
    _lastSpeedLimitCheck = agora;
    final info = await _speedLimitService.fetch(pos.latitude, pos.longitude);
    if (!mounted) return;
    if (info.limitKmh != _speedLimitKmh || info.streetName != _streetName) {
      setState(() {
        _speedLimitKmh = info.limitKmh;
        _streetName = info.streetName;
      });
    }
    _avisarExcessoVelocidade(speed);
  }

  void _avisarExcessoVelocidade(double speed) {
    final limite = _speedLimitKmh;
    if (limite == null || limite <= 0) return;
    if (speed > limite + 8) {
      if (!_overSpeedWarned) {
        _overSpeedWarned = true;
        _showSnackBar('⚠️ Acima do limite: ${limite.toStringAsFixed(0)} km/h');
      }
    } else {
      _overSpeedWarned = false;
    }
  }

  void _moverCamera(LatLng target,
      {required double zoom, double bearing = 0, double tilt = 0}) {
    final c = _mapController;
    if (c == null || !_styleLoaded) return;
    c.animateCamera(
      ml.CameraUpdate.newCameraPosition(
        ml.CameraPosition(
          target: ml.LatLng(target.latitude, target.longitude),
          zoom: zoom,
          bearing: bearing,
          tilt: tilt,
        ),
      ),
      duration: const Duration(milliseconds: 600),
    );
  }

  /// Ajusta o mapa e o consumo de dados conforme a conexao.
  /// Em 4G/5G o app continua com o mapa completo (3D e tudo mais);
  /// a rede apenas informa o usuario e garante reconexao rapida.
  void _iniciarMonitorDeRede() {
    _network.start();
    _networkSub = _network.onChange.listen((kind) {
      if (!mounted) return;
      if (kind == NetKind.none) {
        _showSnackBar('📡 Sem conexão. Tentando reconectar...');
        return;
      }
      if (kind == NetKind.mobile) {
        _showSnackBar('📶 Dados móveis (4G/5G): mapa 3D completo ativo.');
      }
      _renderMarkers();
    });
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    _styleFallbackTimer?.cancel();
    _imagesAdded.clear();
    await _ensureBuildings3d();
    await _renderMarkers();
    if (_is3d) {
      final target = _currentPosition ?? _center;
      _moverCamera(target, zoom: _zoom, bearing: 25, tilt: 50);
    }
  }

  /// Se o estilo vetorial (CDN) demorar ou falhar, cai no raster local
  /// para nunca deixar o mapa em branco.
  void _agendarFallbackDeEstilo() {
    _styleFallbackTimer?.cancel();
    if (!_isDetailed) return;
    _styleFallbackTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || _styleLoaded) return;
      setState(() => _layerMode = MapLayerMode.streets);
      final style = _styleAtual;
      if (style.isNotEmpty) _mapController?.setStyle(style);
    });
  }

  Future<void> _ensureBuildings3d() async {
    final c = _mapController;
    if (c == null || !_isDetailed) return;
    final enabled = context.read<SettingsProvider>().buildings3d;
    final nightMode = context.read<SettingsProvider>().nightMode;
    try {
      await c.removeLayer('truck_buildings_3d');
    } catch (_) {}
    if (!enabled) return;
    final properties = ml.FillExtrusionLayerProperties(
      fillExtrusionColor: nightMode ? '#A8897A' : '#E9C7A6',
      fillExtrusionOpacity: nightMode ? 0.85 : 0.92,
      fillExtrusionVerticalGradient: true,
      fillExtrusionHeight: [
        'max',
        [
          'coalesce',
          ['get', 'render_height'],
          [
            '*',
            ['get', 'render_min_height'],
            2
          ]
        ],
        6
      ],
      fillExtrusionBase: [
        'coalesce',
        ['get', 'render_min_height'],
        0
      ],
    );
    try {
      await c.addFillExtrusionLayer(
        'openmaptiles',
        'truck_buildings_3d',
        properties,
        sourceLayer: 'building',
        belowLayerId: 'road_oneway',
        minzoom: 13,
      );
      return;
    } catch (_) {}
    try {
      await c.addFillExtrusionLayer(
        'openmaptiles',
        'truck_buildings_3d',
        properties,
        sourceLayer: 'building',
        minzoom: 13,
      );
    } catch (_) {}
  }

  Future<void> _addImageOnce(String name, Uint8List bytes) async {
    if (_imagesAdded.contains(name)) return;
    final c = _mapController;
    if (c == null) return;
    await c.addImage(name, bytes);
    _imagesAdded.add(name);
  }

  final Map<String, Uint8List> _photoCache = {};

  Future<Uint8List?> _fotoDoMotorista(Map peer) async {
    final url = (peer['truckPhotoUrl'] ?? peer['avatarUrl'])?.toString();
    if (url == null || url.isEmpty || url.startsWith('https://placehold.co')) {
      return null;
    }
    final cached = _photoCache[url];
    if (cached != null) return cached;
    try {
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 8),
          );
      if (response.statusCode != 200) return null;
      final bytes = response.bodyBytes;
      _photoCache[url] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _renderMarkers() async {
    final c = _mapController;
    if (c == null || !_styleLoaded || !mounted) return;

    final markers = context.read<MarkerProvider>().markers.toList();
    final showTrucks = context.read<SettingsProvider>().showTrucks;
    final routeProvider = context.read<RouteProvider>();
    final route = routeProvider.result;
    final routeStops = routeProvider.stops;
    final gruposFiltro = context.read<GroupProvider>();
    final authHeadersFiltro = context.read<AuthProvider>().authHeaders;
    final minhaFotoUrl = context.read<AuthProvider>().driver?.truckPhotoUrl;
    final meuAvatarUrl = context.read<AuthProvider>().driver?.avatarUrl;
    Set<String>? permitidos;
    if (gruposFiltro.estrito && gruposFiltro.temGrupos) {
      permitidos = gruposFiltro.memberIds;
      for (final g in gruposFiltro.mine) {
        if (gruposFiltro.membersOf(g.id).isEmpty) {
          gruposFiltro.loadMembers(groupId: g.id, auth: authHeadersFiltro);
        }
      }
    }

    try {
      await c.clearSymbols();
      await c.clearLines();
    } catch (_) {}

    if (route != null && route.polyline.length >= 2) {
      final geometry = route.polyline
          .map((p) => ml.LatLng(p.latitude, p.longitude))
          .toList();
      await c.addLine(
        ml.LineOptions(
          geometry: geometry,
          lineColor: '#1A0000',
          lineWidth: 9,
          lineOpacity: 0.55,
        ),
      );
      await c.addLine(
        ml.LineOptions(
          geometry: geometry,
          lineColor: _settingsProvider?.corRota ?? '#FF6D00',
          lineWidth: 5,
          lineOpacity: 0.95,
        ),
      );
    }

    await _renderHighlightedArea();
    if (!mounted) return;

    final empresa = context.read<AuthProvider>().driver;
    if (empresa?.companyLat != null && empresa?.companyLon != null) {
      await _addImageOnce('icon_empresa', await MapIcons.emojiBadge('🏭'));
      await c.addSymbol(
        ml.SymbolOptions(
          geometry: ml.LatLng(empresa!.companyLat!, empresa.companyLon!),
          iconImage: 'icon_empresa',
          iconSize: 0.5,
        ),
        {'kind': 'empresa', 'label': empresa.companyName ?? 'Empresa'},
      );
    }

    if (!mounted) return;
    final routeProviderNow = context.read<RouteProvider>();
    final proximo = routeProviderNow.nextStopIndex;
    for (var i = 0; i < routeProviderNow.stops.length; i++) {
      final stop = routeProviderNow.stops[i];
      final status = routeProviderNow.statusOf(i);
      final isProximo = i == proximo;
      final cor = routeProviderNow.isCompanyStop(i)
          ? const Color(0xFF9C27B0)
          : status == StopStatus.delivered
              ? const Color(0xFF4CAF50)
              : status == StopStatus.arrived
                  ? const Color(0xFF2196F3)
                  : const Color(0xFFFF9800);
      final imgName = 'stop_${cor.toARGB32()}_${i + 1}';
      await _addImageOnce(
          imgName, await MapIcons.waypointBadge(i + 1, color: cor));
      await c.addSymbol(
        ml.SymbolOptions(
          geometry: ml.LatLng(stop.point.latitude, stop.point.longitude),
          iconImage: imgName,
          iconSize: isProximo ? 0.55 : 0.42,
        ),
        {
          'kind': 'stop',
          'index': i,
          'label': stop.customer.isNotEmpty ? stop.customer : stop.label,
          'status': status.name,
        },
      );
    }

    await _addImageOnce('icon_alert', await MapIcons.alert());
    final alertasSnapshot = List<AlertModel>.from(_activeAlerts);
    final hiddenIds = _hiddenIdsSnapshot;
    for (final a
        in alertasSnapshot.where((a) => a.latitude != 0 && a.longitude != 0)) {
      if (hiddenIds.contains(a.id)) continue;
      await c.addSymbol(
        ml.SymbolOptions(
          geometry: ml.LatLng(a.latitude, a.longitude),
          iconImage: 'icon_alert',
          iconSize: 0.42,
        ),
        {'kind': 'alert', 'id': a.id, 'type': a.type, 'message': a.message},
      );
    }

    if (showTrucks) {
      final peersSnapshot = List<Map<String, dynamic>>.from(_peerTrucks);
    for (final p in peersSnapshot) {
        final lat = (p['lat'] as num?)?.toDouble();
        final lon = (p['lon'] as num?)?.toDouble();
        if (lat == null || lon == null || (lat == 0 && lon == 0)) continue;
        if (permitidos != null) {
          final pid = p['driverId']?.toString() ?? '';
          if (pid == widget.driverId || pid.isEmpty) continue;
          if (!permitidos.contains(pid)) continue;
        }
        final helper = (p['role'] ?? 'motorista').toString() == 'ajudante';
        final emoji = (p['truckIcon'] ?? '🚚').toString();
        final photo = await _fotoDoMotorista(p);
        final imgName = helper
            ? 'peer_h_${photo?.length ?? 0}_${photo == null ? 0 : photo[0]}'
            : 'peer_d_${photo?.length ?? 0}_${photo == null ? 0 : photo[0]}';
        if (photo != null) {
          await _addImageOnce(imgName,
              await MapIcons.photoBadge(photo, helper: helper, mine: false));
        } else {
          await _addImageOnce(imgName, await MapIcons.truckIcon(emoji));
        }
        await c.addSymbol(
          ml.SymbolOptions(
            geometry: ml.LatLng(lat, lon),
            iconImage: imgName,
            iconSize: helper ? 0.34 : 0.5,
          ),
          {'kind': 'peer', 'peer': p},
        );
      }
    }

    final me = _currentPosition;
    if (me != null) {
      final minhaFoto = await _fotoDoMotorista(<String, dynamic>{
        'truckPhotoUrl': minhaFotoUrl,
        'avatarUrl': meuAvatarUrl,
      });
      String imgNameMe = 'icon_me';
      if (minhaFoto != null) {
        imgNameMe = 'icon_me_foto';
        await _addImageOnce(
            imgNameMe, await MapIcons.photoBadge(minhaFoto, helper: false, mine: true));
      }
      await _addImageOnce(
          'icon_me', await MapIcons.truckIcon(_truckIcon, mine: true));
      await c.addSymbol(
        ml.SymbolOptions(
          geometry: ml.LatLng(me.latitude, me.longitude),
          iconImage: imgNameMe,
          iconSize: 0.55,
        ),
        {'kind': 'me'},
      );
    }

    for (final m in markers) {
      final imgName = 'emoji_${m.emoji}';
      await _addImageOnce(imgName, await MapIcons.emojiBadge(m.emoji));
      await c.addSymbol(
        ml.SymbolOptions(
          geometry: ml.LatLng(m.latitude, m.longitude),
          iconImage: imgName,
          iconSize: 0.5,
        ),
        {
          'kind': 'marker',
          'id': m.id,
          'label': m.label,
          'type': m.type,
          'emoji': m.emoji
        },
      );
    }

    for (var i = 0; i < routeStops.length; i++) {
      final status = routeProvider.statusOf(i);
      final color = status == StopStatus.delivered
          ? const Color(0xFF2E7D32)
          : status == StopStatus.arrived
              ? const Color(0xFFF9A825)
              : const Color(0xFFD32F2F);
      final imgName = 'wp_${color.toARGB32()}_${i + 1}';
      await _addImageOnce(
          imgName, await MapIcons.waypointBadge(i + 1, color: color));
      await c.addSymbol(
        ml.SymbolOptions(
          geometry: ml.LatLng(
              routeStops[i].point.latitude, routeStops[i].point.longitude),
          iconImage: imgName,
          iconSize: 0.42,
        ),
        {'kind': 'stop', 'index': i},
      );
    }
  }

  Future<void> _renderHighlightedArea() async {
    final c = _mapController;
    if (c == null) return;
    final area = context.read<RouteProvider>().highlightedArea;
    try {
      await c.removeLayer('area_fill');
      await c.removeLayer('area_line');
    } catch (_) {}
    try {
      await c.removeSource('route_area');
    } catch (_) {}
    if (area == null || area.length < 3) return;

    final source = {
      'type': 'Feature',
      'geometry': {
        'type': 'Polygon',
        'coordinates': [area],
      },
      'properties': <String, dynamic>{},
    };
    try {
      await c.addGeoJsonSource('route_area', source);
      await c.addFillLayer(
        'route_area',
        'area_fill',
        const ml.FillLayerProperties(
          fillColor: '#00B0FF',
          fillOpacity: 0.07,
        ),
      );
      await c.addLineLayer(
        'route_area',
        'area_line',
        const ml.LineLayerProperties(
          lineColor: '#FFB300',
          lineWidth: 3.5,
          lineOpacity: 0.95,
          lineBlur: 0.4,
        ),
      );
    } catch (_) {}
  }

  void _onSymbolTapped(ml.Symbol symbol) {
    final data = symbol.data;
    if (data == null) return;
    switch (data['kind']) {
      case 'me':
        _abrirMeuPerfil();
        break;
      case 'peer':
        final peer = data['peer'];
        if (peer is Map) _openPeerProfile(Map<String, dynamic>.from(peer));
        break;
      case 'marker':
        final id = data['id'];
        final matches =
            context.read<MarkerProvider>().markers.where((m) => m.id == id);
        if (matches.isNotEmpty) _mostrarInfoMarcador(matches.first);
        break;
      case 'stop':
        final index = (data['index'] as num?)?.toInt();
        if (index != null) _confirmarParada(index);
        break;
      case 'alert':
        _abrirDetalhesSinal(data);
        break;
      default:
        break;
    }
  }

  /// Bottom sheet com detalhes em tempo real do sinal tocado no mapa.
  void _abrirDetalhesSinal(Map<dynamic, dynamic> data) {
    final id = data['id']?.toString() ?? '';
    final tipo = data['type']?.toString() ?? 'texto_livre';
    final emoji = AppConstants.emojiForType(tipo);
    final mensagem = data['message']?.toString() ?? '';
    final alert = _activeAlerts.where((a) => a.id == id).toList();
    final lat = alert.isNotEmpty ? alert.first.latitude : null;
    final lon = alert.isNotEmpty ? alert.first.longitude : null;
    final criado = alert.isNotEmpty ? alert.first.createdAt : null;
    showModalBottomSheet(
      context: context,
      backgroundColor: kDarkRedTransition,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tipo.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (mensagem.isNotEmpty)
                Text(mensagem,
                    style: const TextStyle(color: Colors.white, fontSize: 14))
              else
                const Text('Sem mensagem no sinal.',
                    style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text(' tempo: ${_formatarTempo(criado)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              if (lat != null && lon != null)
                Text('${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Fechar'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      if (id.isNotEmpty) {
                        context.read<AlertProvider>().hide(id);
                        _showSnackBar('Sinal ocultado.');
                      }
                    },
                    icon: const Icon(Icons.visibility_off, size: 18),
                    label: const Text('Ocultar'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _limparSinal(id);
                    },
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text('Limpar'),
                  ),
                ],
              ),
              if (lat != null && lon != null) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final c = _mapController;
                      Navigator.pop(sheetContext);
                      c?.animateCamera(
                        ml.CameraUpdate.newCameraPosition(
                          ml.CameraPosition(
                            target: ml.LatLng(lat, lon),
                            zoom: 16.5,
                          ),
                        ),
                        duration: const Duration(milliseconds: 700),
                      );
                    },
                    icon: const Icon(Icons.center_focus_strong, size: 18),
                    label: const Text('Ir até o ponto'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatarTempo(DateTime? criado) {
    if (criado == null) return 'agora';
    final d = DateTime.now().difference(criado);
    if (d.inMinutes < 1) return 'agora';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    if (d.inHours < 24) return '${d.inHours} h';
    return '${d.inDays} d';
  }

  /// Remove o sinal do dono em todo mundo e limpa localmente.
  void _limparSinal(String id) {
    final matches = _activeAlerts.where((a) => a.id == id).toList();
    final original = matches.isNotEmpty ? matches.first : null;
    _activeAlerts.removeWhere((a) => a.id == id);
    context.read<AlertProvider>().clearAlert(id);
    if (original != null) {
      _socket.clearAlert(
        alertId: id,
        driverId: widget.driverId,
        lat: original.latitude,
        lon: original.longitude,
      );
    }
    _renderMarkers();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kDarkRedTransition,
        content: Text(
          message,
          style: const TextStyle(
              color: Colors.redAccent, fontWeight: FontWeight.bold),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showWriteReportDialog() {
    showDialog(
      context: context,
      builder: (context) => ReportDialog(
        latitude: _reportPoint.latitude,
        longitude: _reportPoint.longitude,
        onSubmit: (type, message, lat, lon) {
          _socket.sendRoadAlert(
            driverId: widget.driverId,
            type: type,
            message: message,
            lat: lat,
            lon: lon,
          );
        },
      ),
    );
  }

  LatLng get _reportPoint => _currentPosition ?? _center;

  void _openChatPanel({String? peerName, String? peerDriverId}) {
    // O chat virou um painel flutuante do mapa (arrastavel, minimizavel e
    // ocultavel) em vez de uma folha modal que travava o app.
    setState(() {
      _chatAberto = true;
      _chatPeerName = peerName;
      _chatPeerId = peerDriverId;
    });
  }

  /// Envia minha posição atual pela rede para quem estiver perto.
  void _compartilharMinhaPosicao() {
    final pos = _currentPosition;
    if (pos == null) {
      _showSnackBar('GPS ainda sem posição.');
      return;
    }
    _socket.sharePlace(
      fromDriverId: widget.driverId,
      fromName: widget.driverName,
      lat: pos.latitude,
      lon: pos.longitude,
      label: 'Estou aqui',
    );
    _showSnackBar('Posição compartilhada na rede.');
  }

  /// Cartão de perfil do próprio motorista (tap no caminhão no mapa).
  void _abrirMeuPerfil() {
    final driver = context.read<AuthProvider>().driver;
    showModalBottomSheet(
      context: context,
      backgroundColor: _superficie(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: const Color(0xFF1C0303),
                  backgroundImage: (driver?.avatarUrl ?? '').isNotEmpty
                      ? NetworkImage(driver!.avatarUrl!)
                      : null,
                  child: (driver?.avatarUrl ?? '').isEmpty
                      ? Text((driver?.truckIcon ?? '🚚'),
                          style: const TextStyle(fontSize: 30))
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  driver?.name ?? 'Motorista',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Center(
                child: Text(
                  (driver?.isPremium ?? false)
                      ? 'PREMIUM ATIVO'
                      : 'PLANO GRATUITO',
                  style: TextStyle(
                    color: (driver?.isPremium ?? false)
                        ? Colors.greenAccent
                        : Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _linhaPerfil('E-mail', driver?.email ?? '—'),
              _linhaPerfil('Papel',
                  (driver?.isHelper ?? false) ? 'Ajudante' : 'Motorista'),
              _linhaPerfil('Caminhão', driver?.truckModel ?? 'Não informado'),
              _linhaPerfil('Carga', driver?.cargoType ?? 'Carga geral'),
              _linhaPerfil(
                  'Dimensões',
                  'Altura ${(driver?.truckHeight ?? 0).toStringAsFixed(2)} m • '
                      'Peso ${(driver?.truckWeight ?? 0).toStringAsFixed(2)} t • '
                      '${driver?.axleCount ?? 0} eixos'),
              if (driver?.hazmat ?? false) _linhaPerfil('HAZMAT', 'Sim'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('EDITAR PERFIL'),
                ),
              ),
              const SizedBox(height: 10),
              if (_currentPosition != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: kEmergencyRed),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _compartilharMinhaPosicao();
                    },
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('COMPARTILHAR POSIÇÃO'),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linhaPerfil(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(rotulo,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          Expanded(
            child: Text(valor,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _openPeerProfile(Map<String, dynamic> peer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _superficie(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => PeerProfilePanel(
        peerTruck: peer,
        currentDriverId: widget.driverId,
        onSendReaction: (emoji) {
          _socket.sendTruckReaction(
            fromName: widget.driverName,
            targetDriverId: peer['driverId']?.toString() ?? '',
            emoji: emoji,
          );
          Navigator.pop(sheetContext);
        },
        onOpenChat: () {
          Navigator.pop(sheetContext);
          _openChatPanel();
        },
        onMessage: () {
          Navigator.pop(sheetContext);
          _openChatPanel(
            peerName: (peer['name'] ?? 'Caminhoneiro').toString(),
            peerDriverId: peer['driverId']?.toString(),
          );
        },
        onSignal: () {
          Navigator.pop(sheetContext);
          _socket.sendPeerAlert(
            fromDriverId: widget.driverId,
            fromName: widget.driverName,
            targetDriverId: peer['driverId'].toString(),
            kind: 'signal',
            message: 'Atenção na via, sinal do caminhoneiro ao lado.',
          );
          _showSnackBar('Sinal enviado para ${peer['name'] ?? 'o motorista'}.');
        },
        onVibration: () {
          Navigator.pop(sheetContext);
          _socket.sendPeerAlert(
            fromDriverId: widget.driverId,
            fromName: widget.driverName,
            targetDriverId: peer['driverId'].toString(),
            kind: 'vibration',
          );
          _showSnackBar(
              'Vibração enviada para ${peer['name'] ?? 'o motorista'}.');
        },
        onCall: () {
          Navigator.pop(sheetContext);
          _socket.sendPeerAlert(
            fromDriverId: widget.driverId,
            fromName: widget.driverName,
            targetDriverId: peer['driverId'].toString(),
            kind: 'call',
          );
          _showSnackBar(
              'Chamada de rádio enviada para ${peer['name'] ?? 'o motorista'}.');
        },
      ),
    );
  }

  void _exibirAnimacaoEmojiNaTela(String remetente, String emoji) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFF0A0A0A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 250, left: 50, right: 50),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.red)),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 15),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(remetente,
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                const Text("te enviou uma saudação!",
                    style: TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Unico comando de sinalizacao: emoji, aviso na estrada ou endereco.
  void _abrirSinalizacoes() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _superficie(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.emoji_emotions, color: Colors.redAccent),
              title: const Text('Sinal com emoji'),
              subtitle: const Text('Marcar um ponto no mapa (12h)'),
              onTap: () {
                Navigator.pop(ctx);
                _sinalizarNoCentro();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_road, color: Colors.redAccent),
              title: const Text('Avisar a comunidade'),
              subtitle: const Text('Radar, ponte baixa, balança, pedágio...'),
              onTap: () {
                Navigator.pop(ctx);
                _showWriteReportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.pin_drop, color: Colors.redAccent),
              title: const Text('Marcar endereço / rua'),
              subtitle: const Text('Salvar um ponto para quem estiver perto'),
              onTap: () {
                Navigator.pop(ctx);
                _marcarEndereco();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Salva um endereco/ponto exato e compartilha com a rede.
  Future<void> _marcarEndereco() async {
    final controller = TextEditingController();
    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar endereço'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nome do local',
            hintText: 'Ex.: Galpão do motorista, Posto BR',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('SALVAR'),
          ),
        ],
      ),
    );
    if (resultado == null || resultado.isEmpty) return;
    if (!mounted) return;
    final lat = _center.latitude;
    final lon = _center.longitude;
    context.read<MarkerProvider>().addMarker(
          MapMarkerModel(
            id: 'end_${DateTime.now().millisecondsSinceEpoch}',
            emoji: '📍',
            type: 'endereco',
            label: resultado,
            latitude: lat,
            longitude: lon,
          ),
        );
    _socket.sharePlace(
      fromDriverId: widget.driverId,
      fromName: widget.driverName,
      label: resultado,
      lat: lat,
      lon: lon,
    );
    _showSnackBar('📍 "$resultado" marcado e compartilhado com a rede.');
    _renderMarkers();
  }

  void _verRua() {
    final target = _currentPosition ?? _center;
    StreetViewScreen.show(
      context,
      latitude: target.latitude,
      longitude: target.longitude,
      token: AppConstants.mapillaryToken.isEmpty ? null : AppConstants.mapillaryToken,
    );
  }

  /// Novo toque curto no mapa: usado pelo modo "escolher empresa".
  void _onMapClickCurto(LatLng point) {
    if (!_modoEscolherEmpresa) return;
    _modoEscolherEmpresa = false;
    _concluirEscolhaEmpresa(point);
  }

  Future<void> _concluirEscolhaEmpresa(LatLng point) async {
    final controller = TextEditingController(
      text: _nomeEmpresaPendente.isNotEmpty
          ? _nomeEmpresaPendente
          : (context.read<AuthProvider>().driver?.companyName ?? ''),
    );
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nova empresa neste ponto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Local: ${point.latitude.toStringAsFixed(5)}, '
                '${point.longitude.toStringAsFixed(5)}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome da empresa',
                hintText: 'Ex.: Transportadora Silva',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {
              'name': controller.text.trim(),
            }),
            child: const Text('ADICIONAR'),
          ),
        ],
      ),
    );
    if (resultado == null || !mounted) return;
    final nome = (resultado['name'] ?? '').toString();
    await _salvarEmpresa(point, nome);
  }

  /// Salva a empresa na conta e a sincroniza como ponto final da rota.
  Future<void> _salvarEmpresa(LatLng point, String nome) async {
    final nomeFinal = nome.isEmpty ? 'Empresa' : nome;
    final provider = context.read<AuthProvider>();
    await provider.updateProfile(
      companyName: nomeFinal,
      companyLat: point.latitude,
      companyLon: point.longitude,
    );
    if (!mounted) return;
    final route = context.read<RouteProvider>();
    route.setCompanyStop(name: nomeFinal, point: point);
    setState(() => _center = point);
    _moverCamera(point, zoom: 16);
    setState(() {});
    _showSnackBar('🏭 Empresa "$nomeFinal" marcada e sincronizada com a rota.');
  }

  Future<void> _marcarEmpresa() async {
    final controller = TextEditingController(
      text: context.read<AuthProvider>().driver?.companyName ?? '',
    );
    final buscaController = TextEditingController();
    GeoResult? encontrado;
    final GeocodingService geocoding = GeocodingService();

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Empresa'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Nome da empresa',
                    hintText: 'Ex.: Transportadora Silva',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: buscaController,
                  decoration: const InputDecoration(
                    labelText: 'Endereço exato',
                    hintText: 'Rua, número, bairro',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final resultados = await geocoding
                              .search(buscaController.text, limit: 1);
                          if (resultados.isEmpty) return;
                          setState(() => encontrado = resultados.first);
                        },
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Buscar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _nomeEmpresaPendente = controller.text.trim();
                            _modoEscolherEmpresa = true;
                          });
                          _showSnackBar(
                              '🏭 Toque no mapa para posicionar a empresa.');
                        },
                        icon: const Icon(Icons.touch_app, size: 16),
                        label: const Text('Escolher'),
                      ),
                    ),
                  ],
                ),
                if (encontrado != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Encontrado: ${encontrado!.displayName}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (encontrado != null) {
                  Navigator.pop(ctx, {
                    'name': controller.text.trim(),
                    'lat': encontrado!.latitude,
                    'lon': encontrado!.longitude,
                  });
                } else {
                  Navigator.pop(ctx, {
                    'name': controller.text.trim(),
                    'lat': _center.latitude,
                    'lon': _center.longitude,
                  });
                }
              },
              child: const Text('SALVAR'),
            ),
          ],
        ),
      ),
    );

    if (resultado == null) return;
    final nome = (resultado['name'] ?? '').toString();
    final lat = (resultado['lat'] as num?)?.toDouble() ?? _center.latitude;
    final lon = (resultado['lon'] as num?)?.toDouble() ?? _center.longitude;
    if (!mounted) return;
    final provider = context.read<AuthProvider>();
    await provider.updateProfile(
      companyName: nome.isEmpty ? 'Empresa' : nome,
      companyLat: lat,
      companyLon: lon,
    );
    setState(() => _center = LatLng(lat, lon));
    _moverCamera(LatLng(lat, lon), zoom: 16);
    _showSnackBar('🏭 Empresa "${nome.isEmpty ? 'Empresa' : nome}" marcada no mapa.');
  }

  void _recentralizarNoCaminhao() {
    final target = _currentPosition ?? _fallbackCenter;
    setState(() => _is3d = false);
    _moverCamera(target, zoom: 15, bearing: 0, tilt: 0);
  }

  void _abrirHistoricoViagens() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const TravelHistoryScreen()));
  }

  Future<void> _abrirContatosEstrada() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (context) => const ContactsScreen()),
    );
    if (result == null || !mounted) return;
    setState(() => _center = result);
    _moverCamera(result, zoom: 15);
  }

  void _sairDaConta() {
    confirmarEExecutar(
      context,
      titulo: 'Sair da conta',
      mensagem:
          'Voce vai sair da conta neste aparelho.\n\nA sessao do servidor continua valida, mas sera preciso entrar de novo.',
      textoConfirmar: 'SAIR',
      destrutivo: true,
      icone: Icons.logout,
      acao: () async {
        final navigator = Navigator.of(context);
        context.read<AuthProvider>().logout();
        context.read<PeerProvider>().clear();
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      },
    );
  }

  void _validarEntregas(LatLng pos) {
    final route = context.read<RouteProvider>();
    if (route.totalStops == 0) return;
    final before = route.deliveredCount;
    route.updatePosition(pos);
    if (route.deliveredCount > before) {
      HapticFeedback.mediumImpact();
      _showSnackBar('Entrega validada: ${route.nextStopLabel}');
      _renderMarkers();
      final total = route.totalStops - (route.companyStopIndex != null ? 1 : 0);
      // Sequencia da chegada: primeiro o SINO, depois a VOZ (com o radio
      // abaixado) dizendo a proxima parada e a distancia.
      unawaited(_tocarChegadaEVoz(route, total));
    }
    if (route.allDelivered && route.consumeCompletionEvent()) {
      _mostrarViagemConcluida(route.deliveredCount);
    }
  }

  /// Toca o sino da parada e depois fala (com o radio abaixado).
  Future<void> _tocarChegadaEVoz(RouteProvider route, int total) async {
    final audio = context.read<AudioProvider>();
    await audio.tocarChegada();
    if (!mounted) return;
    await VoiceService.instance.chegadaNaParada(
      route.deliveredCount,
      total,
      proxima: route.nextStopLabel.isEmpty ? null : route.nextStopLabel,
      distanciaProximaKm: route.distanciaProximaParadaKm,
    );
  }

  void _mostrarViagemConcluida(int entregas) {
    _dispararAlarme('radar');
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.verified, color: Colors.green, size: 42),
        title: const Text('Viagem concluída com sucesso!'),
        content: Text(
          'Todas as $entregas entregas foram validadas no mapa. '
          'Rota finalizada e registrada no histórico.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _finalizarViagem();
            },
            child: const Text('FINALIZAR'),
          ),
        ],
      ),
    );
  }

  void _mostrarRota() {
    final route = context.read<RouteProvider>();
    final points = <LatLng>[
      ...?route.result?.polyline,
      ...route.stops.map((s) => s.point),
    ];
    if (points.isEmpty) {
      _showSnackBar('Nenhuma rota para exibir.');
      return;
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
    final span = (maxLat - minLat).abs() + (maxLon - minLon).abs();
    final zoom = span <= 0.01 ? 15.0 : (14.5 - (span * 40)).clamp(8.0, 15.0);
    setState(() => _center = center);
    _moverCamera(center, zoom: zoom);
  }

  void _compartilharRota() {
    final route = context.read<RouteProvider>();
    if (route.totalStops == 0) {
      _showSnackBar('Adicione clientes antes de compartilhar a rota.');
      return;
    }
    final grupos = context.read<GroupProvider>();
    final grupo = grupos.mine.isEmpty ? null : grupos.mine.first;
    confirmarEExecutar(
      context,
      titulo: 'Compartilhar rota',
      mensagem: grupo != null
          ? 'Sua rota com ${route.totalStops} parada(s) sera enviada so para o grupo "${grupo.name}" (modo privado).\n\nSo caminhoneiros do grupo veem.'
          : 'Sua rota com ${route.totalStops} parada(s) sera enviada para os caminhoes da rede V2X.\n\nTodos veem onde voce esta e para onde vai.',
      textoConfirmar: 'COMPARTILHAR',
      icone: Icons.share_location,
      acao: () async {
        _socket.shareRoute(
          fromDriverId: widget.driverId,
          fromName: widget.driverName,
          routeJson: route.exportRouteJson(),
          groupId: grupo?.id,
        );
        _showSnackBar(grupo != null
            ? 'Rota compartilhada so com o grupo "${grupo.name}".'
            : 'Rota compartilhada com os caminhões da rede.');
      },
    );
  }
  void _iniciarRota() {
    final provider = context.read<RouteProvider>();
    final driver = context.read<AuthProvider>().driver;
    if (driver != null &&
        driver.companyLat != null &&
        driver.companyLon != null) {
      provider.setCompanyStop(
        name: (driver.companyName ?? '').isNotEmpty
            ? driver.companyName!
            : 'Empresa',
        point: LatLng(driver.companyLat!, driver.companyLon!),
      );
    }
    provider.startRoute();
    _tripStart = DateTime.now();
    _tripStartPos = _currentPosition;
    _tripDistanceMeters = 0;
    _tripMaxSpeed = 0;
    _tripSpeedSum = 0;
    _tripSpeedSamples = 0;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.alert);
    _showSnackBar('▶️ Rota iniciada. Boa viagem!');
    _renderMarkers();
  }

  void _avisarRotaFinalizada() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    unawaited(context.read<AudioProvider>().tocarChegada());
    unawaited(VoiceService.instance.falar('Rota concluida. Volte para a empresa.'));
    _showSnackBar('🏁 ROTA FINALIZADA — todos os clientes visitados.');
  }

  void _avisarViagemConcluida() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    unawaited(context.read<AudioProvider>().tocarChegada());
    unawaited(VoiceService.instance.viagemConcluida());
    _showSnackBar('✅ VIAGEM CONCLUÍDA COM SUCESSO.');
  }

  void _confirmarEntregaAtual() {
    final route = context.read<RouteProvider>();
    final index = route.nextStopIndex;
    if (index == null) return;
    route.confirmDelivery(index);
    HapticFeedback.mediumImpact();
    _showSnackBar('Entrega ${index + 1} confirmada manualmente.');
    _renderMarkers();
    if (route.allDelivered && route.consumeCompletionEvent()) {
      _mostrarViagemConcluida(route.deliveredCount);
    }
  }

  void _confirmarParada(int index) {
    final route = context.read<RouteProvider>();
    if (index < 0 || index >= route.totalStops) return;
    route.confirmDelivery(index);
    HapticFeedback.mediumImpact();
    _showSnackBar('Parada ${index + 1} confirmada.');
    _renderMarkers();
    _verificarConclusoesDaRota();
  }

  void _verificarConclusoesDaRota() {
    final route = context.read<RouteProvider>();
    if (route.consumeRouteFinishedEvent()) {
      _avisarRotaFinalizada();
    }
    if (route.consumeCompanyReachedEvent()) {
      _avisarViagemConcluida();
      _finalizarViagem();
    }
  }

  void _limparMapaCompleto() {
    context.read<MarkerProvider>().clear();
    context.read<AlertProvider>().clearAlerts();
    context.read<RouteProvider>().clear();
    setState(() => _activeAlerts.clear());
    _renderMarkers();
    _showSnackBar('Mapa limpo: sinais, alertas e rota removidos.');
  }

  void _onTripSample(LatLng pos, double speedKmh) {
    _tripStart ??= DateTime.now();
    _tripStartPos ??= pos;
    if (_lastTripPos != null) {
      _tripDistanceMeters += MarkerProvider.metersBetween(_lastTripPos!, pos);
    }
    _lastTripPos = pos;
    if (speedKmh > _tripMaxSpeed) _tripMaxSpeed = speedKmh;
    _tripSpeedSum += speedKmh;
    _tripSpeedSamples++;
  }

  TripModel? _buildTrip() {
    final start = _tripStart;
    final startPos = _tripStartPos;
    final endPos = _lastTripPos;
    if (start == null ||
        startPos == null ||
        endPos == null ||
        _tripDistanceMeters < 200) {
      return null;
    }
    return TripModel(
      id: 'trip_${start.millisecondsSinceEpoch}',
      startedAt: start,
      endedAt: DateTime.now(),
      distanceMeters: _tripDistanceMeters,
      averageSpeedKmh:
          _tripSpeedSamples > 0 ? _tripSpeedSum / _tripSpeedSamples : 0,
      maxSpeedKmh: _tripMaxSpeed,
      startLat: startPos.latitude,
      startLon: startPos.longitude,
      endLat: endPos.latitude,
      endLon: endPos.longitude,
    );
  }

  Future<void> _finalizarViagem({bool notify = true}) async {
    final trip = _buildTrip();
    if (trip == null) {
      if (notify) _showSnackBar('Nenhum trecho percorrido para salvar ainda.');
      return;
    }
    await context.read<TripProvider>().addTrip(trip);
    if (notify) {
      _showSnackBar('✅ Viagem salva: ${trip.distanceKm.toStringAsFixed(1)} km');
    }
    _resetTrip();
  }

  void _resetTrip() {
    _tripStart = null;
    _tripStartPos = null;
    _lastTripPos = null;
    _tripDistanceMeters = 0;
    _tripMaxSpeed = 0;
    _tripSpeedSum = 0;
    _tripSpeedSamples = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_settingsApplied) {
      _settingsProvider = context.read<SettingsProvider>();
      _markerProvider = context.read<MarkerProvider>();
      _routeProvider = context.read<RouteProvider>();
      _tripProvider = context.read<TripProvider>();
      _layerMode = _settingsProvider!.layer;
      _appliedLayer = _layerMode;

      _markerProvider!.purgeExpired();
      _markerProvider!.addListener(_onDataChanged);
      _routeProvider!.addListener(_onDataChanged);
      _settingsProvider!.addListener(_onDataChanged);
      if (!_alertProviderHooked) {
        _alertProviderHooked = true;
        final alertProvider = context.read<AlertProvider>();
        alertProvider.addListener(_onAlertsChanged);
        _hiddenIdsSnapshot = alertProvider.hiddenIds.toSet();
      }

      _carregarAlertsOffline();
      _iniciarMonitorDeRede();
      _settingsApplied = true;
    }
  }

  void _onAlertsChanged() {
    if (!mounted) return;
    setState(() {
      _hiddenIdsSnapshot = context.read<AlertProvider>().hiddenIds.toSet();
    });
    _renderMarkers();
  }

  void _onDataChanged() {
    if (!mounted) return;
    final camada = _settingsProvider?.layer;
    if (camada != null && camada != _appliedLayer) {
      _appliedLayer = camada;
      setState(() => _layerMode = camada);
      final style = _styleAtual;
      if (style.isNotEmpty) _mapController?.setStyle(style);
    }
    final quality = _settingsProvider?.renderQuality;
    if (quality != null && quality != _appliedQuality) {
      _appliedQuality = quality;
      _ensureBuildings3d();
      // Perfil economico: sem predios 3D e sem camadas pesadas de clima.
      _aplicarPerfilDeGraficos(quality);
    }
    _syncTracking();
    _renderMarkers();
  }

  /// Aplica o perfil de graficos escolhido em Configuracoes.
  ///
  /// - **Economico**: desliga predios 3D, radar de chuva e nuvens (poupa bateria
  ///   e dados) e limita os marcadores na tela.
  /// - **Equilibrado**: padrao do app.
  /// - **Ultra**: tudo ligado e contadores de FPS sempre ativos.
  void _aplicarPerfilDeGraficos(RenderQuality quality) {
    final camadas = context.read<MapLayersProvider>();
    if (quality == RenderQuality.economy) {
      if (camadas.radar) camadas.setRadar(false);
      if (camadas.nuvens) camadas.setNuvens(false);
      if (camadas.relevo) camadas.setRelevo(false);
    }
    if (quality == RenderQuality.ultra) {
      // Ultra: garante as camadas de clima e o medidor de FPS na tela.
      if (!camadas.radar) camadas.setRadar(true);
      if (!camadas.nuvens) camadas.setNuvens(true);
      final settings = _settingsProvider;
      if (settings != null && !settings.showFps) {
        settings.setShowFps(true);
      }
    }
    if (mounted) setState(() {});
  }

  void _syncTracking() {
    final tracking = _settingsProvider?.trackingEnabled ?? true;
    final hasStream = _positionSubscription != null;
    if (tracking && !hasStream) {
      _startLocationStream();
    } else if (!tracking && hasStream) {
      _positionSubscription?.cancel();
      _positionSubscription = null;
      setState(() => _currentPosition = null);
    }
  }

  Future<void> _carregarAlertsOffline() async {
    try {
      final rows = await LocalCache.getCachedAlerts();
      if (!mounted || rows.isEmpty) return;
      setState(() {
        _activeAlerts
          ..clear()
          ..addAll(rows
              .map((e) => AlertModel.fromJson(Map<String, dynamic>.from(e))));
      });
      _renderMarkers();
    } catch (_) {}
  }

  /// Adiciona sinais sem duplicar (por id) e limita a lista (evita inundacao
  /// quando a varredura de proximidade reenvia os mesmos sinais a cada
  /// atualizacao de posicao). Retorna true se algum sinal e novo.
  bool _adicionarAlerts(List<AlertModel> novos) {
    final existentes = _activeAlerts.map((a) => a.id).toSet();
    var adicionou = false;
    for (final a in novos) {
      if (a.id.isEmpty || existentes.contains(a.id)) continue;
      _activeAlerts.add(a);
      existentes.add(a.id);
      adicionou = true;
    }
    if (_activeAlerts.length > 60) {
      _activeAlerts.removeRange(0, _activeAlerts.length - 60);
    }
    return adicionou;
  }

  void _dispararAlarme(String type) {
    final s = context.read<SettingsProvider>();
    if (!s.soundEnabled) return;
    switch (type) {
      case 'radar':
        if (s.radarSound) {
          AlertNotifier.triggerRadarWarning();
          unawaited(
              context.read<SonsProvider>().tocar(SlotSom.alertaRadar));
        }
        break;
      case 'perigo':
      case 'ponte_baixa':
        if (s.vibration) AlertNotifier.triggerCriticalDangerAlarm();
        break;
      default:
        if (s.vibration) AlertNotifier.triggerTollAlert();
    }
  }

  void _limparSinaisDoMapa() {
    confirmarEExecutar(
      context,
      titulo: 'Limpar sinais do mapa',
      mensagem:
          'Todos os sinais e marcadores deste mapa serao apagados.\n\nOs avisos ja enviados para a rede continuam valendo.',
      textoConfirmar: 'LIMPAR',
      destrutivo: true,
      icone: Icons.delete_sweep_outlined,
      acao: () async {
        _limparMapaCompleto();
      },
    );
  }

  void _abrirConfiguracoes() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const SettingsScreen()));
  }

  void _abrirPerfil() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()));
  }

  void _abrirPaymentGate() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                PaymentGateScreen(driverId: widget.driverId)));
  }

  bool get _isPremium =>
      context.read<AuthProvider>().driver?.isPremium ?? false;

  void _gatePremium(PremiumFeature feature, VoidCallback action) {
    if (!PremiumPolicy.isLocked(feature, isPremium: _isPremium)) {
      action();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151515),
        title: const Text('Recurso Premium',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '${feature.label} está disponível apenas na versão Premium.\n\n'
          'No plano Free você navega com o mapa e as rotas. '
          'Assine o Premium para liberar alertas, sinais, rádio, '
          'outros caminhoneiros, ruas 3D e histórico.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Agora não'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kEmergencyRed),
            onPressed: () {
              Navigator.pop(ctx);
              _abrirPaymentGate();
            },
            child: const Text('Ver Premium'),
          ),
        ],
      ),
    );
  }

  Future<void> _onMapLongPress(LatLng point) async {
    final draft = await MarkerDialog.show(context);
    if (draft == null) return;
    _addMarkerAt(point, draft);
  }

  Future<void> _sinalizarNoCentro() async {
    final draft = await MarkerDialog.show(context);
    if (draft == null) return;
    _addMarkerAt(_currentPosition ?? _center, draft);
  }

  void _addMarkerAt(LatLng point, MarkerDraft draft) {
    context.read<MarkerProvider>().place(
          emoji: draft.emoji,
          type: draft.type,
          label: draft.label,
          latitude: point.latitude,
          longitude: point.longitude,
          driverId: widget.driverId,
        );
    _socket.sendRoadAlert(
      driverId: widget.driverId,
      type: draft.type,
      message: draft.label ?? draft.emoji,
      lat: point.latitude,
      lon: point.longitude,
    );
    _showSnackBar('${draft.emoji} Sinal adicionado no mapa');
  }

  Future<void> _buscarRua() async {
    final result = await StreetSearchSheet.show(context);
    if (result == null) return;
    final target = LatLng(result.latitude, result.longitude);
    setState(() => _center = target);
    _moverCamera(target, zoom: 16);
    _showSnackBar('📍 ${result.displayName}');
  }

  void _abrirPlanejadorDeRota() {
    RoutePlannerSheet.show(context, origin: _currentPosition);
  }

  /// Radio digital: abre o player (agenda com volume e agora tocando).
  void _abrirRadio() {
    _gatePremium(PremiumFeature.radio, () => RadioSheet.open(context));
  }

  /// Superficie dos paineis com a transparencia e a cor escolhidas pelo
  /// usuario na tela de Aparencia.
  Color _superficie(BuildContext context) {
    final settings = _settingsProvider;
    return overlaySurface(
      context,
      opacity: settings?.overlayOpacity ?? 1.0,
      accent: settings?.overlayColor,
    );
  }

  /// AGENTE B: ajudante acompanha a rede e envia sinais, mas nao monta rota.
  bool get _isHelper =>
      context.read<AuthProvider>().driver?.isHelper ?? false;

  void _abrirMenu() {
    MapMenuSheet.show(
      context,
      isPremium: context.read<AuthProvider>().driver?.isPremium ?? false,
      onProfile: _abrirPerfil,
      onTrips: () =>
          _gatePremium(PremiumFeature.tripHistory, _abrirHistoricoViagens),
      onEndTrip: _finalizarViagem,
      onContacts: () =>
          _gatePremium(PremiumFeature.roadContacts, _abrirContatosEstrada),
      onSettings: _abrirConfiguracoes,
      onPremium: _abrirPaymentGate,
      onClearSignals: _limparSinaisDoMapa,
      onLogout: _sairDaConta,
      onStreetView: _verRua,
      onCompany: _marcarEmpresa,
    );
  }

  /// Painel de grupos (comboios) + modo estrito de visibilidade.
  void _abrirGrupos() {
    final auth = context.read<AuthProvider>();
    GroupsSheet.show(
      context,
      driverId: widget.driverId,
      authHeaders: auth.authHeaders,
    );
  }

  void _mostrarInfoMarcador(MapMarkerModel m) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final tema = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(m.emoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        m.label ?? m.type,
                        style: tema.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Posicao: ${m.latitude.toStringAsFixed(4)}, ${m.longitude.toStringAsFixed(4)}',
                  style: tema.textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _markerProvider?.removeMarker(m.id);
                        },
                        icon: const Icon(Icons.visibility_off, size: 18),
                        label: const Text('Ocultar'),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _markerProvider?.removeMarker(m.id);
                          _showSnackBar('Marcador apagado.');
                        },
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: tema.colorScheme.error),
                        label: Text('Apagar',
                            style: TextStyle(color: tema.colorScheme.error)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    final trip = _buildTrip();
    if (trip != null) _tripProvider?.addTrip(trip);
    _positionSubscription?.cancel();
    _socket.disconnect();
    _markerProvider?.removeListener(_onDataChanged);
    _routeProvider?.removeListener(_onDataChanged);
    _settingsProvider?.removeListener(_onDataChanged);
    _networkSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = _uiExpanded;
    // O painel de rotas so aparece quando existe rota de verdade: painel
    // vazio sobre o mapa so atrapalhava.
    final totalParadas = context.watch<RouteProvider>().totalStops;

    return Scaffold(
      body: Stack(
        children: [
          _buildMapView(),
          if (ui && _settingsProvider?.showFps == true)
            Builder(builder: (ctx) {
              final size = MediaQuery.of(ctx).size;
              return FloatingPanel(
                id: 'fps',
                initial: Offset(size.width - 150, 96),
                width: 130,
                height: 46,
                dragWholeChild: true,
                minimizedChild: const Icon(Icons.speed, size: 20),
                child: FpsOverlay(
                  targetFps: _settingsProvider?.targetFps ?? 60,
                ),
              );
            }),
          if (ui)
            Builder(builder: (ctx) {
              final size = MediaQuery.of(ctx).size;
              return FloatingPanel(
                id: 'clima',
                initial: Offset(16, size.height - 430),
                width: 300,
                height: 390,
                minimizedChild: const Icon(Icons.cloud_outlined, size: 20),
                handle: _buildPuxador('Clima e previsão', Icons.cloud_outlined),
                child: WeatherPanel(
                  latitude: _currentPosition?.latitude,
                  longitude: _currentPosition?.longitude,
                ),
              );
            }),
          if (ui)
            Builder(builder: (ctx) {
              final size = MediaQuery.of(ctx).size;
              return FloatingPanel(
                id: 'camadas',
                initial: Offset(size.width - 320, 96),
                width: 300,
                height: 520,
                minimizedChild: const Icon(Icons.tune, size: 20),
                handle: _buildPuxador('Mapa e gráficos', Icons.tune),
                child: MapControlsPanel(
                  onCamada: _definirCamada,
                  onMostrarUi: (v) => setState(() => _uiExpanded = v),
                  uiVisivel: _uiExpanded,
                ),
              );
            }),
          if (ui && _chatAberto)
            Builder(builder: (ctx) {
              final size = MediaQuery.of(ctx).size;
              return FloatingPanel(
                id: 'chat',
                initial: Offset(size.width - 340, size.height - 520),
                width: 320,
                height: 420,
                minimizedChild: const Icon(Icons.chat_bubble_outline, size: 20),
                handle: _buildPuxador('Chat da via', Icons.chat_bubble_outline),
                child: ChatPanel(
                  driverId: widget.driverId,
                  driverName: widget.driverName,
                  messages: _chatMessages,
                  peerName: _chatPeerName,
                  onSend: (message) {
                    final pos = _reportPoint;
                    _socket.sendChatMessage(
                      driverId: widget.driverId,
                      driverName: widget.driverName,
                      message: message,
                      lat: pos.latitude,
                      lon: pos.longitude,
                      targetDriverId: _chatPeerId,
                    );
                  },
                ),
              );
            }),
          if (ui && !_routePanelClosed && totalParadas > 0)
            Builder(builder: (ctx) {
              final size = MediaQuery.of(ctx).size;
              return FloatingPanel(
                id: 'route',
                initial: Offset(size.width - 360, 96),
                width: 320,
                height: 240,
                minimizedChild: const Icon(Icons.table_rows, size: 20),
                handle: _buildPuxador('Tabela de rotas', Icons.table_rows),
                child: RouteTablePanel(
                  onShowRoute: _mostrarRota,
                  onShare: _compartilharRota,
                  onStart: _iniciarRota,
                  onConfirmNext: _confirmarEntregaAtual,
                  onClose: () => setState(() => _routePanelClosed = true),
                  canManageRoute: !_isHelper,
                ),
              );
            }),
          // AGENTE B: painel de sinais com minimizar/fechar (evita travar a tela).
          if (ui && _activeAlerts.isNotEmpty && !_alertsPanelClosed)
            FloatingPanel(
              id: 'alerts',
              initial: Offset(_contentLeft, 96),
              width: 300,
              height: 200,
              minimizedChild: const Icon(Icons.warning_amber_rounded, size: 20),
              handle: _buildPuxador('Sinais', Icons.warning_amber_rounded),
              child: AlertsPanel(
                alerts: List<AlertModel>.unmodifiable(_activeAlerts),
                surface: _superficie(context),
                accent: _settingsProvider?.overlayColor ?? kEmergencyRed,
                onClose: () => setState(() => _alertsPanelClosed = true),
              ),
            ),
          // AGENTE B: botao flutuante do radio (liga/desliga nas Configuracoes).
          if (ui && _settingsProvider?.radioFabEnabled != false)
            Builder(builder: (ctx) {
              final size = MediaQuery.of(ctx).size;
              return FloatingPanel(
                id: 'radio',
                initial: Offset(size.width - 70, size.height - 300),
                width: 56,
                height: 56,
                dragWholeChild: true,
                minimizedChild: const Icon(Icons.radio_outlined, size: 20),
                child: RadioFab(
                  surface: _superficie(context),
                  accent: _settingsProvider?.overlayColor ?? kEmergencyRed,
                  onPressed: _abrirRadio,
                  onStop: () => context.read<AudioProvider>().pararRadio(),
                ),
              );
            }),
          // AGENTE B: assistente da estrada (IA em todas as camadas).
          if (ui)
            Builder(builder: (ctx) {
              final size = MediaQuery.of(ctx).size;
              return FloatingPanel(
                id: 'assistant',
                initial: Offset(size.width - 70, size.height - 380),
                width: 56,
                height: 56,
                dragWholeChild: true,
                minimizedChild: const Icon(Icons.auto_awesome, size: 20),
                child: _buildAssistantButton(),
              );
            }),
          if (ui)
            Builder(builder: (ctx) {
              final size = MediaQuery.of(ctx).size;
              return FloatingPanel(
                id: 'speed_hud',
                initial: Offset(size.width - 220, size.height - 230),
                width: 200,
                height: 90,
                minimizedChild: const Icon(Icons.speed, size: 20),
                child: SpeedHUD(
                  speedKmh: _speedKmh,
                  limitKmh: _speedLimitKmh,
                  streetName: _streetName,
                ),
              );
            }),
          if (ui && _peerTrucks.isNotEmpty)
            Builder(builder: (ctx) {
              final size = MediaQuery.of(ctx).size;
              return FloatingPanel(
                id: 'peers',
                initial: Offset(size.width - 200, size.height - 390),
                width: 220,
                height: 160,
                minimizedChild: const Icon(Icons.local_shipping, size: 20),
                child: _buildPeerBubble(),
              );
            }),
          if (ui)
            FloatingPanel(
              id: 'toolbar',
              initial: const Offset(12, 120),
              width: 168,
              height: 420,
              minimizedChild: const Icon(Icons.build_outlined, size: 20),
              handle: _buildPuxador('Ferramentas', Icons.build_outlined),
              child: _buildSideRail(),
            ),
        ],
      ),
    );
  }

  /// Puxador de arraste dos paineis (arrasta e mostra o nome do painel).
  Widget _buildPuxador(String titulo, IconData icone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _superficie(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (_settingsProvider?.overlayColor ?? kEmergencyRed)
              .withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone,
              size: 14, color: _settingsProvider?.overlayColor ?? kEmergencyRed),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              titulo,
              style: TextStyle(
                color: overlayTextMuted(context),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.drag_indicator,
              size: 14, color: overlayTextMuted(context)),
        ],
      ),
    );
  }

  /// Abre o assistente (IA que le rota, alertas, limite e clima).
  void _abrirAssistente() {
    unawaited(_abrirAssistenteComContexto());
  }

  Future<void> _abrirAssistenteComContexto() async {
    final pos = _currentPosition;
    if (pos != null) {
      await context
          .read<WeatherProvider>()
          .refresh(lat: pos.latitude, lon: pos.longitude);
    }
    if (!mounted) return;
    AssistantSheet.show(
      context,
      snapshotAoVivo: () => {
        'velocidade': '${_speedKmh.toStringAsFixed(0)} km/h agora'
            '${_speedLimitKmh != null ? ' (limite $_speedLimitKmh km/h'
                '${_speedKmh > _speedLimitKmh! + 8 ? ', excesso!' : ''})' : ''}',
        'clima': _resumoClimaIA(),
        'rua': _streetName ?? 'logradouro não identificado',
      },
    );
  }

  String _resumoClimaIA() {
    try {
      final clima = context.read<WeatherProvider>();
      final n = clima.now;
      final dicas = clima.dicasIA();
      if (n == null) return 'sem informação de clima (sem rede/GPS)';
      return '${clima.emojiForCode(n.code)} ${n.tempC.toStringAsFixed(0)}°C, '
          'vento ${n.windKmh.toStringAsFixed(0)} km/h'
          '${dicas.isNotEmpty ? ' | ${dicas.join(' | ')}' : ''}';
    } catch (_) {
      return 'clima indisponível';
    }
  }

  /// Botao do assistente (IA) sobre o mapa.
  Widget _buildAssistantButton() {
    return Tooltip(
      message: 'Assistente da estrada',
      child: Material(
        color: _superficie(context),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _abrirAssistente,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.auto_awesome,
                color: _settingsProvider?.overlayColor ?? kEmergencyRed, size: 22),
          ),
        ),
      ),
    );
  }

  /// Troca a camada do mapa (satelite/ruas/3D).
  Future<void> _definirCamada(MapLayerMode novo) async {
    if (novo == MapLayerMode.detailed &&
        PremiumPolicy.isLocked(PremiumFeature.detailedMap,
            isPremium: _isPremium)) {
      _gatePremium(PremiumFeature.detailedMap, () {});
      return;
    }
    setState(() {
      _layerMode = novo;
      _appliedLayer = novo;
    });
    await _settingsProvider?.setLayer(novo);
    final style = _styleAtual;
    if (style.isNotEmpty) {
      _mapController?.setStyle(style);
    }
    if (novo == MapLayerMode.detailed) {
      _ensureBuildings3d();
      final target = _currentPosition ?? _center;
      _moverCamera(target, zoom: _zoom, bearing: 25, tilt: 50);
    }
    _showSnackBar(switch (novo) {
      MapLayerMode.satellite => 'Imagem de satelite ativada.',
      MapLayerMode.streets => 'Mapa leve de ruas ativado.',
      MapLayerMode.detailed => 'Ruas em 3D ativadas.',
    });
  }

  /// Volta a camera para o norte (bussola).
  void _voltarAoNorte() {
    final target = _currentPosition ?? _center;
    _moverCamera(target, zoom: _zoom, bearing: 0, tilt: _is3d ? 50 : 0);
  }

  Widget _railAction(IconData icon, String label, VoidCallback onTap) {
    final corIcone =
        _settingsProvider?.overlayColor ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: corIcone, size: 20),
            if (_sideRailOpen) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                      color: overlayTextMuted(context), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Barra de ferramentas flutuante: arrastavel, recolhivel e minimizavel
  /// (arraste para a borda esquerda/direita que ela vira uma tab).
  Widget _buildSideRail() {
    final cor = _settingsProvider?.overlayColor ?? kEmergencyRed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: _sideRailOpen ? 168 : 56,
      decoration: BoxDecoration(
        color: _superficie(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cor, width: 1.2),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: _sideRailOpen ? 'Recolher' : 'Expandir',
              child: InkWell(
                onTap: () => setState(() => _sideRailOpen = !_sideRailOpen),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _sideRailOpen
                            ? Icons.chevron_left
                            : Icons.chevron_right,
                        color: overlayTextMuted(context),
                        size: 20,
                      ),
                      if (_sideRailOpen) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Ferramentas',
                            style: TextStyle(
                              color: overlayTextMuted(context),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Divider(
                color: overlayTextMuted(context).withValues(alpha: 0.18),
                height: 1),
              _railAction(Icons.settings, 'Tudo', _abrirMenu),
              // AGENTE B: bussola e centralizar foram fundidos na barra
              // (antes eram dois botoes flutuantes soltos na tela).
              _railAction(Icons.explore, 'Bússola', _voltarAoNorte),
              _railAction(Icons.center_focus_strong, 'Centralizar',
                  _recentralizarNoCaminhao),
            // AGENTE B: ajudante acompanha, mas nao monta nem inicia rota.
            if (!_isHelper)
              _railAction(Icons.alt_route, 'Rota', _abrirPlanejadorDeRota),
            _railAction(Icons.group, 'Grupos', _abrirGrupos),
            _railAction(Icons.add_location_alt, 'Sinalizar', _abrirSinalizacoes),
            // O radio ficou no botao flutuante e nas Configuracoes (sem duplicar).
            _railAction(Icons.search, 'Buscar',
                () => _gatePremium(PremiumFeature.streetSearch, _buscarRua)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeerBubble() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_peerBubbleOpen)
          Container(
            width: 220,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _superficie(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _settingsProvider?.overlayColor ?? kEmergencyRed),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_shipping,
                        color: Colors.redAccent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${_peerTrucks.length} caminhões por perto',
                      style: TextStyle(
                          color: overlayText(context),
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ..._peerTrucks.take(4).map(
                      (p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _peerBubbleOpen = false);
                            _openPeerProfile(p);
                          },
                          child: Text(
                            '🚚 ${p['name'] ?? 'Caminhoneiro'}',
                            style: TextStyle(
                                color: overlayTextMuted(context), fontSize: 12),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        FloatingActionButton(
          heroTag: 'fab_peers',
          mini: true,
          backgroundColor: _superficie(context),
          onPressed: () => setState(() => _peerBubbleOpen = !_peerBubbleOpen),
          child: Badge(
            label: Text('${_peerTrucks.length}'),
            child: Icon(
              _peerBubbleOpen
                  ? Icons.keyboard_arrow_down
                  : Icons.local_shipping,
              color: Colors.redAccent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapView() {
    if (_styleJsonSat == null || _styleJsonStreetsLight == null) {
      // O mapa e sempre claro: o loading tambem.
      return const ColoredBox(
        color: Color(0xFFF5F2EE),
        child:
            Center(child: CircularProgressIndicator(color: Color(0xFF8B0000))),
      );
    }
    return ml.MapLibreMap(
      styleString: _styleAtual,
      initialCameraPosition: ml.CameraPosition(
        target: ml.LatLng(_center.latitude, _center.longitude),
        zoom: _zoom,
      ),
      onMapCreated: (controller) {
        _agendarFallbackDeEstilo();
        _mapController = controller;
        controller.onSymbolTapped.add(_onSymbolTapped);
      },
      onStyleLoadedCallback: _onStyleLoaded,
      onMapLongClick: (point, latLng) =>
          _onMapLongPress(LatLng(latLng.latitude, latLng.longitude)),
      onMapClick: (point, latLng) =>
          _onMapClickCurto(LatLng(latLng.latitude, latLng.longitude)),
      onCameraMove: (camera) {
        _zoom = camera.zoom;
        if ((camera.bearing - _bearing).abs() > 0.5) {
          setState(() => _bearing = camera.bearing);
        }
      },
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: true,
      doubleClickZoomEnabled: true,
      dragEnabled: true,
      minMaxZoomPreference: ml.MinMaxZoomPreference.unbounded,
      compassEnabled: false,
      myLocationEnabled: false,
      trackCameraPosition: true,
      logoEnabled: false,
      attributionButtonColor: Colors.transparent,
      attributionButtonMargins: const math.Point(-1000, -1000),
    );
  }
}
