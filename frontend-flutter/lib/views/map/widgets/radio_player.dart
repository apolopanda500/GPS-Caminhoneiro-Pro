import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';

/// Tocador do radio (estilo app de musica: capa grande, play/pause grande,
/// fila de estacoes e volume).
///
/// O motorista abre do painel do radio e controla tudo sem sair da tela.
class RadioPlayer extends StatelessWidget {
  final List<EstacaoRadio> extras;

  const RadioPlayer({super.key, this.extras = const []});

  static Future<void> show(BuildContext context, {List<EstacaoRadio> extras = const []}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => RadioPlayer(extras: extras),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final tema = Theme.of(context);
    final estacao = audio.estacaoAtual;
    final fila = <EstacaoRadio>[
      if (estacao != null) estacao,
      ...audio.filaDoTocador.where((e) => e.nome != audio.radioEstacao),
      ...extras,
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kEmergencyRed.withValues(alpha: 0.55),
            const Color(0xFF120404),
            const Color(0xFF080808),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ---- capa grande (estilo tocador de musica)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                  ),
                  Expanded(
                    child: Text(
                      'TOCADOR DO RÁDIO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Favoritar',
                    onPressed: estacao == null
                        ? null
                        : () => context.read<AudioProvider>().alternarFavorita(estacao),
                    icon: Icon(
                      (estacao != null && audio.ehFavorita(estacao))
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: (estacao != null && audio.ehFavorita(estacao))
                          ? kEmergencyRed
                          : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 190,
              height: 190,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    kEmergencyRed.withValues(alpha: 0.9),
                    const Color(0xFF2A0505),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kEmergencyRed.withValues(alpha: 0.35),
                    blurRadius: 34,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      audio.radioAtivo ? Icons.graphic_eq : Icons.radio,
                      size: 66,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Text(
                        audio.radioEstacao.isEmpty ? 'Nada tocando' : audio.radioEstacao,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ---- controles (play/pause grande, anterior, proxima)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Anterior',
                  iconSize: 34,
                  color: Colors.white70,
                  onPressed: () => context.read<AudioProvider>().anteriorEstacao(),
                  icon: const Icon(Icons.skip_previous),
                ),
                const SizedBox(width: 18),
                GestureDetector(
                  onTap: () => context.read<AudioProvider>().alternarReproducao(),
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: kEmergencyRed,
                    ),
                    child: Icon(
                      audio.radioAtivo ? Icons.pause : Icons.play_arrow,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                IconButton(
                  tooltip: 'Próxima',
                  iconSize: 34,
                  color: Colors.white70,
                  onPressed: () => context.read<AudioProvider>().proximaEstacao(),
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
            // ---- volume
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
              child: Row(
                children: [
                  const Icon(Icons.volume_down, color: Colors.white54, size: 18),
                  Expanded(
                    child: Slider(
                      value: audio.volume,
                      onChanged: (v) => context.read<AudioProvider>().setVolume(v),
                      activeColor: kEmergencyRed,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                  const Icon(Icons.volume_up, color: Colors.white54, size: 18),
                ],
              ),
            ),
            // ---- fila
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
                itemCount: fila.length,
                itemBuilder: (context, i) {
                  final e = fila[i];
                  final tocando = e.nome == audio.radioEstacao;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: tocando
                          ? kEmergencyRed.withValues(alpha: 0.35)
                          : Colors.white12,
                      child: Icon(
                        tocando ? Icons.graphic_eq : Icons.radio,
                        size: 16,
                        color: tocando ? kEmergencyRed : Colors.white54,
                      ),
                    ),
                    title: Text(
                      e.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tocando ? kEmergencyRed : Colors.white,
                        fontSize: 13,
                        fontWeight: tocando ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      (e.tags == '' ? 'Rádio da estrada' : e.tags),
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    trailing: IconButton(
                      tooltip: 'Favoritar',
                      icon: Icon(
                        audio.ehFavorita(e) ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: audio.ehFavorita(e) ? kEmergencyRed : Colors.white38,
                      ),
                      onPressed: () =>
                          context.read<AudioProvider>().alternarFavorita(e),
                    ),
                    onTap: () => context.read<AudioProvider>().tocarEstacao(e),
                  );
                },
              ),
            ),
            if (audio.erroRadio.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  audio.erroRadio,
                  style: TextStyle(color: tema.colorScheme.error, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
