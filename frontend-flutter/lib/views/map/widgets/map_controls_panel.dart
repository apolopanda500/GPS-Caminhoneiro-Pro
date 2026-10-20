import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/providers/map_layers_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';

/// Painel unico do mapa: camada (satelite/ruas/3D), predios 3D, chuva,
/// nuvens, relevo, qualidade grafica (leve/medio/pesado) e medidor de FPS.
///
/// Tudo em um so lugar, aberto por um unico botao.
class MapControlsPanel extends StatelessWidget {
  final ValueChanged<MapLayerMode> onCamada;
  final ValueChanged<bool> onMostrarUi;
  final bool uiVisivel;

  const MapControlsPanel({
    super.key,
    required this.onCamada,
    required this.onMostrarUi,
    required this.uiVisivel,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final camadas = context.watch<MapLayersProvider>();
    final texto = overlayText(context);
    final muted = overlayTextMuted(context);

    Widget linha(IconData icone, String titulo, String subtitulo, bool ativo,
        ValueChanged<bool> onChanged) {
      return InkWell(
        onTap: () => onChanged(!ativo),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Icon(icone,
                  size: 19,
                  color: ativo ? overlayAccent(context) : muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: TextStyle(
                            color: texto, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(subtitulo,
                        style: TextStyle(color: muted, fontSize: 10)),
                  ],
                ),
              ),
              Switch(
                value: ativo,
                onChanged: onChanged,
                activeThumbColor: overlayAccent(context),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 300,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: overlaySurface(context, opacity: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: overlayBorder(context), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
            child: Row(
              children: [
                Icon(Icons.tune, size: 18, color: overlayAccent(context)),
                const SizedBox(width: 8),
                Text('Mapa e gráficos',
                    style: TextStyle(
                        color: texto,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Camada do mapa (unico controle de camada)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Text('Camada do mapa',
                style: TextStyle(
                    color: muted, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: SegmentedButton<MapLayerMode>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
              ),
              segments: const [
                ButtonSegment(
                  value: MapLayerMode.satellite,
                  label: Text('Satélite'),
                  icon: Icon(Icons.satellite_alt_outlined, size: 14),
                ),
                ButtonSegment(
                  value: MapLayerMode.streets,
                  label: Text('Ruas'),
                  icon: Icon(Icons.map_outlined, size: 14),
                ),
                ButtonSegment(
                  value: MapLayerMode.detailed,
                  label: Text('3D'),
                  icon: Icon(Icons.view_in_ar, size: 14),
                ),
              ],
              selected: {settings.layer},
              onSelectionChanged: (v) => onCamada(v.first),
            ),
          ),

          // Predios 3D
          linha(
            Icons.apartment,
            'Prédios 3D',
            'Volume e sombra dos prédios',
            settings.buildings3d,
            settings.setBuildings3d,
          ),

          // Camadas de clima
          linha(
            Icons.grain,
            'Radar de chuva',
            'Tempo real, atualiza a cada 10 min',
            camadas.radar,
            camadas.setRadar,
          ),
          linha(
            Icons.cloud_outlined,
            'Nuvens',
            'Tops das nuvens por satélite',
            camadas.nuvens,
            camadas.setNuvens,
          ),
          linha(
            Icons.terrain,
            'Relevo',
            'Sombreamento do terreno real',
            camadas.relevo,
            camadas.setRelevo,
          ),

          const Divider(color: Colors.white12, height: 12),

          // Qualidade grafica: leve / medio / pesado
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
            child: Text('Qualidade dos gráficos',
                style: TextStyle(
                    color: muted, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: SegmentedButton<RenderQuality>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
              ),
              segments: const [
                ButtonSegment(
                  value: RenderQuality.economy,
                  label: Text('Leve'),
                  icon: Icon(Icons.battery_saver, size: 14),
                ),
                ButtonSegment(
                  value: RenderQuality.balanced,
                  label: Text('Médio'),
                  icon: Icon(Icons.balance, size: 14),
                ),
                ButtonSegment(
                  value: RenderQuality.ultra,
                  label: Text('Pesado'),
                  icon: Icon(Icons.speed, size: 14),
                ),
              ],
              selected: {settings.renderQuality},
              onSelectionChanged: (v) => settings.setRenderQuality(v.first),
            ),
          ),

          // FPS
          linha(
            Icons.speed,
            'Mostrar FPS',
            'Medidor de desempenho na tela',
            settings.showFps,
            settings.setShowFps,
          ),

          // Mostrar/ocultar os elementos da tela (antes era um botao solto)
          linha(
            Icons.visibility,
            'Mostrar elementos da tela',
            'Barras, paineis e alertas visiveis',
            uiVisivel,
            onMostrarUi,
          ),

          const Divider(color: Colors.white12, height: 12),

          // Cor da linha da rota
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text('Cor da linha da rota',
                style: TextStyle(
                    color: muted, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _coresRota.map((c) {
                final sel = settings.corRota.toUpperCase() == c;
                return GestureDetector(
                  onTap: () => settings.setCorRota(c),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(int.parse('FF${c.replaceFirst('#', '')}', radix: 16)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel ? Colors.white : Colors.white24,
                        width: 3,
                      ),
                    ),
                    child: sel
                        ? const Icon(Icons.check, size: 15, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

const List<String> _coresRota = [
  '#FF6D00',
  '#E53935',
  '#1D4ED8',
  '#15803D',
  '#7E22CE',
  '#FACC15',
];
