import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WeatherNow {
  final double tempC;
  final double precipMm;
  final double windKmh;
  final int code;
  final DateTime capturedAt;

  const WeatherNow({
    required this.tempC,
    required this.precipMm,
    required this.windKmh,
    required this.code,
    required this.capturedAt,
  });
}

class WeatherHour {
  final DateTime time;
  final double tempC;
  final double precipMm;
  final int precipProb;
  final double windKmh;
  final int code;

  const WeatherHour({
    required this.time,
    required this.tempC,
    required this.precipMm,
    required this.precipProb,
    required this.windKmh,
    required this.code,
  });
}

class WeatherDay {
  final DateTime date;
  final double tempMin;
  final double tempMax;
  final double precipSum;
  final int code;

  const WeatherDay({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.precipSum,
    required this.code,
  });
}

/// Clima em tempo real (Open-Meteo, sem chave) + motor de dicas da "IA de bordo".
class WeatherProvider extends ChangeNotifier {
  WeatherNow? _now;
  List<WeatherHour> _hours = [];
  List<WeatherDay> _days = [];
  bool _loading = false;
  String? _error;
  double? _lat;
  double? _lon;
  DateTime? _updatedAt;
  String? _lastAlertKey;

  WeatherNow? get now => _now;

  /// Ultima posicao consultada (para abrir o clima de qualquer tela).
  double? get lastLatitude => _lat;
  double? get lastLongitude => _lon;
  List<WeatherHour> get hours => List.unmodifiable(_hours);
  List<WeatherDay> get days => List.unmodifiable(_days);
  bool get loading => _loading;
  String? get error => _error;
  DateTime? get updatedAt => _updatedAt;

  String emojiForCode(int? code) {
    if (code == null) return '☁️';
    if (code == 0) return '☀️';
    if (code <= 3) return '⛅';
    if (code <= 48) return '🌫️';
    if (code <= 57) return '🌦️';
    if (code <= 67) return '🌧️';
    if (code <= 77) return '🌨️';
    if (code <= 82) return '🌧️';
    if (code <= 86) return '🌨️';
    if (code <= 99) return '⛈️';
    return '☁️';
  }

  String? ventoNivel() {
    final n = _now;
    if (n == null) return null;
    if (n.windKmh >= 60) return 'Vento muito forte (${n.windKmh.round()} km/h)';
    if (n.windKmh >= 40) return 'Vento forte (${n.windKmh.round()} km/h)';
    return null;
  }

  String? chuvaNivel() {
    final n = _now;
    if (n == null) return null;
    if (n.precipMm >= 7.6) return 'Chuva forte agora';
    if (n.precipMm >= 2.5) return 'Chuva moderada agora';
    return null;
  }

  /// Alerta prioritário para voz/sino (nulo se nenhum perigo no momento).
  String? perigoParaVoz() {
    final n = _now;
    if (n == null) return null;
    if (n.code >= 95) return 'Tempestade na área. Busque abrigo seguro.';
    if (chuvaNivel() != null) return chuvaNivel();
    if (ventoNivel() != null) return ventoNivel();
    return null;
  }

  String? alertaDuplicado(String perigo) {
    final key = '$perigo@${DateTime.now().hour}';
    if (_lastAlertKey == key) return key;
    _lastAlertKey = key;
    return null;
  }  List<String> dicasIA() {
    final tips = <String>[];
    final n = _now;
    if (n == null) return tips;
    final proximaChuva = _hours
        .take(4)
        .where((h) => h.precipProb >= 60 || h.precipMm >= 1)
        .toList();
    if (n.code >= 95) tips.add('Rodovia com risco de alagamento. Reduza.');
    if (proximaChuva.isNotEmpty) {
      tips.add(
          'Chuva prevista nas próximas horas (${proximaChuva.first.precipProb}%).');
    }
    if (ventoNivel() != null) {
      tips.add('Carroceria alta: cuidado com rajadas laterais em pontes.');
    }
    final t = n.tempC;
    if (t >= 33) {
      tips.add('Calor extremo: revise pressão dos pneus e arrefecimento.');
    } else if (t <= 5) {
      tips.add('Frio/possível geada: uso de correntes pode ser necessário.');
    }
    if (tips.isEmpty) tips.add('Condições favoráveis na estrada.');
    return tips;
  }

