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
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/network/socket_client.dart';
import 'package:gps_camioneiro_pro/core/network/speed_limit_service.dart';
import 'package:gps_camioneiro_pro/data/models/alert_model.dart';
import 'package:gps_camioneiro_pro/data/models/map_marker_model.dart';
import 'package:gps_camioneiro_pro/data/models/trip_model.dart';
import 'package:gps_camioneiro_pro/core/utils/location_handler.dart';
import 'package:gps_camioneiro_pro/core/database/local_cache.dart';
import 'package:gps_camioneiro_pro/providers/alert_notifier.dart';
import 'package:gps_camioneiro_pro/providers/alert_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/providers/marker_provider.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/peer_provider.dart';
import 'package:gps_camioneiro_pro/providers/trip_provider.dart';
import 'package:gps_camioneiro_pro/providers/route_provider.dart';
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
  String? _styleJsonStreetsDark;
  bool _styleLoaded = false;
  final Set<String> _imagesAdded = {};

  LatLng _center = _fallbackCenter;
  LatLng? _currentPosition;
  double _zoom = 14;
  double _speedKmh = 0;

  bool _is3d = false;
  bool _uiExpanded = true;
  bool _sideRailOpen = false;
  bool _railHidden = false;
  MapLayerMode _layerMode = MapLayerMode.satellite;
  final SpeedLimitService _speedLimitService = SpeedLimitService();
  int? _speedLimitKmh;
  String? _streetName;
  bool _overSpeedWarned = false;
  DateTime _lastSpeedLimitCheck = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _isSatellite => _layerMode == MapLayerMode.satellite;
  bool get _isDetailed => _layerMode == MapLayerMode.detailed;

  double get _railWidth => _railHidden ? 0 : (_sideRailOpen ? 168 : 56);

  double get _contentLeft => _railHidden ? 16 : 12 + _railWidth + 10;
  bool _settingsApplied = false;
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
    final dark = await rootBundle.loadString(AppConstants.styleStreetsDark);
    if (!mounted) return;
    setState(() {
      _styleJsonSat = sat;
      _styleJsonStreetsLight = light;
      _styleJsonStreetsDark = dark;
    });
  }

  String get _styleAtual {
    if (_isSatellite) return _styleJsonSat ?? '';
    if (_isDetailed) {
      final settings = context.read<SettingsProvider>();
      final base = settings.nightMode
          ? AppConstants.styleStreetsUrl
          : AppConstants.styleStreetsLightUrl;
      final version = settings.mapCacheVersion;
      return version == 0 ? base : '$base?v=$version';
    }
    final settings = context.read<SettingsProvider>();
    return settings.nightMode
        ? (_styleJsonStreetsDark ?? '')
        : (_styleJsonStreetsLight ?? '');
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
          _activeAlerts.addAll(alerts);
        });
        _renderMarkers();
      }
    });

    _socket.onReceiveAlertRealtime((data) {
      if (!mounted) return;
      final alert = AlertModel.fromJson(Map<String, dynamic>.from(data));
      setState(() {
        _activeAlerts.add(alert);
      });
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
          lat: pos.latitude, lon: pos.longitude, driverId: widget.driverId);
      _validarEntregas(newPos);
      _verificarLimiteVelocidade(newPos, _speedKmh);
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

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    _imagesAdded.clear();
    await _ensureBuildings3d();
    await _renderMarkers();
    if (_is3d) {
      final target = _currentPosition ?? _center;
      _moverCamera(target, zoom: _zoom, bearing: 25, tilt: 50);
    }
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
          lineColor: '#FF6D00',
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
    for (final a
        in _activeAlerts.where((a) => a.latitude != 0 && a.longitude != 0)) {
      await c.addSymbol(
        ml.SymbolOptions(
          geometry: ml.LatLng(a.latitude, a.longitude),
          iconImage: 'icon_alert',
          iconSize: 0.42,
        ),
        {'kind': 'alert', 'type': a.type, 'message': a.message},
      );
    }

    if (showTrucks) {
      for (final p in _peerTrucks) {
        final lat = (p['lat'] as num?)?.toDouble();
        final lon = (p['lon'] as num?)?.toDouble();
        if (lat == null || lon == null || (lat == 0 && lon == 0)) continue;
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
      await _addImageOnce(
          'icon_me', await MapIcons.truckIcon(_truckIcon, mine: true));
      await c.addSymbol(
        ml.SymbolOptions(
          geometry: ml.LatLng(me.latitude, me.longitude),
          iconImage: 'icon_me',
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
          fillColor: '#FF1744',
          fillOpacity: 0.16,
        ),
      );
      await c.addLineLayer(
        'route_area',
        'area_line',
        const ml.LineLayerProperties(
          lineColor: '#FF5252',
          lineWidth: 2.5,
          lineOpacity: 0.9,
        ),
      );
    } catch (_) {}
  }

  void _onSymbolTapped(ml.Symbol symbol) {
    final data = symbol.data;
    if (data == null) return;
    switch (data['kind']) {
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
        _showSnackBar(
            '[${(data['type'] ?? 'aviso').toString().toUpperCase()}] ${data['message'] ?? ''}');
        break;
      default:
        break;
    }
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xEE101418),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => ChatPanel(
        driverId: widget.driverId,
        driverName: widget.driverName,
        messages: _chatMessages,
        peerName: peerName,
        onSend: (message) {
          final pos = _reportPoint;
          _socket.sendChatMessage(
            driverId: widget.driverId,
            driverName: widget.driverName,
            message: message,
            lat: pos.latitude,
            lon: pos.longitude,
            targetDriverId: peerDriverId,
          );
        },
      ),
    );
  }

  void _openPeerProfile(Map<String, dynamic> peer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xEE101418),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => PeerProfilePanel(
        peerTruck: peer,
        currentDriverId: widget.driverId,
        onSendReaction: (emoji) {
          _socket.sendTruckReaction(
            fromName: widget.driverName,
            targetDriverId: peer['driverId'],
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

  void _verRua() {
    final target = _currentPosition ?? _center;
    StreetViewScreen.show(
      context,
      latitude: target.latitude,
      longitude: target.longitude,
      token: AppConstants.mapillaryToken.isEmpty ? null : AppConstants.mapillaryToken,
    );
  }

  Future<void> _marcarEmpresa() async {
    final controller = TextEditingController(
      text: context.read<AuthProvider>().driver?.companyName ?? '',
    );
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empresa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Nome da empresa',
                hintText: 'Ex.: Transportadora Silva',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'A empresa será marcada no centro do mapa atual e usada como '
              'última parada da rota.',
              style: TextStyle(fontSize: 12),
            ),
          ],
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
    if (nome == null || nome.isEmpty) return;
    if (!mounted) return;
    final provider = context.read<AuthProvider>();
    await provider.updateProfile(
      companyName: nome,
      companyLat: _center.latitude,
      companyLon: _center.longitude,
    );
    _showSnackBar('🏭 Empresa "$nome" marcada no mapa.');
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
    final navigator = Navigator.of(context);
    context.read<AuthProvider>().logout();
    context.read<PeerProvider>().clear();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
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
    }
    if (route.allDelivered && route.consumeCompletionEvent()) {
      _mostrarViagemConcluida(route.deliveredCount);
    }
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
    _socket.shareRoute(
      fromDriverId: widget.driverId,
      fromName: widget.driverName,
      routeJson: route.exportRouteJson(),
    );
    _showSnackBar('Rota compartilhada com os caminhões da rede.');
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
    _showSnackBar('🏁 ROTA FINALIZADA — todos os clientes visitados.');
  }

  void _avisarViagemConcluida() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
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

      _markerProvider!.purgeExpired();
      _markerProvider!.addListener(_onDataChanged);
      _routeProvider!.addListener(_onDataChanged);
      _settingsProvider!.addListener(_onDataChanged);

      _carregarAlertsOffline();
      _settingsApplied = true;
    }
  }

  void _onDataChanged() {
    if (!mounted) return;
    final quality = _settingsProvider?.renderQuality;
    if (quality != null && quality != _appliedQuality) {
      _appliedQuality = quality;
      _ensureBuildings3d();
    }
    _syncTracking();
    _renderMarkers();
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

  void _dispararAlarme(String type) {
    final s = context.read<SettingsProvider>();
    if (!s.soundEnabled) return;
    switch (type) {
      case 'radar':
        if (s.radarSound) AlertNotifier.triggerRadarWarning();
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
    _limparMapaCompleto();
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

  void _gatePremium(String feature, VoidCallback action) {
    if (_isPremium) {
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
          '$feature está disponível apenas na versão Premium.\n\n'
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

  void _abrirMenu() {
    MapMenuSheet.show(
      context,
      isPremium: context.read<AuthProvider>().driver?.isPremium ?? false,
      onProfile: _abrirPerfil,
      onTrips: () =>
          _gatePremium('Histórico de viagens', _abrirHistoricoViagens),
      onEndTrip: _finalizarViagem,
      onContacts: () =>
          _gatePremium('Contatos de estrada', _abrirContatosEstrada),
      onSettings: _abrirConfiguracoes,
      onPremium: _abrirPaymentGate,
      onClearSignals: _limparSinaisDoMapa,
      onLogout: _sairDaConta,
    );
  }

  void _mostrarInfoMarcador(MapMarkerModel m) {
    _showSnackBar(
        '${m.emoji} ${m.label ?? m.type} (segure no mapa para adicionar outro)');
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
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = context.watch<RouteProvider>().hasRoute;
    final ui = _uiExpanded;

    return Scaffold(
      body: Stack(
        children: [
          _buildMapView(),
          if (ui && hasRoute)
            Positioned(
                top: 96,
                left: _contentLeft,
                right: 16,
                child: _buildRouteSummary()),
          if (ui && _activeAlerts.isNotEmpty)
            Positioned(
              top: hasRoute ? 184 : 96,
              left: _contentLeft,
              right: 16,
              child: _buildAlertsCard(),
            ),
          if (ui)
            Positioned(
              bottom: 96,
              right: 16,
              child: SpeedHUD(
                speedKmh: _speedKmh,
                limitKmh: _speedLimitKmh,
                streetName: _streetName,
              ),
            ),
          if (ui && _peerTrucks.isNotEmpty)
            Positioned(
              bottom: 164,
              right: 16,
              child: _buildPeerBubble(),
            ),
          if (ui)
            Positioned(
              left: 12,
              top: 120,
              bottom: 24,
              child: _buildSideRail(),
            ),
          Positioned(
            top: 44,
            right: 16,
            child: _buildUiToggle(),
          ),
        ],
      ),
    );
  }

  Widget _buildUiToggle() {
    final icon = _uiExpanded ? Icons.visibility_off : Icons.visibility;
    final tooltip = _uiExpanded
        ? 'Ocultar interações e conversas'
        : 'Mostrar interações e conversas';
    return Material(
      color: const Color(0xEE101418),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => setState(() => _uiExpanded = !_uiExpanded),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteSummary() {
    final provider = context.watch<RouteProvider>();
    final route = provider.result!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEE101418),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kEmergencyRed, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route, color: Colors.redAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${route.distanceKm.toStringAsFixed(1)} km • ${route.etaText}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    Text(
                      provider.totalStops == 0
                          ? 'Sem paradas cadastradas'
                          : 'Próxima: ${provider.nextStopLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      route.heavyVehicle
                          ? '${route.trafficText} • rota para caminhão'
                          : route.trafficText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: route.hasTrafficDelay
                            ? Colors.orangeAccent
                            : Colors.greenAccent,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Mostrar rota',
                icon: const Icon(Icons.center_focus_strong,
                    color: Colors.white70),
                onPressed: _mostrarRota,
              ),
              IconButton(
                tooltip: 'Compartilhar rota',
                icon: const Icon(Icons.share_location, color: Colors.white70),
                onPressed: _compartilharRota,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => context.read<RouteProvider>().clearRoute(),
              ),
            ],
          ),
          if (provider.totalStops > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: provider.progress,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.greenAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${provider.deliveredCount}/${provider.totalStops}',
                  style:
                      const TextStyle(color: Colors.greenAccent, fontSize: 12),
                ),
              ],
            ),
            Row(
              children: [
                if (!provider.started)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _iniciarRota,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('INICIAR ROTA',
                          style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      child: const Text(
                        '🟢 ROTA EM ANDAMENTO',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (!provider.allDelivered)
                  TextButton.icon(
                    onPressed: _confirmarEntregaAtual,
                    icon: const Icon(Icons.check_circle_outline,
                        size: 18, color: Colors.greenAccent),
                    label: const Text('Confirmar',
                        style:
                            TextStyle(color: Colors.greenAccent, fontSize: 12)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC1C0303),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kEmergencyRed, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _activeAlerts.take(4).map((alert) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '[${alert.type.toUpperCase()}] ${alert.message ?? 'Sem mensagem'}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _railAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            Icon(icon, color: Colors.redAccent, size: 20),
            if (_sideRailOpen) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSideRail() {
    if (_railHidden) {
      return Material(
        color: const Color(0xEE101418),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => setState(() => _railHidden = false),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.chevron_right, color: Colors.white70, size: 20),
          ),
        ),
      );
    }
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 250) {
          setState(() {
            if (_railHidden) {
              _railHidden = false;
            } else {
              _sideRailOpen = true;
            }
          });
        } else if (v < -250) {
          setState(() {
            if (_sideRailOpen) {
              _sideRailOpen = false;
            } else {
              _railHidden = true;
            }
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: _sideRailOpen ? 168 : 56,
        decoration: BoxDecoration(
          color: const Color(0xEE101418),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kEmergencyRed, width: 1.2),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => setState(() => _sideRailOpen = !_sideRailOpen),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      child: Icon(
                        _sideRailOpen
                            ? Icons.chevron_left
                            : Icons.chevron_right,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _railHidden = true),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Icon(Icons.close, color: Colors.white70, size: 18),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 1),
              _railAction(Icons.settings, 'Tudo', _abrirMenu),
              _railAction(Icons.search, 'Buscar',
                  () => _gatePremium('Buscar ruas', _buscarRua)),
              _railAction(Icons.alt_route, 'Rota', _abrirPlanejadorDeRota),
              _railAction(
                  Icons.edit,
                  'Avisar',
                  () => _gatePremium(
                      'Avisar a comunidade', _showWriteReportDialog)),
              _railAction(Icons.emoji_emotions, 'Sinal',
                  () => _gatePremium('Sinalizar no mapa', _sinalizarNoCentro)),
              _railAction(Icons.radio, 'Rádio',
                  () => _gatePremium('Rádio da estrada', _openChatPanel)),
              _railAction(Icons.gps_fixed, 'Aqui', _recentralizarNoCaminhao),
              _railAction(Icons.streetview, 'Ver rua', _verRua),
              _railAction(Icons.factory, 'Empresa', _marcarEmpresa),
            ],
          ),
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
              color: const Color(0xEE101418),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kEmergencyRed),
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
                      style: const TextStyle(
                          color: Colors.white,
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
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
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
          backgroundColor: const Color(0xEE101418),
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
    if (_styleJsonSat == null ||
        _styleJsonStreetsLight == null ||
        _styleJsonStreetsDark == null) {
      return const ColoredBox(
        color: Color(0xFF0A0A0A),
        child:
            Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }
    return ml.MapLibreMap(
      styleString: _styleAtual,
      initialCameraPosition: ml.CameraPosition(
        target: ml.LatLng(_center.latitude, _center.longitude),
        zoom: _zoom,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        controller.onSymbolTapped.add(_onSymbolTapped);
      },
      onStyleLoadedCallback: _onStyleLoaded,
      onMapLongClick: (point, latLng) =>
          _onMapLongPress(LatLng(latLng.latitude, latLng.longitude)),
      onCameraMove: (camera) {
        _zoom = camera.zoom;
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
      compassEnabled: true,
      myLocationEnabled: false,
      trackCameraPosition: true,
      logoEnabled: false,
      attributionButtonColor: Colors.transparent,
      attributionButtonMargins: const math.Point(-1000, -1000),
    );
  }
}
