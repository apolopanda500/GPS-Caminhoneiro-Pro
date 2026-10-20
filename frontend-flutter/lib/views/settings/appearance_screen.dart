import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/utils/overlay_style.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';

/// Tela de aparencia dos paineis flutuantes do mapa.
///
/// Fica fora do app_theme de proposito: cor de destaque e transparencia sao
/// preferencias do usuario, nao temas do aplicativo.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final texto = escuro ? Colors.white : const Color(0xFF1A1A1A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aparença do mapa'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Transparência dos painéis',
              style: TextStyle(
                  color: texto, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'Deixe os botões e cartões mais discretos para ver mais da estrada.',
            style: TextStyle(color: texto.withValues(alpha: 0.7), fontSize: 12),
          ),
          Slider(
            value: settings.overlayOpacity,
            min: 0.3,
            max: 1.0,
            divisions: 14,
            label: '${(settings.overlayOpacity * 100).round()}%',
            onChanged: (v) => settings.setOverlayOpacity(v),
          ),
          const SizedBox(height: 8),
          Text('Cor de destaque',
              style: TextStyle(
                  color: texto, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(kOverlayAccents.length, (i) {
              final cor = kOverlayAccents[i];
              final selecionado = settings.overlayAccentIndex == i;
              return GestureDetector(
                onTap: () => settings.setOverlayAccent(i),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: cor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selecionado
                          ? (escuro ? Colors.white : Colors.black87)
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: selecionado
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          _preview(context, settings, texto),
          const Divider(height: 40),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.radioFabEnabled,
            onChanged: (v) => settings.setRadioFabEnabled(v),
            title: Text('Botão flutuante do rádio',
                style: TextStyle(color: texto, fontSize: 15)),
            subtitle: Text(
              'Mostra um botão fixo no mapa para abrir o rádio da estrada.',
              style: TextStyle(color: texto.withValues(alpha: 0.7), fontSize: 12),
            ),
            secondary: const Icon(Icons.radio_outlined),
          ),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context, SettingsProvider settings, Color texto) {
    final superficie = OverlayStyle.surface(context, settings.overlayOpacity);
    final cor = settings.overlayColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OverlayStyle.border(context, cor), width: 1.4),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Assim ficam os painéis do mapa (Sinal, tabela de rotas, botões).',
              style: TextStyle(color: texto, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
