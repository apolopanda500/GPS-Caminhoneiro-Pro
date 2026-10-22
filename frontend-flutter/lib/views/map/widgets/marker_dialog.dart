import 'package:flutter/material.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';

class MarkerDraft {
  final String emoji;
  final String type;
  final String? label;

  MarkerDraft({required this.emoji, required this.type, this.label});
}

/// Diálogo para o motorista sinalizar um ponto no mapa com emoji + tipo.
class MarkerDialog extends StatefulWidget {
  const MarkerDialog({super.key});

  static Future<MarkerDraft?> show(BuildContext context) {
    return showDialog<MarkerDraft>(
      context: context,
      builder: (_) => const MarkerDialog(),
    );
  }

  @override
  State<MarkerDialog> createState() => _MarkerDialogState();
}

class _MarkerDialogState extends State<MarkerDialog> {
  static const List<String> _emojis = [
    '👋',
    '👍',
    '☕',
    '⚠️',
    '🚧',
    '🚓',
    '📡',
    '⛽',
    '🛑',
    '🅿️',
    '🐄',
    '💧',
    '🌧️',
    '🔥',
    '🚚',
    '🍔',
    '🛠️',
    '⛔',
    '🚦',
    '🚸',
    '🛣️',
    '🔀',
    '🏗️',
    '🌫️',
    '❄️',
    '🌊',
    '🪵',
    '🧱',
    '⛽',
    '🍽️',
    '🏨',
    '🛞',
    '🧯',
    '🚜',
    '🪣',
    '🌾',
    '📍',
  ];
  static const Map<String, String> _types = {
    'sinal': 'Sinal',
    'radar': 'Radar',
    'policia': 'Polícia',
    'perigo': 'Perigo',
    'ponto_apoio': 'Ponto de apoio',
    'pedagio': 'Pedágio',
    'obra': 'Obra',
    'ponte_baixa': 'Ponte baixa',
    'balanca': 'Balança',
    'zmrc': 'Zona restrita',
    'descanso': 'Descanso',
    'estacionamento': 'Estacionamento',
    'combustivel': 'Combustível',
    'restaurante': 'Restaurante',
    'borracharia': 'Borracharia',
    'serra': 'Serra / descida',
    'curva': 'Curva perigosa',
    'fiscalizacao': 'Fiscalização',
  };

  String _emoji = '👋';
  String _type = 'sinal';
  final _labelController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kDarkBlack,
      title: const Text('Sinalizar ponto no mapa',
          style: TextStyle(color: Colors.white, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Emoji',
                style: TextStyle(color: kLightText, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojis.map((e) {
                final selected = e == _emoji;
                return GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: selected ? kEmergencyRed : Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Tipo',
                style: TextStyle(color: kLightText, fontSize: 12)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _type,
              dropdownColor: kDarkRedTransition,
              style: const TextStyle(color: Colors.white),
              items: _types.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? 'sinal'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _labelController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                labelStyle: TextStyle(color: kLightText),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: kLightText)),
        ),
        ElevatedButton(
          onPressed: () {
            final label = _labelController.text.trim();
            Navigator.pop(
              context,
              MarkerDraft(
                  emoji: _emoji,
                  type: _type,
                  label: label.isEmpty ? null : label),
            );
          },
          child: const Text('SINALIZAR'),
        ),
      ],
    );
  }
}
