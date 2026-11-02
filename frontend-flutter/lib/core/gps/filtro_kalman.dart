import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class PosicaoFiltrada {
  final LatLng pos;
  final double precisao;
  final bool estimada;

  const PosicaoFiltrada({
    required this.pos,
    required this.precisao,
    this.estimada = false,
  });
}

class FiltroKalman {
  double _lat = 0;
  double _lon = 0;
  double _vn = 0;
  double _ve = 0;
  double _incLat = 1e9;
  double _incLon = 1e9;
  DateTime _t = DateTime(0);

  void resetar() {
    _lat = 0;
    _lon = 0;
    _vn = 0;
    _ve = 0;
    _incLat = 1e9;
    _incLon = 1e9;
    _t = DateTime(0);
  }

  PosicaoFiltrada filtrar(LatLng pos, double precisaoMetros) {
    final agora = DateTime.now();
    const variacao = 0.02;
    final r = precisaoMetros <= 0 ? 8.0 : prevencao(precisaoMetros);
    if (_t.year <= 1971) {
      _lat = pos.latitude;
      _lon = pos.longitude;
      _incLat = r;
      _incLon = r;
      _vn = 0;
      _ve = 0;
      _t = agora;
      return PosicaoFiltrada(
          pos: pos, precisao: precisaoMetros.toDouble());
    }
    final dt = agora.difference(_t).inMilliseconds / 1000.0;
    final passo = dt <= 0 ? 0.1 : dt.clamp(0.1, 10.0);
    final n = (pos.latitude - _lat) / passo;
    final e = (pos.longitude - _lon) / passo;
    final novoVn = _vn + (n - _vn) * 0.25;
    final novoVe = _ve + (e - _ve) * 0.25;

    _incLat = _incLat + passo * variacao;
    _incLon = _incLon + passo * variacao;
    final kN = _incLat / (_incLat + r * r);
    final kE = _incLon / (_incLon + r * r);
    final latPrevista = _lat + _vn * passo;
    final lonPrevista = _lon + _ve * passo;
    _lat = latPrevista + kN * (pos.latitude - latPrevista);
    _lon = lonPrevista + kE * (pos.longitude - lonPrevista);
    _vn = novoVn;
    _ve = novoVe;
    _incLat = (1 - kN) * _incLat;
    _incLon = (1 - kE) * _incLon;
    _t = agora;
    return PosicaoFiltrada(
      pos: LatLng(_lat, _lon),
      precisao: math.sqrt(_incLat * _incLat + _incLon * _incLon),
    );
  }

  double prevencao(double metros) => metros * metros;

  PosicaoFiltrada prevista({required Duration desdeUltimoGps}) {
    if (_t.year <= 1971) {
      return PosicaoFiltrada(
          pos: LatLng(_lat, _lon), precisao: 999, estimada: true);
    }
    final dt = desdeUltimoGps.inMilliseconds / 1000.0;
    final passo = dt <= 0 ? 0.1 : dt.clamp(0.1, 45.0);
    final lat = _lat + _vn * passo;
    final lon = _lon + _ve * passo;
    final precisao = math.sqrt(_incLat * _incLat + _incLon * _incLon) +
        passo * passo * 0.6;
    return PosicaoFiltrada(
        pos: LatLng(lat, lon), precisao: precisao, estimada: true);
  }
}
