import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';
import 'package:gps_camioneiro_pro/providers/route_provider.dart';

/// Status de uma parada de uma rota compartilhada.
class StatusParadaCompartilhada {
  static const String pendente = 'pendente';
  static const String chegou = 'chegou';
  static const String entregue = 'entregue';

  const StatusParadaCompartilhada._();
}

/// Uma rota compartilhada dentro de um grupo (comboio).
class SharedRoute {
  final String shareId;
  final String groupId;
  final String ownerDriverId;
  final String ownerName;
  final String nome;
  final List<RouteStopEntry> stops;
  final Map<int, String> progress;
  final bool isPublic;
  final DateTime createdAt;

  const SharedRoute({
    required this.shareId,
    this.groupId = '',
    required this.ownerDriverId,
    required this.ownerName,
    this.nome = '',
    this.stops = const [],
    this.progress = const {},
    this.isPublic = false,
    required this.createdAt,
  });

  /// Linha da rota (para desenhar no mapa).
  List<List<double>> get linha =>
      stops.map((s) => [s.point.longitude, s.point.latitude]).toList();

  int get totalParadas => stops.length;

  int get entregues => progress.values
      .where((s) => s == StatusParadaCompartilhada.entregue)
      .length;

  int get chegadas => progress.values
      .where((s) =>
          s == StatusParadaCompartilhada.chegou ||
          s == StatusParadaCompartilhada.entregue)
      .length;

  bool get concluida => totalParadas > 0 && entregues >= totalParadas;

  String statusDaParada(int index) =>
      progress[index] ?? StatusParadaCompartilhada.pendente;

