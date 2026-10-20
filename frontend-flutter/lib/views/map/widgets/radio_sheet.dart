import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';

/// Bottom sheet do rádio FM: busca estações, toca/para.
class RadioSheet extends StatefulWidget {
  const RadioSheet({super.key});

  static Future<void> open(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: kDarkRedTransition,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const RadioSheet(),
    );
  }

  @override
  State<RadioSheet> createState() => _RadioSheetState();
}

class _RadioSheetState extends State<RadioSheet> {
  final _buscaController = TextEditingController();
  String _busca = '';

  @override
  void initState() {
    super.initState();
    final audio = context.read<AudioProvider>();
    if (audio.estacoes.isEmpty) {
      Future<void>.microtask(() => audio.buscarEstacoes());
    }
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final estacoes = _busca.isEmpty
        ? audio.estacoes
        : audio.estacoes
            .where((e) =>
                e.nome.toLowerCase().contains(_busca.toLowerCase()))
            .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.radio, color: kEmergencyRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    audio.radioTocando
                        ? 'Tocando: ${audio.radioEstacao}'
                        : 'Rádio FM do caminhoneiro',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                if (audio.radioTocando)
                  IconButton(
                    onPressed: () => context.read<AudioProvider>().pararRadio(),
                    icon: const Icon(Icons.stop_circle,
                        color: kEmergencyRed, size: 28),
                  ),
              ],
            ),
            TextField(
              controller: _buscaController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar estação (ex.: nova, fm)',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: kDarkBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: audio.carregandoEstacoes
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search, color: Colors.white70),
                  onPressed: () {
                    context.read<AudioProvider>().buscarEstacoes(
                          _buscaController.text.trim(),
                        );
                    setState(() => _busca = '');
                  },
                ),
              ),
              onChanged: (v) => setState(() => _busca = v),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: estacoes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Nenhuma estação encontrada.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: estacoes.length,
                      itemBuilder: (_, i) {
                        final e = estacoes[i];
                        final ativo =
                            audio.radioTocando && audio.radioEstacao == e.nome;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            ativo ? Icons.play_circle : Icons.play_circle_outline,
                            color: ativo ? kEmergencyRed : Colors.white70,
                          ),
                          title: Text(e.nome,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                          tileColor: ativo ? Colors.white10 : null,
                          onTap: () =>
                              context.read<AudioProvider>().tocarEstacao(e),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