  /// `force=false` evita requisições repetidas (cache de 15 minutos).
  Future<void> refresh({
    required double lat,
    required double lon,
    bool force = false,
  }) async {
    final cacheOk = _updatedAt != null &&
        DateTime.now().difference(_updatedAt!) < const Duration(minutes: 15) &&
        _lat != null &&
        _lon != null &&
        (lat - _lat!).abs() < 0.3 &&
        (lon - _lon!).abs() < 0.3;
    if (!force && (cacheOk || _loading)) return;
    _loading = true;
    _error = null;
    _lat = lat;
    _lon = lon;
    notifyListeners();
    try {
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast'
          '?latitude=$lat&longitude=$lon'
          '&current=temperature_2m,precipitation,weather_code,wind_speed_10m'
          '&hourly=temperature_2m,precipitation,precipitation_probability,'
          'weather_code,wind_speed_10m'
          '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,'
          'weather_code'
          '&timezone=auto&wind_speed_unit=kmh&forecast_days=5');
      final resp =
          await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final cur = body['current'] as Map<String, dynamic>? ?? {};
      _now = WeatherNow(
        tempC: _num(cur['temperature_2m']) ?? 0,
        precipMm: _num(cur['precipitation']) ?? 0,
        windKmh: _num(cur['wind_speed_10m']) ?? 0,
        code: (_num(cur['weather_code']) ?? 0).toInt(),
        capturedAt: DateTime.now(),
      );
      final hourList = (body['hourly'] as Map<String, dynamic>? ?? {});
      final times = (hourList['time'] as List?) ?? [];
      final temps = (hourList['temperature_2m'] as List?) ?? [];
      final prec = (hourList['precipitation'] as List?) ?? [];
      final probs = (hourList['precipitation_probability'] as List?) ?? [];
      final winds = (hourList['wind_speed_10m'] as List?) ?? [];
      final codes = (hourList['weather_code'] as List?) ?? [];
      final nowUtc = DateTime.now().toUtc();
      _hours = [
        for (var i = 0; i < times.length; i++)
          WeatherHour(
            time: _parseLocal(times[i] as String),
            tempC: _num(temps.length > i ? temps[i] : null) ?? 0,
            precipMm: _num(prec.length > i ? prec[i] : null) ?? 0,
            precipProb:
                (_num(probs.length > i ? probs[i] : null) ?? 0).toInt(),
            windKmh: _num(winds.length > i ? winds[i] : null) ?? 0,
            code: (_num(codes.length > i ? codes[i] : null) ?? 0).toInt(),
          )
      ].where((h) =>
          h.time.isAfter(nowUtc) ||
          nowUtc.difference(h.time).inMinutes < 60).take(24).toList();
      final daily = body['daily'] as Map<String, dynamic>? ?? {};
      final dTimes = (daily['time'] as List?) ?? [];
      final dMax = (daily['temperature_2m_max'] as List?) ?? [];
      final dMin = (daily['temperature_2m_min'] as List?) ?? [];
      final dSum = (daily['precipitation_sum'] as List?) ?? [];
      final dCode = (daily['weather_code'] as List?) ?? [];
      _days = [
        for (var i = 0; i < dTimes.length; i++)
          WeatherDay(
            date: DateTime.parse(dTimes[i] as String),
            tempMin: _num(dMin.length > i ? dMin[i] : null) ?? 0,
            tempMax: _num(dMax.length > i ? dMax[i] : null) ?? 0,
            precipSum: _num(dSum.length > i ? dSum[i] : null) ?? 0,
            code: (_num(dCode.length > i ? dCode[i] : null) ?? 0).toInt(),
          )
      ];
      _days = _days.sublist(0, _days.length);
      _updatedAt = DateTime.now();
    } catch (e) {
      _error = 'Sem conexão com o serviço de clima.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// A API devolve os horarios no fuso local (sem 'Z'): nao podemos tratar
  /// como UTC, senao as horas ficam erradas em 3 horas.
  static DateTime _parseLocal(String iso) {
    final semZ = iso.endsWith('Z') ? iso.substring(0, iso.length - 1) : iso;
    return DateTime.parse(semZ);
  }
}
