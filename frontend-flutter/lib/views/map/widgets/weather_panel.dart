import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/utils/moon.dart';
import 'package:gps_camioneiro_pro/core/utils/solar.dart';
import 'package:gps_camioneiro_pro/providers/map_layers_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/providers/weather_provider.dart';

/// Painel único do clima: condições agora, dicas de estrada, previsão de
/// horas/dias e todas as camadas de clima do mapa em um só lugar.
class WeatherPanel extends StatefulWidget {
  final double? latitude;
  final double? longitude;

  const WeatherPanel({super.key, this.latitude, this.longitude});

  @override
  State<WeatherPanel> createState() => _WeatherPanelState();
}

class _WeatherPanelState extends State<WeatherPanel> {
  Timer? _relogio;
  Timer? _atualizacao;

  double? get _lat => widget.latitude;

  double? get _lon => widget.longitude;

  @override
  void initState() {
    super.initState();
    _relogio = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _atualizar(force: true);
      _agendarAtualizacao();
    });
  }

  @override
  void dispose() {
    _relogio?.cancel();
    _atualizacao?.cancel();
    super.dispose();
  }

  void _agendarAtualizacao() {
    _atualizacao?.cancel();
    if (!mounted) return;
    final intervalo = context.read<SettingsProvider>().intervaloClima;
    _atualizacao = Timer.periodic(intervalo, (_) {
      if (mounted) _atualizar();
    });
  }

  Future<void> _atualizar({bool force = false}) async {
    final lat = _lat;
    final lon = _lon;
    if (lat == null || lon == null) return;
    try {
      await context.read<WeatherProvider>().refresh(
            lat: lat,
            lon: lon,
            force: force,
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final clima = context.watch<WeatherProvider>();
    final camadas = context.watch<MapLayersProvider>();
    final settings = context.watch<SettingsProvider>();
    final texto = overlayText(context);
    final muted = overlayTextMuted(context);
    final agora = DateTime.now();
    final infoSolar = (_lat != null && _lon != null)
        ? calcularSolar(latitude: _lat!, longitude: _lon!)
        : null;
    final now = clima.now;
    final horas = clima.hours.take(12).toList();
    final dias = clima.days.take(5).toList();
    final risco = clima.perigoParaVoz();
    final dicas = clima.dicasIA();

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: BoxDecoration(
          color: overlaySurface(context, opacity: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: overlayBorder(context), width: 1.2),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _cabecalho(context, clima, agora, texto, muted),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (now == null)
                        _semDados(context, clima, muted)
                      else ...[
                        _condicaoAtual(
                            context, clima, now, infoSolar, texto, muted),
                        if (infoSolar != null) ...[
                          const SizedBox(height: 10),
                          _solELua(context, infoSolar, texto, muted),
                        ],
                        if (risco != null) ...[
                          const SizedBox(height: 10),
                          _avisoRisco(context, risco),
                        ],
                        if (dicas.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _dicas(context, dicas, texto, muted),
                        ],
                        const SizedBox(height: 14),
                        _titulo('Próximas horas', muted),
                        const SizedBox(height: 6),
                        _listaHoras(context, clima, horas, texto, muted),
                        const SizedBox(height: 14),
                        _titulo('Próximos dias', muted),
                        const SizedBox(height: 4),
                        ...dias.map(
                            (d) => _linhaDia(context, clima, d, texto, muted)),
                      ],
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 12),
                      _titulo('Camadas no mapa', muted),
                      const SizedBox(height: 2),
                      Text(
                        'Ligue só o que precisa. Tudo fica neste painel.',
                        style: TextStyle(color: muted, fontSize: 10),
                      ),
                      const SizedBox(height: 8),
                      if (settings.batterySaver)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _notaEconomia(context, muted),
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _camadaChip(
                            context,
                            icone: Icons.grain,
                            rotulo: 'Clima completo',
                            ativo: camadas.climaCompleto,
                            onTap: () =>
                                camadas.setClimaCompleto(!camadas.climaCompleto),
                          ),
                          _camadaChip(
                            context,
                            icone: Icons.terrain,
                            rotulo: 'Relevo',
                            ativo: camadas.relevo,
                            onTap: () => camadas.setRelevo(!camadas.relevo),
                          ),
                        ],
                      ),
                      if (camadas.radar) ...[
                        const SizedBox(height: 10),
                        _controlesRadar(context, camadas, muted),
                      ],
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        secondary: Icon(Icons.brightness_4_outlined,
                            size: 18,
                            color: settings.realismo
                                ? overlayAccent(context)
                                : muted),
                        title: Text(
                          'Modo realista (sol e lua)',
                          style: TextStyle(color: texto, fontSize: 12),
                        ),
                        subtitle: Text(
                          settings.realismo
                              ? 'O mapa acompanha a luz real do dia e da noite'
                              : 'Escurece o mapa no fim da tarde e clareia com a lua',
                          style: TextStyle(color: muted, fontSize: 10),
                        ),
                        value: settings.realismo,
                        onChanged: settings.setRealismo,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(Icons.update, size: 13, color: muted),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              clima.updatedAt == null
                                  ? 'Aguardando atualização'
                                  : 'Atualizado às ${_hora(clima.updatedAt!)} • '
                                      'Open-Meteo + RainViewer',
                              style: TextStyle(color: muted, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cabecalho(BuildContext context, WeatherProvider clima, DateTime agora,
      Color texto, Color muted) {
    final atualizado = clima.updatedAt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: muted.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.cloud_sync_outlined,
                  size: 22, color: overlayAccent(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clima na estrada',
                      style: TextStyle(
                        color: texto,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      atualizado == null
                          ? 'Buscando condições...'
                          : 'Atualizado às ${_hora(atualizado)}',
                      style: TextStyle(color: muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Atualizar clima',
                onPressed: () => _atualizar(force: true),
                icon: clima.loading
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.refresh, size: 20, color: muted),
              ),
              IconButton(
                tooltip: 'Fechar clima',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(Icons.close, size: 21, color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _semDados(BuildContext context, WeatherProvider clima, Color muted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.cloud_off, size: 44, color: muted),
            const SizedBox(height: 10),
            Text(
              clima.error ?? 'Sem dados de clima ainda.',
              style: TextStyle(color: muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _atualizar(force: true),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('TENTAR DE NOVO'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _condicaoAtual(BuildContext context, WeatherProvider clima,
      WeatherNow now, InfoSolar? solar, Color texto, Color muted) {
    final chuva = clima.chuvaNivel();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: overlayBorder(context), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(clima.emojiForCode(now.code),
                  style: const TextStyle(fontSize: 46)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${now.tempC.toStringAsFixed(0)}°C',
                    style: TextStyle(
                      color: texto,
                      fontSize: 38,
                      height: 1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    clima.descricaoForCode(now.code),
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _medida(Icons.air, '${now.windKmh.toStringAsFixed(0)} km/h',
                      texto, muted),
                  const SizedBox(height: 5),
                  _medida(
                    Icons.water_drop,
                    now.precipMm > 0
                        ? '${now.precipMm.toStringAsFixed(1)} mm'
                        : 'Sem chuva',
                    chuva == null ? texto : const Color(0xFF64B5F6),
                    muted,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (solar != null && solar.nascerDoSol != null) ...[
                _medida(
                    Icons.wb_sunny_outlined,
                    '${_hora(solar.nascerDoSol!)} / ${_hora(solar.porDoSol!)}',
                    muted,
                    muted),
                const SizedBox(width: 14),
              ],
              _medida(
                  Icons.nightlight_round,
                  '${_lua.emoji} ${_lua.iluminacao.toStringAsFixed(0)}%',
                  muted,
                  muted),
              const Spacer(),
              Text(
                solar?.ehDia == false ? 'Noite' : 'Dia',
                style: TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _solELua(
      BuildContext context, InfoSolar solar, Color texto, Color muted) {
    final lua = calcularLua();
    final cardeal = _cardeal(solar.azimuteGraus);
    final noite = !solar.ehDia;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SOL AGORA',
                    style: TextStyle(
                        color: muted,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(noite ? '🌙' : '☀️',
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      '${solar.elevacaoGraus.toStringAsFixed(0)}° • $cardeal',
                      style: TextStyle(
                          color: texto,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  solar.ehDia ? 'Acima do horizonte' : 'Abaixo do horizonte',
                  style: TextStyle(color: muted, fontSize: 9),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 44, color: Colors.white12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LUA AGORA',
                    style: TextStyle(
                        color: muted,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(lua.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${lua.iluminacao.toStringAsFixed(0)}% iluminada',
                        style: TextStyle(
                            color: texto,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(lua.fase,
                    style: TextStyle(color: muted, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _cardeal(double azimute) {
    const nomes = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
    final i = (((azimute % 360) / 45).round()) % 8;
    return nomes[i];
  }

  Widget _medida(IconData icone, String valor, Color cor, Color muted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 14, color: muted),
        const SizedBox(width: 4),
        Text(valor, style: TextStyle(color: cor, fontSize: 11)),
      ],
    );
  }

  Widget _avisoRisco(BuildContext context, String risco) {
    const cor = Color(0xFFFFB300);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 19, color: cor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              risco,
              style: const TextStyle(
                  color: cor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dicas(
      BuildContext context, List<String> dicas, Color texto, Color muted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping,
                  size: 15, color: overlayAccent(context)),
              const SizedBox(width: 6),
              Text(
                'DICAS PARA A ESTRADA',
                style: TextStyle(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ...dicas.take(3).map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• $d',
                    style: TextStyle(color: texto, fontSize: 11, height: 1.35),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _titulo(String texto, Color muted) => Text(
        texto,
        style: TextStyle(
          color: muted,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      );

  Widget _listaHoras(BuildContext context, WeatherProvider clima,
      List<WeatherHour> horas, Color texto, Color muted) {
    if (horas.isEmpty) {
      return Text('Previsão por hora indisponível.',
          style: TextStyle(color: muted, fontSize: 11));
    }
    return SizedBox(
      height: 84,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: horas.length,
        itemBuilder: (context, i) {
          final h = horas[i];
          final chuva = h.precipProb >= 40;
          return Container(
            width: 58,
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: chuva
                    ? const Color(0xFF64B5F6).withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_horaCurta(h.time),
                    style: TextStyle(color: muted, fontSize: 10)),
                Text(clima.emojiForCode(h.code),
                    style: const TextStyle(fontSize: 17)),
                Text('${h.tempC.toStringAsFixed(0)}°',
                    style: TextStyle(
                        color: texto,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                Text(
                  '${h.precipProb}%',
                  style: TextStyle(
                    color: chuva ? const Color(0xFF64B5F6) : muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _linhaDia(BuildContext context, WeatherProvider clima, WeatherDay d,
      Color texto, Color muted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              _diaSemana(d.date),
              style: TextStyle(color: texto, fontSize: 12),
            ),
          ),
          Text(clima.emojiForCode(d.code),
              style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              d.precipSum > 0
                  ? '${d.precipSum.toStringAsFixed(1)} mm de chuva'
                  : 'Sem chuva prevista',
              style: TextStyle(color: muted, fontSize: 10),
            ),
          ),
          Text(
            '${d.tempMin.toStringAsFixed(0)}° / ${d.tempMax.toStringAsFixed(0)}°',
            style: TextStyle(
                color: texto, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _camadaChip(
    BuildContext context, {
    required IconData icone,
    required String rotulo,
    required bool ativo,
    required VoidCallback onTap,
  }) {
    final accent = overlayAccent(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: ativo
              ? accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ativo ? accent : overlayBorder(context),
            width: ativo ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone,
                size: 15, color: ativo ? accent : overlayTextMuted(context)),
            const SizedBox(width: 5),
            Text(
              rotulo,
              style: TextStyle(
                color: ativo ? accent : overlayTextMuted(context),
                fontSize: 11,
                fontWeight: ativo ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlesRadar(
      BuildContext context, MapLayersProvider camadas, Color muted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: camadas.animando ? 'Pausar radar' : 'Animar radar',
            iconSize: 20,
            onPressed:
                camadas.totalFrames > 1 ? camadas.alternarAnimacao : null,
            icon: Icon(
              camadas.animando ? Icons.pause : Icons.play_arrow,
              color: overlayAccent(context),
            ),
          ),
          IconButton(
            tooltip: 'Voltar ao início',
            iconSize: 20,
            onPressed: camadas.totalFrames > 1 ? camadas.recomecarRadar : null,
            icon: Icon(Icons.replay, color: overlayAccent(context)),
          ),
          Expanded(
            child: Text(
              camadas.totalFrames > 1
                  ? '${camadas.rotuloFrame} • ${camadas.totalFrames} frames'
                  : 'Carregando radar...',
              style: TextStyle(color: muted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notaEconomia(BuildContext context, Color muted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.battery_saver, size: 15, color: Color(0xFF66BB6A)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Economia de bateria: o clima completo fica desligado.',
              style: TextStyle(color: muted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _horaCurta(DateTime d) => '${d.hour.toString().padLeft(2, '0')}h';

  String _diaSemana(DateTime d) {
    const dias = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
    return dias[d.weekday - 1];
  }

  InfoLua get _lua => calcularLua();
}
