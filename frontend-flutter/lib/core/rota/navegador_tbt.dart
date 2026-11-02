import 'package:latlong2/latlong.dart';

import '../audio/voice_service.dart';
import '../network/directions_service.dart';
import '../rota/geometria_rota.dart';
import '../rota/manobra.dart';

class SnapshotNavegacao {
  final Manobra? proxima;
  final double distanciaProxima;
  final double restanteAoDestino;

  const SnapshotNavegacao({
    required this.proxima,
    required this.distanciaProxima,
    required this.restanteAoDestino,
  });
}

class NavegadorTbt {
  final VoiceService voz;
  List<Manobra> _manobras = const [];
  LatLng? _destino;
  double _total = 0;
  double _progresso = 0;
  LatLng? _ultimaPos;
  final Set<String> _falados = <String>{};
  bool _anunciouChegada = false;

  NavegadorTbt({required this.voz});

  bool get ativa => _manobras.isNotEmpty && _destino != null;

  List<Manobra> get manobras => _manobras;

  void definirRota(RouteResult rota) {
    _manobras = rota.manobras;
    _destino = rota.polyline.isEmpty ? null : rota.polyline.last;
    _total = rota.distanceMeters;
    _progresso = 0;
    _ultimaPos = rota.polyline.isEmpty ? null : rota.polyline.first;
    _falados.clear();
    _anunciouChegada = false;
    if (_manobras.isNotEmpty) {
      final primeira = _manobras.first;
      if (_textoUsavel(primeira.texto)) {
        voz.falar('Rota iniciada. ${_limparTexto(primeira.texto)}');
      }
    }
  }

  void limpar() {
    _manobras = const [];
    _destino = null;
    _total = 0;
    _progresso = 0;
    _ultimaPos = null;
    _falados.clear();
  }

  double get restanteAoDestino =>
      ativa ? (_total - _progresso).clamp(0.0, _total) : 0.0;

  SnapshotNavegacao atualizar(LatLng pos) {
    if (!ativa) {
      return const SnapshotNavegacao(
          proxima: null, distanciaProxima: 0, restanteAoDestino: 0);
    }
    final anterior = _ultimaPos;
    if (anterior != null) {
      final pulo = GeometriaRota.distancia(anterior, pos);
      if (pulo < 250) _progresso += pulo;
    }
    _ultimaPos = pos;

    final i = _indiceProxima();
    final proxima = i == null ? null : _manobras[i];
    final restanteProxima =
        i == null ? 0.0 : (_manobras[i].acumulado - _progresso);
    if (i != null) _anunciar(i, restanteProxima);

    if (restanteAoDestino <= 45 && !_anunciouChegada) {
      _anunciouChegada = true;
      voz.falar('Você chegou ao destino da rota.');
    }

    return SnapshotNavegacao(
      proxima: proxima,
      distanciaProxima: restanteProxima,
      restanteAoDestino: restanteAoDestino,
    );
  }

  int? _indiceProxima() {
    for (var i = 0; i < _manobras.length; i++) {
      if (_manobras[i].acumulado > _progresso + 2) return i;
    }
    // Quando todas as manobras ja passaram, mantem a ultima como proxima
    // (evita null e permite anuncio de chegada).
    if (_manobras.isNotEmpty) return _manobras.length - 1;
    return null;
  }

  void _anunciar(int i, double restante) {
    if (restante <= 500 && !_tem(i, 'agora')) {
      _marcar(i, 'agora');
      voz.falar('Agora. ${_limparTexto(_manobras[i].texto)}');
      return;
    }
    if (restante <= 220 && !_tem(i, '200')) {
      _marcar(i, '200');
      voz.falar('Em ${_metrosFala(restante)}. ${_limparTexto(_manobras[i].texto)}');
      return;
    }
    if (restante <= 850 && !_tem(i, '800')) {
      _marcar(i, '800');
      voz.falar(
          'Prepare-se. Em ${_metrosFala(restante)}. ${_limparTexto(_manobras[i].texto)}');
    }
  }

  bool _tem(int i, String nivel) => _falados.contains('$i-$nivel');

  void _marcar(int i, String nivel) => _falados.add('$i-$nivel');

  bool _textoUsavel(String texto) => _limparTexto(texto).length >= 6;

  String _limparTexto(String texto) {
    var t = texto.trim().split('\n').first.trim();
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    if (t.length > 120) t = t.substring(0, 120);
    if (t.isEmpty) return '';
    return t[0].toUpperCase() + t.substring(1);
  }

  String _metrosFala(double metros) {
    if (metros >= 1500) {
      final km = (metros / 1000).toStringAsFixed(1).replaceFirst('.', ',');
      return '$km quilômetros';

    }
    return '${metros.round()} metros';
  }
}
