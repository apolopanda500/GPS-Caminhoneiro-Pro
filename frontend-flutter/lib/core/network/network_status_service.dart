import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

enum NetKind { none, mobile, wifi, other }

/// Detecta o tipo de conexao para adaptar o app:
/// - em dados moveis: mapa raster (leve), sem fotos dos colegas, GPS menos frequente
/// - em WiFi: mapa vetorial detalhado, fotos e 3D liberados
class NetworkStatusService {
  static final NetworkStatusService _instance = NetworkStatusService._internal();
  factory NetworkStatusService() => _instance;
  NetworkStatusService._internal();

  final _controller = StreamController<NetKind>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  NetKind _current = NetKind.other;

  NetKind get current => _current;
  Stream<NetKind> get onChange => _controller.stream;

  bool get isMobile => _current == NetKind.mobile;
  bool get isOffline => _current == NetKind.none;

  /// O app nao limita recursos por tipo de rede: 4G/5G recebe o mesmo
  /// mapa 3D, as mesmas fotos e as mesmas rotas do WiFi.
  bool get fullQuality => true;

  Future<void> start() async {
    try {
      _current = _map(await Connectivity().checkConnectivity());
      _controller.add(_current);
    } catch (_) {}
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      _current = _map(results);
      _controller.add(_current);
    });
  }

  NetKind _map(List<ConnectivityResult> results) {
    if (results.isEmpty) return NetKind.none;
    if (results.contains(ConnectivityResult.mobile)) return NetKind.mobile;
    if (results.contains(ConnectivityResult.wifi)) return NetKind.wifi;
    if (results.contains(ConnectivityResult.ethernet)) return NetKind.wifi;
    if (results.contains(ConnectivityResult.vpn)) return NetKind.other;
    if (results.contains(ConnectivityResult.none)) return NetKind.none;
    return NetKind.other;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
