import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/network/socket_client.dart';
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
import 'package:gps_camioneiro_pro/views/map/widgets/fps_overlay.dart';
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
  bool _styleLoaded = false;
  final Set<String> _imagesAdded = {};

  LatLng _center = _fallbackCenter;
  LatLng? _currentPosition;
  double _zoom = 14;
  double _speedKmh = 0;

  bool _isSatellite = true;
  bool _is3d = false;
  bool _uiExpanded = true;
  bool _sideRailOpen = false;
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
    if (!mounted) return;
    setState(() => _styleJsonSat = sat);
  }

  String get _styleAtual {
    if (_isSatellite) return _styleJsonSat ?? '';
    final settings = context.read<SettingsProvider>();
    final base = settings.nightMode
        ? AppConstants.styleStreetsUrl
        : AppConstants.styleStreetsLightUrl;
    final version = settings.mapCacheVersion;
    return version == 0 ? base : '$base?v=$version';
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
      if (isFirst) {
        _moverCamera(newPos, zoom: 15, bearing: 0, tilt: 0);
      } else {
        _renderMarkers();
      }
    });
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
  }

  Future<void> _ensureBuildings3d() async {
    final c = _mapController;
    if (c == null || _isSatellite) return;
    final enabled = context.read<SettingsProvider>().buildings3d;
    try {
      await c.removeLayer('truck_buildings_3d');
    } catch (_) {}
    if (!enabled) return;
    try {
      await c.addFillExtrusionLayer(
        'openmaptiles',
        'truck_buildings_3d',
        const ml.FillExtrusionLayerProperties(
          fillExtrusionColor: '#2A0A0A',
          fillExtrusionOpacity: 0.85,
          fillExtrusionHeight: [
            'coalesce',
            ['get', 'render_height'],
            8
          ],
          fillExtrusionBase: [
            'coalesce',
            ['get', 'render_min_height'],
            0
          ],
        ),
        sourceLayer: 'building',
        belowLayerId: 'road_oneway',
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
        final emoji = (p['truckIcon'] ?? '🚚').toString();
        final imgName = 'peer_$emoji';
        await _addImageOnce(imgName, await MapIcons.truckIcon(emoji));
        await c.addSymbol(
          ml.SymbolOptions(
            geometry: ml.LatLng(lat, lon),
            iconImage: imgName,
            iconSize: 0.5,
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
      backgroundColor: const Color(0xEE0A0A0A),
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
      backgroundColor: const Color(0xEE0A0A0A),
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

  void _recentralizarNoCaminhao() {
    final target = _currentPosition ?? _fallbackCenter;
    setState(() => _is3d = false);
    _moverCamera(target, zoom: 15, bearing: 0, tilt: 0);
  }

  void _toggle3d() {
    final target = _currentPosition ?? _center;
    final enable = !_is3d;
    setState(() => _is3d = enable);
    _moverCamera(target,
        zoom: _zoom, bearing: enable ? 25 : 0, tilt: enable ? 50 : 0);
  }

  void _toggleLayer() {
    final next = !_isSatellite;
    setState(() => _isSatellite = next);
    final style = _styleAtual;
    if (style.isNotEmpty) _mapController?.setStyle(style);
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
      _isSatellite = _settingsProvider!.layer == MapLayerMode.satellite;

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
      isSatellite: _isSatellite,
      is3d: _is3d,
      isPremium: context.read<AuthProvider>().driver?.isPremium ?? false,
      onProfile: _abrirPerfil,
      onToggleLayer: _toggleLayer,
      onToggle3d: _toggle3d,
      onTrips: _abrirHistoricoViagens,
      onEndTrip: _finalizarViagem,
      onContacts: _abrirContatosEstrada,
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
    final showFps = context.watch<SettingsProvider>().showFps;
    final targetFps = context.watch<SettingsProvider>().targetFps;
    final ui = _uiExpanded;

    return Scaffold(
      body: Stack(
        children: [
          _buildMapView(),
          if (ui && hasRoute)
            Positioned(
                top: 96, left: 16, right: 16, child: _buildRouteSummary()),
          if (ui && _activeAlerts.isNotEmpty)
            Positioned(
              top: hasRoute ? 176 : 96,
              left: 16,
              right: 16,
              child: _buildAlertsCard(),
            ),
          if (ui && showFps)
            Positioned(
              bottom: 96,
              left: _sideRailOpen ? 196 : 84,
              child: FpsOverlay(targetFps: targetFps),
            ),
          if (ui)
            Positioned(
              bottom: 96,
              right: 16,
              child: SpeedHUD(speedKmh: _speedKmh),
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
            child: Column(
              children: [
                _buildUiToggle(),
                const SizedBox(height: 10),
                _buildTrackingButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUiToggle() {
    final icon = _uiExpanded ? Icons.fullscreen_exit : Icons.fullscreen;
    final tooltip = _uiExpanded ? 'Minimizar controles' : 'Mostrar controles';
    return Material(
      color: const Color(0xEE0A0A0A),
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

  Future<void> _toggleDay() async {
    final settings = context.read<SettingsProvider>();
    if (settings.trackingEnabled) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF151515),
          title: const Text('Encerrar o dia?',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'O GPS e o compartilhamento de posição serão pausados. A rota e os alertas continuam salvos para o próximo expediente.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar rodando'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kEmergencyRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Encerrar dia'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      await settings.endDay();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expediente encerrado. GPS pausado.')),
      );
    } else {
      await settings.startDay();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bom trabalho! GPS e expediente iniciados.')),
      );
    }
  }

  Widget _buildTrackingButton() {
    final settings = context.watch<SettingsProvider>();
    final on = settings.trackingEnabled;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: on ? const Color(0xEE1B5E20) : const Color(0xEE37474F),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _toggleDay,
            child: Tooltip(
              message: on
                  ? 'Encerrar expediente e pausar GPS'
                  : 'Iniciar expediente e GPS',
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Icon(
                  Icons.power_settings_new,
                  color: on ? Colors.greenAccent : Colors.white54,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          on ? 'GPS ON' : 'GPS OFF',
          style: TextStyle(
            color: on ? Colors.greenAccent : Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRouteSummary() {
    final provider = context.watch<RouteProvider>();
    final route = provider.result!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEE0A0A0A),
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
            if (!provider.allDelivered)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _confirmarEntregaAtual,
                  icon: const Icon(Icons.check_circle_outline,
                      size: 18, color: Colors.greenAccent),
                  label: const Text('Confirmar entrega',
                      style:
                          TextStyle(color: Colors.greenAccent, fontSize: 12)),
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(icon, color: Colors.redAccent, size: 22),
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
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 200) {
          setState(() => _sideRailOpen = true);
        } else if (v < -200) {
          setState(() => _sideRailOpen = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: _sideRailOpen ? 168 : 56,
        decoration: BoxDecoration(
          color: const Color(0xEE0A0A0A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kEmergencyRed, width: 1.2),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => setState(() => _sideRailOpen = !_sideRailOpen),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Icon(
                    _sideRailOpen ? Icons.chevron_left : Icons.chevron_right,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              _railAction(Icons.menu, 'Menu', _abrirMenu),
              _railAction(Icons.search, 'Buscar', _buscarRua),
              _railAction(Icons.alt_route, 'Rota', _abrirPlanejadorDeRota),
              _railAction(Icons.edit, 'Avisar', _showWriteReportDialog),
              _railAction(Icons.emoji_emotions, 'Sinal', _sinalizarNoCentro),
              _railAction(Icons.radio, 'Rádio', _openChatPanel),
              _railAction(Icons.gps_fixed, 'Aqui', _recentralizarNoCaminhao),
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
              color: const Color(0xEE0A0A0A),
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
          backgroundColor: const Color(0xEE0A0A0A),
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
    if (_styleJsonSat == null) {
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
      minMaxZoomPreference: const ml.MinMaxZoomPreference(3, 20),
      compassEnabled: true,
      myLocationEnabled: false,
      trackCameraPosition: true,
      logoEnabled: false,
    );
  }
}