  /// Vem do socket (receive_shared_route / route_shared_state).
  factory SharedRoute.fromSocket(Map<String, dynamic> d) {
    final stops = <RouteStopEntry>[];
    final brutos = d['stops'];
    if (brutos is List) {
      for (final s in brutos) {
        if (s is Map) {
          stops.add(RouteStopEntry.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }
    return SharedRoute(
      shareId: (d['shareId'] ?? d['share_id'] ?? '').toString(),
      groupId: (d['groupId'] ?? d['group_id'] ?? '').toString(),
      ownerDriverId: (d['fromDriverId'] ??
              d['ownerDriverId'] ??
              d['owner_driver_id'] ??
              '')
          .toString(),
      ownerName: (d['fromName'] ?? d['ownerName'] ?? '').toString(),
      nome: (d['nome'] ?? '').toString(),
      stops: stops,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (d['timestamp'] ?? DateTime.now().millisecondsSinceEpoch).toInt(),
      ),
    );
  }

  /// Vem do REST (GET /api/groups/:id/routes).
  factory SharedRoute.fromRow(Map<String, dynamic> row) {
    final payload = row['payload'];
    final p = payload is Map
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{};
    final stops = <RouteStopEntry>[];
    final brutos = p['stops'];
    if (brutos is List) {
      for (final s in brutos) {
        if (s is Map) {
          stops.add(RouteStopEntry.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }
    final progress = <int, String>{};
    final prog = p['progress'];
    if (prog is Map) {
      prog.forEach(
          (k, v) => progress[int.tryParse(k.toString()) ?? -1] = v.toString());
    }
    return SharedRoute(
      shareId: (row['id'] ?? '').toString(),
      groupId: (row['group_id'] ?? '').toString(),
      ownerDriverId: (row['driver_id'] ?? '').toString(),
      ownerName: (row['driver_name'] ?? '').toString(),
      nome: (p['nome'] ?? '').toString(),
      stops: stops,
      progress: progress,
      isPublic: row['is_public'] == true,
      createdAt: DateTime.tryParse('${row['created_at']}') ?? DateTime.now(),
    );
  }
}

/// Rotas compartilhadas do grupo, com escolha do que ver e acompanhamento
/// ao vivo das paradas de cada motorista.
///
/// - O usuario escolhe quais rotas quer ver (1 de 10, 9 de 10, todas...).
/// - Quem acompanha recebe a rota e o status de cada parada em tempo real.
class SharedRoutesProvider extends ChangeNotifier {
  final List<SharedRoute> _rotas = [];
  final Set<String> _ocultas = {};
  final Set<String> _seguindo = {};
  final Map<String, String> _minhasShares = {};
  static const _kOcultas = 'shared_routes.ocultas.v1';

  List<SharedRoute> get todas => List.unmodifiable(_rotas);

  /// Rotas que o usuario escolheu ver.
  List<SharedRoute> get visiveis =>
      _rotas.where((r) => !_ocultas.contains(r.shareId)).toList();

  int get total => _rotas.length;
  int get totalVisiveis => visiveis.length;
  Set<String> get seguindo => Set.unmodifiable(_seguindo);
  Set<String> get ocultas => Set.unmodifiable(_ocultas);
  Map<String, String> get minhasShares => Map.unmodifiable(_minhasShares);

  SharedRoutesProvider() {
    _carregarOcultas();
  }

  Future<void> _carregarOcultas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bruto = prefs.getString(_kOcultas) ?? '';
      if (bruto.isNotEmpty) {
        _ocultas.addAll(bruto.split(',').where((e) => e.isNotEmpty));
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _persistirOcultas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kOcultas, _ocultas.join(','));
    } catch (_) {}
  }

  /// Carrega as rotas compartilhadas de um grupo (pela API).
  Future<void> carregar(String groupId, Map<String, String> auth) async {
    if (groupId.isEmpty || !AppConstants.serverConfigured) return;
    try {
      final resp = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/api/groups/$groupId/routes'),
            headers: auth,
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;
      final lista = jsonDecode(resp.body);
      if (lista is! List) return;
      final novas = lista
          .whereType<Map>()
          .map((e) => SharedRoute.fromRow(Map<String, dynamic>.from(e)))
          .where((r) => r.shareId.isNotEmpty)
          .toList();
      if (novas.isEmpty) return;
      for (final r in novas) {
        final i = _rotas.indexWhere((x) => x.shareId == r.shareId);
        if (i >= 0) {
          _rotas[i] = r;
        } else {
          _rotas.insert(0, r);
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Rotas compartilhadas que chegaram pelo socket.
  void adicionarDoSocket(Map<String, dynamic> d) {
    final rota = SharedRoute.fromSocket(d);
    if (rota.shareId.isEmpty) return;
    final i = _rotas.indexWhere((x) => x.shareId == rota.shareId);
    if (i >= 0) {
      _rotas[i] = rota;
    } else {
      _rotas.insert(0, rota);
    }
    notifyListeners();
  }

  /// Registra que EU compartilhei esta rota (para eu avisar o progresso).
  void registrarMinhaShare(String shareId, String groupId) {
    _minhasShares[shareId] = groupId;
  }

  /// Progresso de uma parada (chegou/entregou) - em tempo real.
  void registrarProgresso(String shareId, int indice, String status) {
    final i = _rotas.indexWhere((r) => r.shareId == shareId);
    if (i < 0) return;
    final rota = _rotas[i];
    final novoProgresso = Map<int, String>.from(rota.progress);
    novoProgresso[indice] = status;
    _rotas[i] = SharedRoute(
      shareId: rota.shareId,
      groupId: rota.groupId,
      ownerDriverId: rota.ownerDriverId,
      ownerName: rota.ownerName,
      nome: rota.nome,
      stops: rota.stops,
      progress: novoProgresso,
      isPublic: rota.isPublic,
      createdAt: rota.createdAt,
    );
    notifyListeners();
  }

  /// Escolha do usuario: quais rotas ver (1 de 10, 9 de 10, todas...).
  void alternarVisibilidade(String shareId) {
    if (_ocultas.contains(shareId)) {
      _ocultas.remove(shareId);
    } else {
      _ocultas.add(shareId);
    }
    _persistirOcultas();
    notifyListeners();
  }

  void mostrarTodas() {
    _ocultas.clear();
    _persistirOcultas();
    notifyListeners();
  }

  void ocultarTodas() {
    _ocultas.addAll(_rotas.map((r) => r.shareId));
    _persistirOcultas();
    notifyListeners();
  }

  bool isVisivel(String shareId) => !_ocultas.contains(shareId);
  bool isSeguindo(String shareId) => _seguindo.contains(shareId);

  void marcarSeguindo(String shareId, bool seguindo) {
    if (seguindo) {
      _seguindo.add(shareId);
    } else {
      _seguindo.remove(shareId);
    }
    notifyListeners();
  }

  void remover(String shareId) {
    _rotas.removeWhere((r) => r.shareId == shareId);
    _ocultas.remove(shareId);
    _seguindo.remove(shareId);
    notifyListeners();
    _persistirOcultas();
  }

  /// Ponto medio da rota (para centralizar o mapa).
  LatLng? centroDaRota(SharedRoute rota) {
    if (rota.stops.isEmpty) return null;
    double lat = 0;
    double lon = 0;
    for (final s in rota.stops) {
      lat += s.point.latitude;
      lon += s.point.longitude;
    }
    return LatLng(lat / rota.stops.length, lon / rota.stops.length);
  }
}
