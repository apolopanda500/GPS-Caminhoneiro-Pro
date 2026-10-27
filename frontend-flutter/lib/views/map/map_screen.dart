import 'dart:async';
import 'dart:convert';
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
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/native/servico_rastreio.dart';
import 'package:gps_camioneiro_pro/core/map/traffic_layer.dart';
import 'package:gps_camioneiro_pro/core/rota/geometria_rota.dart';
import 'package:gps_camioneiro_pro/core/rota/monitor_paradas.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/onda_aviso.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/rede_screen.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/radio_sheet.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/weather_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/map_controls_panel.dart';
import 'package:gps_camioneiro_pro/core/network/socket_client.dart';
import 'package:gps_camioneiro_pro/core/network/speed_limit_service.dart';
import 'package:gps_camioneiro_pro/core/network/geocoding_service.dart';
import 'package:gps_camioneiro_pro/core/network/network_status_service.dart';
import 'package:gps_camioneiro_pro/data/models/alert_model.dart';
import 'package:gps_camioneiro_pro/data/models/map_marker_model.dart';
import 'package:gps_camioneiro_pro/data/models/trip_model.dart';
import 'package:gps_camioneiro_pro/core/utils/location_handler.dart';
import 'package:gps_camioneiro_pro/core/utils/confirm.dart';
import 'package:gps_camioneiro_pro/core/utils/estado_uf.dart';
import 'package:gps_camioneiro_pro/core/database/local_cache.dart';
import 'package:gps_camioneiro_pro/providers/alert_notifier.dart';
import 'package:gps_camioneiro_pro/providers/alert_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/providers/marker_provider.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/weather_provider.dart';
import 'package:gps_camioneiro_pro/providers/peer_provider.dart';
import 'package:gps_camioneiro_pro/providers/shared_routes_provider.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/shared_routes_panel.dart';
import 'package:gps_camioneiro_pro/providers/trip_provider.dart';
import 'package:gps_camioneiro_pro/providers/route_provider.dart';
import 'package:gps_camioneiro_pro/providers/group_provider.dart';
import 'package:gps_camioneiro_pro/providers/map_layers_provider.dart';
import 'package:gps_camioneiro_pro/views/auth/login_screen.dart';
import 'package:gps_camioneiro_pro/views/map/utils/map_icons.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/report_dialog.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/speed_hud.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/marker_dialog.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/street_search_sheet.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/chat_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/peer_profile_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/route_planner_sheet.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/route_table_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/alerts_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/floating_panel.dart';
import 'package:gps_camioneiro_pro/views/contacts/contacts_screen.dart';
import 'package:gps_camioneiro_pro/views/settings/settings_screen.dart';
import 'package:gps_camioneiro_pro/views/profile/profile_screen.dart';

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
  final Set<String> _sinaisOcultosSessao = {};
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

  double _heading = 0;
  CameraMode _cameraMode = CameraMode.norte;
  int _foraDaRotaAmostras = 0;
  DateTime _ultimoRecalculoAutomatico = DateTime.fromMillisecondsSinceEpoch(0);
  bool _recalculandoAutomatico = false;
  bool? _trafegoAplicado;
  bool _modoEscolherEmpresa = false;
  String _nomeEmpresaPendente = '';
  final bool _uiExpanded = true;
  bool _alertsPanelClosed = false;

  /// O painel de sinais foi aberto pelo botao (aparece mesmo sem sinais).
  bool _mostrarAlertas = false;
  bool _routePanelClosed = false;

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
    // O app entra em modo de estrada: servico em primeiro plano ligado para
    // o GPS e a rede continuarem com a tela apagada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ligado = context.read<SettingsProvider>().trackingEnabled;
      _sincronizarServicoDeFundo(ligado);
    });
    // Mini janela (Picture-in-Picture): mesma tecnologia do YouTube Premium.
    ServicoRastreio.instancia.onPipChanged((emPip) {
      if (!mounted) return;
      setState(() => _emPip = emPip);
    });
  }

  /// O app esta na mini janela flutuante?
  bool _emPip = false;

  /// A camera segue o caminhao automaticamente.
  bool _seguirVeiculo = true;

  /// Quando o app moveu a camera pela ultima vez.
  DateTime _ultimaCameraProgramatica = DateTime.fromMillisecondsSinceEpoch(0);

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
        if (novo) _alertsPanelClosed = false;
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
      final mapa = Map<String, dynamic>.from(data);
      // Rota compartilhada: entra na lista do grupo (com as paradas).
      context.read<SharedRoutesProvider>().adicionarDoSocket(mapa);
      _handleSharedRoute(mapa);
    });

    // Estado completo da rota de quem eu acompanho (para desenhar no mapa).
    _socket.onRouteSharedState((data) {
      if (!mounted) return;
      final mapa = Map<String, dynamic>.from(data);
      context.read<SharedRoutesProvider>().adicionarDoSocket(mapa);
      setState(() {});
      _renderRotasCompartilhadas();
    });

    // Progresso ao vivo: uma parada mudou (chegou / entregou).
    _socket.onRouteProgress((data) {
      if (!mounted) return;
      final mapa = Map<String, dynamic>.from(data);
      final shareId = (mapa['shareId'] ?? '').toString();
      final indice = (mapa['stopIndex'] as num?)?.toInt() ?? -1;
      final status = (mapa['status'] ?? '').toString();
      if (shareId.isEmpty || indice < 0) return;
      context
          .read<SharedRoutesProvider>()
          .registrarProgresso(shareId, indice, status);
      setState(() {});
      _renderRotasCompartilhadas();
    });

    _socket.onRouteFollowError((data) {
      if (!mounted) return;
      _showSnackBar(
          'Não dá para acompanhar: ${data['error'] ?? 'rota indisponível'}');
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
      intervalMilliseconds: settings.intervaloGpsReal * 1000,
      highAccuracy: true,
    ).listen((pos) {
      final newPos = LatLng(pos.latitude, pos.longitude);
      final anterior = _currentPosition;
      final isFirst = anterior == null;
      final deslocamento =
          anterior == null ? 0.0 : GeometriaRota.distancia(anterior, newPos);

      // Rumo real do GPS. Quando o aparelho nao informa o rumo (parado ou
      // recem-ligado), usa o sentido do deslocamento entre duas posicoes.
      final velocidade = pos.speed >= 0 ? pos.speed * 3.6 : 0.0;
      var rumo = _heading;
      if (pos.heading >= 0 && pos.heading.isFinite && velocidade >= 3) {
        rumo = pos.heading;
      } else if (deslocamento > 2) {
        rumo = GeometriaRota.bearing(anterior!, newPos);
      }

      _onTripSample(newPos, pos.speed >= 0 ? pos.speed * 3.6 : 0);
      setState(() {
        _currentPosition = newPos;
        _speedKmh = pos.speed >= 0 ? pos.speed * 3.6 : 0;
        _heading = isFirst
            ? rumo
            : GeometriaRota.suavizarBearing(_heading, rumo, 0.45);
        if (_center == _fallbackCenter) _center = newPos;
      });
      // As camadas de previsao (chuva, vento, temperatura) sao calculadas
      // sobre a posicao do caminhao.
      if (!mounted) return;
      context.read<MapLayersProvider>().definirPosicao(newPos);
      _socket.sendLocationUpdate(
          lat: newPos.latitude,
          lon: newPos.longitude,
          driverId: widget.driverId);
      _validarEntregas(newPos);
      _detectarChegadaSaida(newPos);
      unawaited(_atualizarEstadoLocal());
      _verificarLimiteVelocidade(newPos, _speedKmh);
      // Clima em tempo real: busca assim que o GPS define a posicao.
      if (mounted) {
        unawaited(context
            .read<WeatherProvider>()
            .refresh(lat: newPos.latitude, lon: newPos.longitude));
      }
      if (isFirst) {
        _aplicarCameraNoVeiculo(newPos, instant: true);
      } else if (_seguirVeiculo) {
        // A camera segue o caminhao no modo escolhido (2D, navegacao 3D ou
        // visao do caminhoneiro) ate o motorista mexer no mapa.
        _aplicarCameraNoVeiculo(newPos);
      }
      unawaited(_verificarForaDaRota(newPos));
      _renderMarkers();
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

  /// Interface compacta da mini janela (Picture-in-Picture): velocidade,
  /// proxima parada e o botao de voltar ao app.
  Widget _miniJanela(BuildContext context) {
    final cor = _settingsProvider?.overlayColor ?? kEmergencyRed;
    final proxima = context.watch<RouteProvider>().nextStopLabel;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              kDarkBlack.withValues(alpha: 0.85),
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_speedKmh.round()} km/h',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                proxima.isEmpty ? 'Sem rota' : proxima,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            IconButton(
              tooltip: 'Voltar ao app',
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              color: Colors.white,
              icon: const Icon(Icons.open_in_full, size: 16),
              onPressed: () => ServicoRastreio.instancia.entrarNoPip(),
            ),
          ],
        ),
      ),
    );
  }

  /// Abre a mini janela flutuante (Picture-in-Picture): a mesma tecnologia
  /// que o YouTube Premium usa para continuar em segundo plano. A janela
  /// pode ser arrastada, redimensionada e minimizada pelo usuario.
  /// Adiciona uma parada na rota depois que ela ja foi montada ou iniciada.
  /// Estado (UF) onde o caminhao esta agora. A busca e o filtro usam isso:
  /// nunca aparece resultado de outro estado.
  ///
  /// Resposta imediata pela caixa geografica e refino pelo geocodificador
  /// reverso (que acerta a cidade de Florianopolis, Recife e assim por diante).
  String? get _estadoLocal =>
      _estadoLocalCache ?? estadoDaPosicao(_currentPosition ?? _center);

  /// Atualiza a UF do caminhao (em segundo plano, sem travar o GPS).
  Future<void> _atualizarEstadoLocal() async {
    final pos = _currentPosition;
    if (pos == null) return;
    final uf = await EstadoUf.instancia.descobrir(pos);
    if (!mounted || uf == null) return;
    if (uf != _estadoLocalCache) {
      setState(() => _estadoLocalCache = uf);
    }
  }

  String? _estadoLocalCache;

  Future<void> _adicionarParadaNaRota() async {
    final resultado = await StreetSearchSheet.show(
      context,
      near: _currentPosition,
      stateName: _estadoLocal,
    );
    if (resultado == null || !mounted) return;
    final route = context.read<RouteProvider>();
    route.addStop(RouteStopEntry(
      label: resultado.displayName,
      customer: resultado.displayName.split(',').first.trim(),
      neighborhood: resultado.region ?? '',
      point: LatLng(resultado.latitude, resultado.longitude),
      radiusMeters: 150,
    ));
    _showSnackBar('Parada adicionada. Recalculando a rota...');
    await _recalcularRota();
  }

  /// Recalcula a rota depois de editar as paradas.
  Future<void> _recalcularRota() async {
    final route = context.read<RouteProvider>();
    if (route.stops.isEmpty) return;
    final origem = _currentPosition ?? _center;
    _foraDaRotaAmostras = 0;
    final ok = route.started
        ? await route.replanFrom(origem)
        : await route.plan(origem);
    if (!ok) {
      _showSnackBar('Não foi possível recalcular a rota.');
    }
  }

  /// Abre o painel unico "Mapa e graficos" (camada, transito, clima,
  /// qualidade, FPS, cor da linha e aparencia).
  void _abrirMapaGraficos() {
    final settings = context.read<SettingsProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MapControlsPanel(
        onCamada: (modo) => settings.setLayer(modo),
        onMostrarUi: (_) {},
        uiVisivel: true,
      ),
    );
  }

  /// Rede de caminhoneiros: chat, grupos, contatos e empresa.
  void _abrirRede() {
    final auth = context.read<AuthProvider>();
    RedeScreen.show(
      context,
      driverId: auth.driver?.driverId ?? widget.driverId,
      driverName: auth.driver?.name ?? 'Motorista',
      authHeaders: auth.authHeaders,
      onContatos: _abrirContatosEstrada,
      onEmpresa: _marcarEmpresa,
      onSinalizar: _abrirSinalizacoes,
    );
  }

  /// Radio da estrada (agora direto no mapa).
  void _abrirRadio() {
    RadioSheet.open(context);
  }

  /// Clima e previsao (agora direto no mapa).
  void _abrirClima() {
    final clima = context.read<WeatherProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => WeatherPanel(
        latitude: clima.lastLatitude,
        longitude: clima.lastLongitude,
      ),
    );
  }

  /// Limpa a rota: some com a linha, as paradas, a empresa, o painel e
  /// qualquer estado de chegada - o mapa fica limpo para a proxima viagem.
  Future<void> _limparRotaDoMapa() async {
    final route = context.read<RouteProvider>();
    if (route.stops.isEmpty && route.result == null) {
      _showSnackBar('Nao ha rota para limpar.');
      return;
    }
    final resposta = await confirmarAcao(
      context,
      titulo: 'Limpar a rota?',
      mensagem: 'Some com a linha da rota, as paradas e o retorno a empresa. '
          'O historico de viagens continua salvo.',
      textoConfirmar: 'LIMPAR',
      destrutivo: true,
      icone: Icons.delete_sweep,
    );
    if (resposta != Confirmacao.confirmado) return;
    if (!mounted) return;

    route.clear();
    // Marcadores que pertencem a rota tambem saem.
    final markers = context.read<MarkerProvider>();
    for (final m in markers.markers.toList()) {
      if (m.type == 'rota' || m.type == 'parada') {
        markers.removeMarker(m.id);
      }
    }
    setState(() {
      _routePanelClosed = true;
      _monitorParadas.resetar();
      _sinalSelecionadoId = null;
    });
    _renderMarkers();
    _showSnackBar('Rota limpa do mapa.');
  }

  /// Onda de aviso em curso (posicao na tela + cor).
  ({Offset posicao, Color cor})? _onda;

  /// Momento do ultimo aviso: evita encher a rede de sinais iguais.
  DateTime? _ultimoAviso;

  /// Compartilha a posicao com a rede: emite uma onda, avisa os caminhoes
  /// por perto (sinal no mapa de todos) e mostra o alerta na lista.
  void _compartilharLocalizacao() {
    final pos = _currentPosition ?? _center;
    final agora = DateTime.now();
    final ultimo = _ultimoAviso;
    if (ultimo != null &&
        agora.difference(ultimo) < const Duration(minutes: 2)) {
      final falta = 2 - agora.difference(ultimo).inMinutes;
      _showSnackBar('Aguarde $falta min para avisar de novo.');
      return;
    }
    _ultimoAviso = agora;

    final auth = context.read<AuthProvider>();
    final driverId = auth.driver?.driverId ?? widget.driverId;
    final nome = auth.driver?.name ?? 'Motorista';

    // Sinal no mapa de todos (vai para o banco e chega pela rede).
    _socket.sendRoadAlert(
      driverId: driverId,
      type: 'sinal',
      message: '$nome esta passando por aqui',
      lat: pos.latitude,
      lon: pos.longitude,
    );
    // Mensagem no chat da rodovia (todo mundo ouve).
    _socket.sendChatMessage(
      driverId: driverId,
      driverName: nome,
      message: 'Passando por aqui. Seguam com cuidado.',
      lat: pos.latitude,
      lon: pos.longitude,
    );

    // Onda na tela, no ponto do caminhao.
    final size = MediaQuery.of(context).size;
    setState(() {
      _onda = (
        posicao: Offset(size.width / 2, size.height / 2),
        cor: kEmergencyRed
      );
    });
    _showSnackBar('📡 Posicao compartilhada com a rede.');
  }

  void _moverCamera(LatLng target,
      {required double zoom,
      double bearing = 0,
      double tilt = 0,
      bool instant = false}) {
    final c = _mapController;
    if (c == null || !_styleLoaded) return;
    _ultimaCameraProgramatica = DateTime.now();
    c.animateCamera(
      ml.CameraUpdate.newCameraPosition(
        ml.CameraPosition(
          target: ml.LatLng(target.latitude, target.longitude),
          zoom: zoom,
          bearing: bearing,
          tilt: tilt,
        ),
      ),
      duration: instant
          ? const Duration(milliseconds: 0)
          : const Duration(milliseconds: 450),
    );
  }

  /// Posiciona a camera conforme o modo escolhido, usando o rumo real do
  /// caminhao. A visao do caminhoneiro (cabine) aponta a camera para frente
  /// e inclina o mapa, deixando o veiculo no rodape da tela.
  void _aplicarCameraNoVeiculo(LatLng pos, {bool instant = false}) {
    final rumo = _heading;
    switch (_cameraMode) {
      case CameraMode.norte:
        _moverCamera(
          pos,
          zoom: 15,
          instant: instant,
        );
        break;
      case CameraMode.navegacao:
        _moverCamera(
          pos,
          zoom: 16.6,
          bearing: rumo,
          tilt: 50,
          instant: instant,
        );
        break;
      case CameraMode.cabine:
        final alvo = GeometriaRota.deslocar(pos, rumo, 30);
        _moverCamera(
          alvo,
          zoom: 17.4,
          bearing: rumo,
          tilt: 60,
          instant: instant,
        );
        break;
    }
  }

  /// Proxima camera de acompanhamento (2D -> navegacao 3D -> cabine 3D).
  /// Nao religa o modo centralizado: a camera so volta ao caminhao pelo
  /// botao de centralizar.
  void _alternarCamera() {
    const modos = CameraMode.values;
    final proximo = modos[(_cameraMode.index + 1) % modos.length];
    setState(() => _cameraMode = proximo);
    unawaited(context.read<SettingsProvider>().setCameraMode(proximo));
    final pos = _currentPosition;
    if (pos != null && _seguirVeiculo) {
      _aplicarCameraNoVeiculo(pos, instant: true);
    }
    _showSnackBar('Camera: ${_nomeCamera(proximo)}');
  }

  String _nomeCamera(CameraMode modo) {
    return switch (modo) {
      CameraMode.norte => '2D norte',
      CameraMode.navegacao => '3D navegacao',
      CameraMode.cabine => 'visao do caminhoneiro',
    };
  }

  IconData get _iconeCamera {
    return switch (_cameraMode) {
      CameraMode.norte => Icons.explore,
      CameraMode.navegacao => Icons.navigation,
      CameraMode.cabine => Icons.remove_red_eye,
    };
  }

  /// Saiu do tracado? Recalcula sozinho mantendo as entregas que faltam.
  Future<void> _verificarForaDaRota(LatLng pos) async {
    if (!mounted) return;
    final route = context.read<RouteProvider>();
    if (!route.started ||
        !route.hasRoute ||
        route.loading ||
        route.nextStopIndex == null ||
        _recalculandoAutomatico) {
      _foraDaRotaAmostras = 0;
      return;
    }
    final polyline = route.result?.polyline;
    if (polyline == null || polyline.length < 2) return;

    final distancia = GeometriaRota.distanciaAteRota(polyline, pos);
    if (distancia <= 80) {
      _foraDaRotaAmostras = 0;
      return;
    }

    _foraDaRotaAmostras++;
    // Confirma o desvio em 3 leituras seguidas: evita recalcular por causa
    // de um erro momentaneo do GPS (predio, tunel, viaduto).
    if (_foraDaRotaAmostras < 3) return;
    final agora = DateTime.now();
    if (agora.difference(_ultimoRecalculoAutomatico) <
        const Duration(seconds: 25)) {
      return;
    }

    _foraDaRotaAmostras = 0;
    _ultimoRecalculoAutomatico = agora;
    _recalculandoAutomatico = true;
    _showSnackBar('Fora da rota. Recalculando...');
    try {
      final ok = await route.replanFrom(pos);
      if (!mounted) return;
      if (ok) {
        _showSnackBar('Rota recalculada. Siga o novo tracado.');
        await _renderMarkers();
      }
    } finally {
      _recalculandoAutomatico = false;
    }
  }

  /// Sinal escolhido no painel de sinais: o mapa destaca o local dele.
  String? _sinalSelecionadoId;

  /// Toca em um sinal no painel: destaca o ponto no mapa e leva a camera
  /// ate ele. Toca de novo no mesmo sinal: volta a selection.
  void _selecionarSinal(AlertModel? alert) {
    setState(() => _sinalSelecionadoId = alert?.id);
    if (alert == null) {
      _renderMarkers();
      return;
    }
    if (alert.latitude == 0 && alert.longitude == 0) {
      _showSnackBar('Este sinal nao tem localizacao.');
      return;
    }
    _renderMarkers();
    _moverCamera(
      LatLng(alert.latitude, alert.longitude),
      zoom: 16,
      bearing: _bearing,
      tilt: 0,
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
    // As camadas de clima (chuva, nuvens, vento) entram DEPOIS dos
    // marcadores: assim a chuva aparece por cima do caminhao, que e o que
    // o motorista precisa ver.
    await _aplicarCamadaDeTrafego();
    await _aplicarCamadasDeClima();
    final target = _currentPosition;
    if (target != null && _seguirVeiculo) {
      _aplicarCameraNoVeiculo(target, instant: true);
    }
  }

  /// Liga (ou desliga) a camada de transito em tempo real (TomTom).
  Future<void> _aplicarCamadaDeTrafego() async {
    final c = _mapController;
    if (c == null || !_styleLoaded) return;
    final ligado = _settingsProvider?.trafficLayer ?? true;
    if (ligado && CamadaTrafego.disponivel) {
      await CamadaTrafego.instancia.aplicar(c);
    } else {
      await CamadaTrafego.instancia.remover(c);
    }
    _trafegoAplicado = ligado;
  }

  /// Liga (ou re-aplica, apos trocar o estilo) as camadas de clima
  /// (nuvens, vento, relevo, radar) com o controller atual do mapa.
  Future<void> _aplicarCamadasDeClima() async {
    final c = _mapController;
    if (c == null || !_styleLoaded) return;
    if (!mounted) return;
    try {
      await context.read<MapLayersProvider>().ligar(c);
    } catch (_) {}
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
  final Map<String, String?> _fotoServidorCache = {};

  Future<Uint8List?> _fotoDoMotorista(Map peer) async {
    final url = (peer['truckPhotoUrl'] ?? peer['avatarUrl'])?.toString() ?? '';
    final driverId = (peer['driverId'] ?? '').toString();
    var fonte = url;
    if (fonte.isEmpty || fonte.startsWith('https://placehold.co')) {
      // Sem foto no payload: busca no servidor pela foto do motorista.
      final doServidor = await _buscarFotoNoServidor(driverId);
      if (doServidor == null) return null;
      fonte = doServidor;
    }
    final cached = _photoCache[fonte];
    if (cached != null) return cached;
    try {
      final Uint8List bytes;
      if (fonte.startsWith('data:')) {
        // O banco guarda a foto como data URL (base64) - decodifica local.
        final partes = fonte.split(',');
        if (partes.length < 2) return null;
        bytes = base64Decode(partes[1]);
      } else {
        final response = await http.get(Uri.parse(fonte)).timeout(
              const Duration(seconds: 8),
            );
        if (response.statusCode != 200) return null;
        bytes = response.bodyBytes;
      }
      _photoCache[fonte] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Foto do motorista no servidor (quando o peer chega sem foto no payload).
  Future<String?> _buscarFotoNoServidor(String driverId) async {
    if (driverId.isEmpty || !AppConstants.serverConfigured) return null;
    if (_fotoServidorCache.containsKey(driverId)) {
      return _fotoServidorCache[driverId];
    }
    try {
      final resp = await http
          .get(Uri.parse('${AppConstants.baseUrl}/api/auth/photo/$driverId'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) {
        _fotoServidorCache[driverId] = null;
        return null;
      }
      final dados = jsonDecode(resp.body);
      final foto =
          (dados is Map ? (dados['truckPhotoUrl'] ?? dados['avatarUrl']) : null)
              ?.toString();
      final util = (foto != null &&
              foto.isNotEmpty &&
              !foto.startsWith('https://placehold.co'))
          ? foto
          : null;
      _fotoServidorCache[driverId] = util;
      return util;
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
      var pontos = route.polyline;
      final pos = _currentPosition;
      // A linha acompanha o caminhao: o trecho ja percorrido sai do mapa e
      // so fica um pequeno rastro atras do veiculo.
      if (pos != null &&
          GeometriaRota.distanciaAteRota(route.polyline, pos) < 150) {
        pontos = GeometriaRota.restante(route.polyline, pos);
      }
      final geometry =
          pontos.map((p) => ml.LatLng(p.latitude, p.longitude)).toList();
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
          lineColor: _settingsProvider?.corRota ?? '#1D4ED8',
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
    final hiddenIds = <String>{..._hiddenIdsSnapshot, ..._sinaisOcultosSessao};
    final sinalSelecionado = _sinalSelecionadoId;
    for (final a
        in alertasSnapshot.where((a) => a.latitude != 0 && a.longitude != 0)) {
      if (hiddenIds.contains(a.id)) continue;
      final emDestaque = a.id == sinalSelecionado;
      await c.addSymbol(
        ml.SymbolOptions(
          geometry: ml.LatLng(a.latitude, a.longitude),
          iconImage: 'icon_alert',
          iconSize: emDestaque ? 0.85 : 0.42,
        ),
        {
          'kind': 'alert',
          'id': a.id,
          'type': a.type,
          'message': a.message,
          if (emDestaque) 'selected': true,
        },
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
        // Cada caminhao tem o SEU icone: o nome da imagem inclui o id do
        // motorista e a versao da foto. Sem isso, todos os peers que nao tem
        // foto compartilhavam a mesma imagem (todos iguais no mapa).
        final peerId = (p['driverId'] ?? '').toString();
        final fotoUrl =
            (p['truckPhotoUrl'] ?? p['avatarUrl'])?.toString() ?? '';
        final imgName =
            'peer_${helper ? 'h' : 'd'}_${peerId}_${fotoUrl.hashCode.abs()}_${emoji.hashCode.abs()}';
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
        await _addImageOnce(imgNameMe,
            await MapIcons.photoBadge(minhaFoto, helper: false, mine: true));
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

    await _renderRotasCompartilhadas();
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
        if (index != null) _mostrarInformacaoDaParada(index);
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
      backgroundColor: sheetBackground(context),
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
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
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
        backgroundColor: sheetBackground(context),
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
    // O chat nao e mais uma janela flutuante: abre sob demanda (sem poluir a
    // tela) e continua acessivel pelas Configuracoes.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _superficie(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
              leading:
                  const Icon(Icons.emoji_emotions, color: Colors.redAccent),
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
    _showSnackBar(
        '🏭 Empresa "${nome.isEmpty ? 'Empresa' : nome}" marcada no mapa.');
  }

  void _recentralizarNoCaminhao() {
    final target = _currentPosition ?? _fallbackCenter;
    setState(() => _seguirVeiculo = true);
    _aplicarCameraNoVeiculo(target);
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

  /// Falas automaticas de aproximacao: quando o caminhao passa de 1 km,
  /// 500 m e 20 m da proxima parada, o app fala uma vez em cada faixa.
  /// O aviso final fica entre 10 e 20 m, junto do ponto real de entrega.
  static const double _raioChegadaKm = 0.02;
  static const List<double> _faixasKm = [1.0, 0.5, _raioChegadaKm];
  int _faixaAnunciada = -1;

  /// Fala a aproximacao da proxima parada (uma vez por faixa).
  void _anunciarAproximacao(RouteProvider route, int total) {
    final km = route.distanciaProximaParadaKm;
    if (km == null || km > _faixasKm.first) {
      _faixaAnunciada = -1;
      return;
    }
    var faixa = 0;
    for (var i = 0; i < _faixasKm.length; i++) {
      if (km <= _faixasKm[i]) faixa = i;
    }
    if (_faixaAnunciada == faixa) return;
    _faixaAnunciada = faixa;

    final proxima = route.nextStopLabel;
    if (proxima.isEmpty || proxima.startsWith('Rota conclu')) return;
    final texto = km <= _raioChegadaKm
        ? 'Chegando: $proxima.'
        : 'Faltam ${(km * 1000).round()} metros para $proxima.';
    // Som de aproximacao (slot "Proxima parada") e depois a voz.
    unawaited(context.read<SonsProvider>().tocar(SlotSom.proximaParada));
    unawaited(VoiceService.instance.falar(texto));
  }

  /// Monitor de chegada e saida das paradas (logica testada com milhares
  /// de simulacoes em test/simulacao_jornadas_test.dart).
  final MonitorDeParadas _monitorParadas = MonitorDeParadas();

  /// Detecta a chegada e a saida das paradas pelo GPS, em tempo real.
  ///
  /// - Chegou (entrou no raio da parada): vibra, toca o sino e fala a parada.
  /// - Comecou a andar e saiu (passou de 100-200 m): toca o som e anuncia a
  ///   proxima parada automaticamente.
  void _detectarChegadaSaida(LatLng pos) {
    final route = context.read<RouteProvider>();
    if (route.stops.isEmpty) return;

    final eventos = _monitorParadas.processar(
      totalParadas: route.stops.length,
      dentroDe: (i) => route.dentroDoRaio(i, pos),
      saiuDe: (i) => route.saiuDaParada(i, pos),
      velocidadeKmh: _speedKmh,
    );
    if (eventos.isEmpty) return;

    final total = route.totalStops - (route.companyStopIndex != null ? 1 : 0);

    for (final ev in eventos) {
      if (ev.chegou) {
        // O som e a voz da chegada sao tocados pela rota (um lugar so, para
        // o sino nao tocar duas vezes). Aqui fica so a vibracao.
        HapticFeedback.heavyImpact();
      } else if (ev.saiu) {
        // Som de SAÍDA (nao e o sino de chegada) e a proxima parada.
        unawaited(context.read<SonsProvider>().tocar(SlotSom.saidaParada));
        unawaited(VoiceService.instance.proximaParada(
          numero: route.proximoNumero,
          nome: route.proximoNome,
          distanciaKm: route.distanciaProximaParadaKm,
          totalParadas: total,
        ));
      }
    }
  }

  void _validarEntregas(LatLng pos) {
    final route = context.read<RouteProvider>();
    if (route.totalStops == 0) return;
    final before = route.deliveredCount;
    route.updatePosition(pos);
    final total = route.totalStops - (route.companyStopIndex != null ? 1 : 0);

    // Chegou na parada: fala na hora (com a distancia real do momento) e
    // vibra, sem esperar a confirmacao da entrega.
    final chegada = route.consumeArrivalEvent();
    if (chegada != null) {
      HapticFeedback.heavyImpact();
      _emitirProgressoRota(chegada, StatusParadaCompartilhada.chegou, pos);
      unawaited(_falarChegada(route, total, chegada));
    } else {
      _anunciarAproximacao(route, total);
    }

    if (route.deliveredCount > before) {
      HapticFeedback.mediumImpact();
      _showSnackBar('Entrega validada: ${route.nextStopLabel}');
      _renderMarkers();
      // O comboio que acompanha a rota ve a parada como "entregue" na hora.
      _emitirProgressoRota(
        route.nextStopIndex == null ? -1 : route.nextStopIndex!,
        StatusParadaCompartilhada.entregue,
        pos,
      );
      // Sequencia da chegada: primeiro o SINO, depois a VOZ (com o radio
      // abaixado) dizendo a proxima parada e a distancia.
      unawaited(_tocarChegadaEVoz(route, total));
    }
    if (route.allDelivered && route.consumeCompletionEvent()) {
      _mostrarViagemConcluida(route.deliveredCount);
    }
  }

  /// Fala a chegada na parada com os dados atualizados do momento.
  /// Toca o **sino de chegada** e o **sino de estação** (uma vez so).
  Future<void> _falarChegada(
      RouteProvider route, int total, int indiceParada) async {
    final audio = context.read<AudioProvider>();
    await audio.tocarChegada();
    if (!mounted) return;
    unawaited(context.read<SonsProvider>().tocar(SlotSom.sinoEstacao));
    final numero = route.numeroDaParada(indiceParada);
    await VoiceService.instance.chegadaNaParada(
      numero,
      total,
      proximoNumero: route.proximoNumero,
      proximoNome: route.proximoNome,
      distanciaProximaKm: route.distanciaProximaParadaKm,
    );
  }

  /// Depois da entrega: **so a voz** anuncia a proxima parada (o sino ja
  /// tocou na chegada - nao toca duas vezes).
  Future<void> _tocarChegadaEVoz(RouteProvider route, int total) async {
    if (!mounted) return;
    await VoiceService.instance.chegadaNaParada(
      route.deliveredCount,
      total,
      proximoNumero: route.proximoNumero,
      proximoNome: route.proximoNome,
      distanciaProximaKm: route.distanciaProximaParadaKm,
    );
  }

  /// Id (UUID v4) de uma rota compartilhada.
  String _novoShareId() {
    final r = math.Random();
    String bloco(int n) =>
        List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${bloco(8)}-${bloco(4)}-4${bloco(3)}-'
        '${'89ab'[r.nextInt(4)]}${bloco(3)}-${bloco(12)}';
  }

  /// Avisa o comboio que acompanha a rota: a parada X chegou/entregou.
  void _emitirProgressoRota(int indice, String status, LatLng pos) {
    if (indice < 0) return;
    final minhas = context.read<SharedRoutesProvider>().minhasShares;
    if (minhas.isEmpty) return;
    for (final shareId in minhas.keys) {
      _socket.sendRouteProgress(
        shareId: shareId,
        stopIndex: indice,
        status: status,
        lat: pos.latitude,
        lon: pos.longitude,
        driverId: widget.driverId,
        driverName: widget.driverName,
      );
    }
  }

  /// Desenha as rotas compartilhadas que o usuario escolheu ver.
  Future<void> _renderRotasCompartilhadas() async {
    final c = _mapController;
    if (c == null || !_styleLoaded || !mounted) return;
    final provider = context.read<SharedRoutesProvider>();
    final visiveis = provider.visiveis;

    // Limpa as linhas anteriores.
    for (final rota in provider.todas) {
      final id = 'rota_shared_${rota.shareId}';
      try {
        await c.removeLayer('${id}_linha');
        await c.removeLayer('${id}_paradas');
      } catch (_) {}
      try {
        await c.removeSource(id);
      } catch (_) {}
    }

    for (final rota in visiveis) {
      if (rota.stops.length < 2) continue;
      final id = 'rota_shared_${rota.shareId}';
      final coords = rota.linha;
      final source = {
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': coords,
        },
        'properties': <String, dynamic>{'shareId': rota.shareId},
      };
      try {
        await c.addGeoJsonSource(id, source);
        await c.addLineLayer(
          id,
          '${id}_linha',
          const ml.LineLayerProperties(
            lineColor: '#00E676',
            lineWidth: 4,
            lineOpacity: 0.85,
            lineDasharray: [2, 1.4],
          ),
        );
      } catch (_) {}
    }
  }

  /// Acompanha a rota de outro motorista (com as paradas ao vivo).
  void _seguirRota(SharedRoute rota) {
    final provider = context.read<SharedRoutesProvider>();
    provider.marcarSeguindo(rota.shareId, true);
    _socket.followRoute(
      shareId: rota.shareId,
      driverId: widget.driverId,
      name: widget.driverName,
    );
    _showSnackBar('Acompanhando a rota de ${rota.ownerName}.');
    setState(() {});
  }

  void _pararDeSeguirRota(SharedRoute rota) {
    final provider = context.read<SharedRoutesProvider>();
    provider.marcarSeguindo(rota.shareId, false);
    _socket.unfollowRoute(shareId: rota.shareId);
    setState(() {});
  }

  /// Remove a rota compartilhada do grupo (so o dono).
  void _removerRotaCompartilhada(SharedRoute rota) {
    final provider = context.read<SharedRoutesProvider>();
    provider.remover(rota.shareId);
    setState(() {});
    _renderRotasCompartilhadas();
    _showSnackBar('Rota removida do grupo.');
  }

  /// Centraliza o mapa na rota compartilhada.
  void _centralizarRotaCompartilhada(SharedRoute rota) {
    final centro = context.read<SharedRoutesProvider>().centroDaRota(rota);
    if (centro == null) return;
    _moverCamera(centro, zoom: 15.5);
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
        // Cada rota compartilhada tem um id (UUID): e o que liga o
        // acompanhamento (quem acompanha) com o progresso ao vivo das paradas.
        final shareId = _novoShareId();
        _socket.shareRoute(
          fromDriverId: widget.driverId,
          fromName: widget.driverName,
          routeJson: route.exportRouteJson(),
          groupId: grupo?.id,
          shareId: shareId,
        );
        if (grupo?.id != null) {
          context
              .read<SharedRoutesProvider>()
              .registrarMinhaShare(shareId, grupo!.id);
        }
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
    _foraDaRotaAmostras = 0;
    _ultimoRecalculoAutomatico = DateTime.fromMillisecondsSinceEpoch(0);
    _seguirVeiculo = true;
    final pos = _currentPosition;
    if (pos != null) _aplicarCameraNoVeiculo(pos);
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
    unawaited(
        VoiceService.instance.falar('Rota concluida. Volte para a empresa.'));
    _showSnackBar('🏁 ROTA FINALIZADA — todos os clientes visitados.');
  }

  void _avisarViagemConcluida() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    unawaited(context.read<AudioProvider>().tocarChegada());
    unawaited(VoiceService.instance.chegadaNaEmpresa());
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

  /// Tocar num ponto da rota **nao** confirma a entrega: mostra o local e a
  /// informacao da parada. A confirmacao continua sendo um ato deliberado.
  void _mostrarInformacaoDaParada(int index) {
    final route = context.read<RouteProvider>();
    if (index < 0 || index >= route.totalStops) return;
    final stop = route.stops[index];
    final status = route.statusOf(index);
    final pos = _currentPosition;
    final distancia = pos == null
        ? null
        : const Distance().as(LengthUnit.Meter, pos, stop.point) / 1000;

    final statusTexto = switch (status) {
      StopStatus.delivered => 'Entrega concluída',
      StopStatus.arrived => 'Você está na parada',
      StopStatus.pending => 'Ainda não chegou',
    };

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
                Text(
                  'Parada ${index + 1}',
                  style: tema.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  stop.customer.isNotEmpty ? stop.customer : stop.label,
                  style: tema.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (stop.neighborhood.isNotEmpty)
                  Text(stop.neighborhood, style: tema.textTheme.bodySmall),
                const SizedBox(height: 12),
                _linhaInfo(sheetContext, Icons.place, statusTexto),
                _linhaInfo(
                  sheetContext,
                  Icons.straighten,
                  'Posição: ${stop.point.latitude.toStringAsFixed(5)}, '
                  '${stop.point.longitude.toStringAsFixed(5)}',
                ),
                if (distancia != null)
                  _linhaInfo(
                    sheetContext,
                    Icons.near_me,
                    'A ${distancia.toStringAsFixed(1)} km de você',
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _moverCamera(stop.point, zoom: 16, bearing: _bearing);
                        },
                        icon: const Icon(Icons.center_focus_strong, size: 18),
                        label: const Text('VER NO MAPA'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _confirmarParada(index);
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('CONFIRMAR'),
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

  Widget _linhaInfo(BuildContext context, IconData icone, String texto) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 16, color: tema.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: tema.textTheme.bodySmall),
          ),
        ],
      ),
    );
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
    // Os sinais que estao na tela ficam ocultos ate o fim da sessao: sem
    // isso a varredura de proximidade (socket) os recoloca na hora e o
    // usuario acha que o botao nao fez nada.
    for (final a in _activeAlerts) {
      _sinaisOcultosSessao.add(a.id);
    }
    final daProvider = context.read<AlertProvider>().alerts;
    for (final a in daProvider) {
      _sinaisOcultosSessao.add(a.id);
    }
    _sinalSelecionadoId = null;
    context.read<MarkerProvider>().clear();
    context.read<AlertProvider>().clearAlerts();
    context.read<RouteProvider>().clear();
    setState(() => _activeAlerts.clear());
    _renderMarkers();
    _showSnackBar(
        'Mapa limpo: sinais, alertas e rota removidos (ficam ocultos nesta viagem).');
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
    _limparMapaAoFinalizar();
  }

  /// Ao encerrar a viagem o mapa fica limpo: some a linha da rota, as
  /// paradas e os marcadores de caminhao (o historico ja foi salvo).
  void _limparMapaAoFinalizar() {
    final route = context.read<RouteProvider>();
    route.clear();
    _sinaisOcultosSessao.clear();
    setState(() {
      _routePanelClosed = true;
      _sinalSelecionadoId = null;
      _faixaAnunciada = -1;
    });
    _renderMarkers();
    // Sem viagem em andamento o app pode voltar ao normal: o servico em
    // primeiro plano e desligado.
    unawaited(ServicoRastreio.instancia.parar());
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
      _cameraMode = _settingsProvider!.cameraMode;

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
      _trafegoAplicado = null;
      setState(() => _layerMode = camada);
      final style = _styleAtual;
      if (style.isNotEmpty) _mapController?.setStyle(style);
    }
    final trafego = _settingsProvider?.trafficLayer;
    if (trafego != null && trafego != _trafegoAplicado) {
      _trafegoAplicado = trafego;
      unawaited(_aplicarCamadaDeTrafego());
    }
    final camera = _settingsProvider?.cameraMode;
    if (camera != null && camera != _cameraMode && mounted) {
      setState(() => _cameraMode = camera);
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
  /// - **Ultra**: camadas de clima ligadas.
  void _aplicarPerfilDeGraficos(RenderQuality quality) {
    final camadas = context.read<MapLayersProvider>();
    if (quality == RenderQuality.economy) {
      if (camadas.radar) camadas.setRadar(false);
      if (camadas.nuvens) camadas.setNuvens(false);
      if (camadas.relevo) camadas.setRelevo(false);
    }
    if (quality == RenderQuality.ultra) {
      if (!camadas.radar) camadas.setRadar(true);
      if (!camadas.nuvens) camadas.setNuvens(true);
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
    _sincronizarServicoDeFundo(tracking);
  }

  /// Mantem o app vivo em segundo plano (servico em primeiro plano do
  /// Android): com a tela apagada o GPS, a rede V2X e as vozes continuam
  /// funcionando, como nos apps de video/musica premium.
  Future<void> _sincronizarServicoDeFundo(bool tracking) async {
    try {
      if (tracking) {
        await ServicoRastreio.instancia.iniciar(
          titulo: 'GPS Caminhoneiro Pro',
          texto: 'Rastreando sua viagem - GPS e rede ativos',
        );
        // Pede a isencao do economizador de bateria (o Android mata o app
        // em segundo plano sem isso).
        await ServicoRastreio.instancia.pedirIsencaoDeBateria();
        // Tela acesa: o motorista nao trava a tela durante a viagem.
        await ServicoRastreio.instancia.manterTelaLigada(true);
      } else {
        await ServicoRastreio.instancia.parar();
        await ServicoRastreio.instancia.manterTelaLigada(false);
      }
    } catch (_) {}
  }

  Future<void> _carregarAlertsOffline() async {
    try {
      final rows = await LocalCache.getCachedAlerts();
      if (!mounted || rows.isEmpty) return;
      setState(() {
        _activeAlerts
          ..clear()
          ..addAll(rows
              .map((e) => AlertModel.fromJson(Map<String, dynamic>.from(e)))
              .where((a) => !_sinaisOcultosSessao.contains(a.id)));
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
      if (_sinaisOcultosSessao.contains(a.id)) continue;
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
          unawaited(context.read<SonsProvider>().tocar(SlotSom.alertaRadar));
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          onLimparSinais: _limparSinaisDoMapa,
          onSairDaConta: _sairDaConta,
        ),
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
    final result = await StreetSearchSheet.show(
      context,
      near: _currentPosition,
      stateName: _estadoLocal,
    );
    if (result == null) return;
    final target = LatLng(result.latitude, result.longitude);
    setState(() => _center = target);
    _moverCamera(target, zoom: 16);
    _showSnackBar('📍 ${result.displayName}');
  }

  void _abrirPlanejadorDeRota() {
    RoutePlannerSheet.show(context, origin: _currentPosition);
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
  bool get _isHelper => context.read<AuthProvider>().driver?.isHelper ?? false;

  /// Painel de grupos (comboios) + modo estrito de visibilidade.
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
    // Na mini janela (Picture-in-Picture) a interface e compacta: sem
    // paineis, so o essencial do GPS.
    final ui = _uiExpanded && !_emPip;
    final size = MediaQuery.of(context).size;
    // O painel de rotas so aparece quando existe rota de verdade: painel
    // vazio sobre o mapa so atrapalhava.
    final totalParadas = context.watch<RouteProvider>().totalStops;

    return Scaffold(
      body: Stack(
        children: [
          _buildMapView(),
          if (_emPip) _miniJanela(context),
          // Onda de aviso (compartilhar posicao / marcar sinal).
          if (_onda != null)
            Positioned.fill(
              child: OndaAviso(
                posicao: _onda!.posicao,
                cor: _onda!.cor,
                aoTerminar: () {
                  if (mounted) setState(() => _onda = null);
                },
              ),
            ),
          // AGENTE B: na tela do mapa ficam SO os 5 elementos pedidos:
          // km/h, centralizar camera, rota, buscar e sinais.
          // Tudo o mais (clima, camadas/graficos, radio, IA, chat, caminhoes
          // proximos) foi para as Configuracoes.
          if (ui)
            FloatingPanel(
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
            ),
          if (ui)
            FloatingPanel(
              id: 'acoes',
              initial: const Offset(16, 120),
              width: 138,
              height: 210,
              dragWholeChild: true,
              resizable: false,
              minimizedChild: const Icon(Icons.apps, size: 18),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.start,
                children: [
                  _botaoFlutuante(Icons.search, 'Buscar rua', _buscarRua),
                  _botaoFlutuante(
                      Icons.alt_route, 'Rota', _abrirPlanejadorDeRota),
                  _botaoFlutuante(
                      Icons.tune, 'Mapa e graficos', _abrirMapaGraficos),
                  _botaoFlutuante(
                      Icons.group, 'Rede de caminhoneiros', _abrirRede),
                  _botaoFlutuante(
                      Icons.radio_outlined, 'Radio da estrada', _abrirRadio),
                  _botaoFlutuante(
                      Icons.cloud_outlined, 'Clima e previsao', _abrirClima),
                  _botaoFlutuante(
                      Icons.campaign,
                      'Compartilhar posicao com a rede',
                      _compartilharLocalizacao),
                  _botaoFlutuante(Icons.add_location_alt,
                      'Emitir sinal no mapa', _emitirSinalNoMapa),
                  _botaoFlutuante(
                      Icons.settings, 'Configuracoes', _abrirConfiguracoes),
                  _botaoParar(),
                ],
              ),
            ),
          // Centralizar a camera: botao solto (igual o km/h), fora do grupo.
          if (ui)
            FloatingPanel(
              id: 'centralizar',
              initial: Offset(16, size.height - 420),
              width: 52,
              height: 52,
              dragWholeChild: true,
              resizable: false,
              minimizedChild: Icon(
                  _seguirVeiculo
                      ? Icons.center_focus_strong
                      : Icons.center_focus_weak,
                  size: 18),
              child: _botaoCentralizar(),
            ),
          // Modo de camera: 2D norte -> 3D navegacao -> visao do caminhoneiro.
          if (ui)
            FloatingPanel(
              id: 'camera_modo',
              initial: Offset(16, size.height - 480),
              width: 52,
              height: 52,
              dragWholeChild: true,
              resizable: false,
              minimizedChild: Icon(_iconeCamera, size: 18),
              child: _botaoFlutuante(
                  _iconeCamera,
                  'Camera: ${_nomeCamera(_cameraMode)} (toque para trocar)',
                  _alternarCamera),
            ),
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
                  onAddStop: _adicionarParadaNaRota,
                  onRecalcular: _recalcularRota,
                  onLimparRota: _limparRotaDoMapa,
                  canManageRoute: !_isHelper,
                  sharedRoutesChild: SharedRoutesPanel(
                    driverId: widget.driverId,
                    onSeguir: _seguirRota,
                    onPararDeSeguir: _pararDeSeguirRota,
                    onRemover: _removerRotaCompartilhada,
                    onCentralizar: _centralizarRotaCompartilhada,
                  ),
                ),
              );
            }),
          // AGENTE B: painel de sinais com minimizar/fechar (evita travar a tela).
          if (ui &&
              !_alertsPanelClosed &&
              (_activeAlerts.isNotEmpty || _mostrarAlertas))
            FloatingPanel(
              id: 'alerts',
              initial: Offset(_contentLeft, 96),
              width: 300,
              height: 260,
              minimizedChild: const Icon(Icons.warning_amber_rounded, size: 20),
              handle: _buildPuxador(
                  'Sinais da estrada', Icons.warning_amber_rounded),
              child: AlertsPanel(
                alerts: List<AlertModel>.unmodifiable(_activeAlerts),
                surface: _superficie(context),
                accent: _settingsProvider?.overlayColor ?? kEmergencyRed,
                onClose: () => setState(() {
                  _alertsPanelClosed = true;
                  _mostrarAlertas = false;
                }),
                onCriarSinal: _abrirSinalizacoes,
                selectedId: _sinalSelecionadoId,
                onSelect: _selecionarSinal,
              ),
            ),
          // Sinais recebidos com o painel fechado: badge para reabrir.
          if (ui && _activeAlerts.isNotEmpty && _alertsPanelClosed)
            FloatingPanel(
              id: 'alerts_badge',
              initial: Offset(_contentLeft, 96),
              width: 56,
              height: 56,
              dragWholeChild: true,
              minimizedChild: const Icon(Icons.warning_amber_rounded, size: 20),
              child: FloatingActionButton(
                heroTag: 'fab_alerts_badge',
                tooltip: '${_activeAlerts.length} sinais — toque para ver',
                onPressed: () => setState(() => _alertsPanelClosed = false),
                backgroundColor: _superficie(context),
                foregroundColor: Colors.amber,
                elevation: 2,
                child: const Icon(Icons.warning_amber_rounded, size: 22),
              ),
            ),
        ],
      ),
    );
  }

  /// Botao flutuante pequeno (usado na coluna de acoes do mapa).
  /// Modo centralizado (camera segue o caminhao) com ativar/desativar:
  /// ligado = a camera acompanha; toque de novo = a tela fica solta.
  /// Arrastar o mapa tambem solta a tela; volta ao centro so pelo botao.
  Widget _botaoCentralizar() {
    final accent = _settingsProvider?.overlayColor ?? kEmergencyRed;
    final ativo = _seguirVeiculo;
    return Tooltip(
      message: ativo
          ? 'Modo centralizado ativo (toque para deixar a tela solta)'
          : 'Ativar modo centralizado (centralizar no caminhao)',
      child: Material(
        color: ativo ? accent : _superficie(context),
        shape: CircleBorder(
          side: BorderSide(
            color: accent.withValues(alpha: 0.65),
            width: 1.3,
          ),
        ),
        elevation: 4,
        shadowColor: Colors.black54,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            if (ativo) {
              setState(() => _seguirVeiculo = false);
              _showSnackBar('📷 Tela solta. Centralize pelo botao quando quiser.');
            } else {
              _recentralizarNoCaminhao();
            }
          },
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              ativo ? Icons.center_focus_strong : Icons.center_focus_weak,
              color: ativo ? Colors.white : accent,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _botaoFlutuante(IconData icone, String dica, VoidCallback onTap) {
    final accent = _settingsProvider?.overlayColor ?? kEmergencyRed;
    return Tooltip(
      message: dica,
      child: Material(
        color: _superficie(context),
        shape: CircleBorder(
          side: BorderSide(
            color: accent.withValues(alpha: 0.65),
            width: 1.3,
          ),
        ),
        elevation: 4,
        shadowColor: Colors.black54,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icone, color: accent, size: 20),
          ),
        ),
      ),
    );
  }

  /// Emite um sinal no mapa (aviso para a rede) no ponto atual.
  void _emitirSinalNoMapa() {
    _showWriteReportDialog();
  }

  /// Botao de camada do mapa: alterna Satelite -> Ruas -> 3D (detalhado) com
  /// um toque. O icone mostra em qual modo o mapa esta.
  /// Troca a camada do mapa (satelite -> ruas -> 3D) e avisa o usuario.
  /// Botao vermelho de encerrar a viagem: fica sempre a vista na coluna de
  /// acoes do mapa (no menu ele ficava longe e era facil esquecer).
  ///
  /// Ele **para o GPS de verdade**: salva a viagem (se houver), cancela o
  /// fluxo de posicao, encerra o expediente e desliga o servico em primeiro
  /// plano (a notificacao some).
  /// Botao do GPS: **verde para ligar** e **vermelho para desligar**.
  ///
  /// Desligar encerra a viagem, cancela o fluxo de posicao e desliga o
  /// servico em primeiro plano; ligar volta o rastreio com a tela acesa.
  Widget _botaoParar() {
    final ligado = context.watch<SettingsProvider>().trackingEnabled;
    final cor = ligado ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
    return Tooltip(
      message: ligado ? 'Encerrar viagem, limpar rotas e reiniciar GPS' : 'Ligar o GPS',
      child: Material(
        color: cor,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black54,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: ligado ? _pararGpsEEncerrarViagem : _ligarGps,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              ligado ? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }

  /// Liga o GPS: inicia o expediente, o servico em primeiro plano e a tela
  /// mantida acesa.
  Future<void> _ligarGps() async {
    final settings = context.read<SettingsProvider>();
    if (!settings.trackingEnabled) {
      await settings.startDay();
    }
    await _sincronizarServicoDeFundo(true);
    _startLocationStream();
    _showSnackBar('GPS ligado. Boa viagem!');
  }

  /// Para tudo e reinicia pronto para a proxima rota: salva a viagem
  /// percorrida, limpa a rota/sinais do mapa e volta o GPS ligado de novo,
  /// ja cafacado para o proximo trajeto (nao precisa religar na mao).
  Future<void> _pararGpsEEncerrarViagem() async {
    final resposta = await confirmarAcao(
      context,
      titulo: 'Encerrar viagem?',
      mensagem: 'A viagem atual sera salva, as rotas e sinais serao limpos e '
          'o GPS reinicia automaticamente para a proxima viagem.',
      textoConfirmar: 'ENCERRAR E REINICIAR',
      destrutivo: true,
      icone: Icons.stop_rounded,
    );
    if (resposta != Confirmacao.confirmado) return;
    if (!mounted) return;

    // 1) Salva a viagem percorrida (se houver trecho) e limpa o mapa (rota,
    //    paradas e sinais ocultos desta viagem).
    await _finalizarViagem(notify: false);
    if (!mounted) return;
    _limparMapaAoFinalizar();

    // 2) Reinicia o rastreio automaticamente para a proxima viagem: novo
    //    expediente, servico em primeiro plano e fluxo de posicao ativo.
    if (!mounted) return;
    await _ligarGps();
    if (!mounted) return;
    _showSnackBar('Viagem encerrada e mapa limpo. GPS pronto para a proxima rota.');
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
              size: 14,
              color: _settingsProvider?.overlayColor ?? kEmergencyRed),
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
      onCameraIdle: () {
        // Se a ultima movimentacao foi do app, continua seguindo o caminhao.
        // Se o motorista mexeu no mapa, para de seguir ate "centralizar".
        final desdeProgramatica =
            DateTime.now().difference(_ultimaCameraProgramatica);
        if (desdeProgramatica < const Duration(milliseconds: 1200)) return;
        if (_seguirVeiculo) setState(() => _seguirVeiculo = false);
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
