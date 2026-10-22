import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/utils/moon.dart';
import 'package:gps_camioneiro_pro/core/utils/solar.dart';
import 'package:gps_camioneiro_pro/providers/weather_provider.dart';

/// Painel de clima em tempo real: agora, proximas horas, proximos dias,
/// horario local e sol (nascer/por).
class WeatherPanel extends StatefulWidget {
  final double? latitude;
  final double? longitude;

  const WeatherPanel({super.key, this.latitude, this.longitude});

  @override
  State<WeatherPanel> createState() => _WeatherPanelState();
}

class _WeatherPanelState extends State<WeatherPanel> {
  Timer? _timer;
  bool _expandido = false;

  @override
  void initState() {
    super.initState();
    // Relogio e atualizacao do clima a cada 30 segundos.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
      _atualizar();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _atualizar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _atualizar() {
    final lat = widget.latitude;
    final lon = widget.longitude;
    if (lat == null || lon == null) return;
    try {
      context.read<WeatherProvider>().refresh(lat: lat, lon: lon);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final clima = context.watch<WeatherProvider>();
    final texto = overlayText(context);
    final muted = overlayTextMuted(context);
    final agora = DateTime.now();
    final infoSolar = (widget.latitude != null && widget.longitude != null)
        ? calcularSolar(
            latitude: widget.latitude!, longitude: widget.longitude!)
        : null;

    final now = clima.now;
    final dias = clima.days.take(5).toList();
    final horas = clima.hours.take(8).toList();

    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: overlaySurface(context, opacity: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: overlayBorder(context), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecalho: hora/data local + sol
          Row(
            children: [
              Icon(
                infoSolar == null
                    ? Icons.cloud_outlined
                    : (infoSolar.ehDia
                        ? Icons.wb_sunny
                        : Icons.nightlight_round),
                size: 18,
                color: overlayAccent(context),
              ),
              const SizedBox(width: 8),
              Text(
                _horaTexto(agora),
                style: TextStyle(
                  color: texto,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dataTexto(agora),
                  style: TextStyle(color: muted, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Atualizar clima',
                iconSize: 16,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                onPressed: _atualizar,
                icon: Icon(Icons.refresh, size: 15, color: muted),
              ),
            ],
          ),
          if (infoSolar != null && infoSolar.nascerDoSol != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sol: nascer ${_horaTexto(infoSolar.nascerDoSol!)} • '
                    'pôr ${_horaTexto(infoSolar.porDoSol!)} • '
                    '${infoSolar.ehDia ? 'dia' : 'noite'} '
                    '(elev. ${infoSolar.elevacaoGraus.toStringAsFixed(0)}°)',
                    style: TextStyle(color: muted, fontSize: 10),
                  ),
                  Text(
                    'Lua: ${_lua.emoji} ${_lua.fase} • '
                    '${_lua.iluminacao.toStringAsFixed(0)}% iluminada',
                    style: TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          const Divider(color: Colors.white12, height: 8),
          if (clima.loading && now == null)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (now == null)
            Text('Sem dados de clima ainda.',
                style: TextStyle(color: muted, fontSize: 12))
          else ...[
            // Agora
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _expandido = !_expandido),
                  child: Text(clima.emojiForCode(now.code),
                      style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 10),
                Text('${now.tempC.toStringAsFixed(0)}°C',
                    style: TextStyle(
                        color: texto,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vento ${now.windKmh.toStringAsFixed(0)} km/h',
                          style: TextStyle(color: texto, fontSize: 12)),
                      if (now.precipMm > 0)
                        Text('Chuva ${now.precipMm.toStringAsFixed(1)} mm',
                            style: TextStyle(color: muted, fontSize: 11)),
                      GestureDetector(
                        onTap: () => setState(() => _expandido = !_expandido),
                        child: Text(
                          _expandido
                              ? 'Ocultar previsao'
                              : 'Ver previsao (${dias.length} dias, ${horas.length}h)',
                          style: TextStyle(
                              color: overlayAccent(context), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Proximas horas
            if (_expandido && horas.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Próximas horas',
                  style: TextStyle(
                      color: muted, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SizedBox(
                height: 58,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: horas.length,
                  itemBuilder: (context, i) {
                    final h = horas[i];
                    return Container(
                      width: 52,
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_horaCurta(h.time),
                              style: TextStyle(color: muted, fontSize: 10)),
                          Text(clima.emojiForCode(h.code),
                              style: const TextStyle(fontSize: 14)),
                          Text('${h.tempC.toStringAsFixed(0)}°',
                              style: TextStyle(
                                  color: texto,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          Text(
                            '${h.precipProb}%',
                            style: TextStyle(
                                color: h.precipProb >= 40
                                    ? const Color(0xFF64B5F6)
                                    : muted,
                                fontSize: 9),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            // Proximos dias
            if (_expandido && dias.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Previsão dos próximos dias',
                  style: TextStyle(
                      color: muted, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...dias.map((d) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 52,
                          child: Text(
                            _diaSemana(d.date),
                            style: TextStyle(color: texto, fontSize: 11),
                          ),
                        ),
                        Text(clima.emojiForCode(d.code),
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${d.tempMin.toStringAsFixed(0)}° / ${d.tempMax.toStringAsFixed(0)}°'
                            '${d.precipSum > 0 ? ' • ${d.precipSum.toStringAsFixed(1)} mm' : ''}',
                            style: TextStyle(color: muted, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ],
      ),
    );
  }

  String _horaTexto(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  InfoLua get _lua => calcularLua();

  String _horaCurta(DateTime d) => '${d.hour.toString().padLeft(2, '0')}h';

  String _dataTexto(DateTime d) {
    const dias = [
      'seg',
      'ter',
      'qua',
      'qui',
      'sex',
      'sab',
      'dom',
    ];
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}'
        ' • ${dias[d.weekday - 1]}';
  }

  String _diaSemana(DateTime d) {
    const dias = [
      'seg',
      'ter',
      'qua',
      'qui',
      'sex',
      'sab',
      'dom',
    ];
    return dias[d.weekday - 1];
  }
}
