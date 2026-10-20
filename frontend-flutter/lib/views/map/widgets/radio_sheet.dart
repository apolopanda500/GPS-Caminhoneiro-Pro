import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';

/// Bottom sheet do radio digital: busca, filtros, favoritos e reproducao.
class RadioSheet extends StatefulWidget {
  const RadioSheet({super.key});

  static Future<void> open(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: sheetBackground(context),
      isScrollControlled: true,
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
      Future<void>.microtask(() => audio.carregarPopulares());
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
    final termo = _busca.trim().toLowerCase();
    final estacoes = termo.isEmpty
        ? audio.estacoes
        : audio.estacoes
            .where((e) =>
                e.nome.toLowerCase().contains(termo) ||
                e.listaTags.any((t) => t.contains(termo)))
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => SafeArea(
        child: Column(
          children: [
            _cabecalho(context, audio),
            _barraBusca(context, audio),
            _filtros(context, audio),
            Expanded(child: _lista(context, audio, estacoes)),
            _player(context, audio),
          ],
        ),
      ),
    );
  }

  Widget _cabecalho(BuildContext context, AudioProvider audio) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kEmergencyRed.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.radio, color: kEmergencyRed),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Radio do caminhoneiro',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  audio.radioTocando
                      ? 'Tocando: ${audio.radioEstacao}'
                      : 'Estacoes reais do Brasil',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Fechar',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _barraBusca(BuildContext context, AudioProvider audio) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _buscaController,
        style: const TextStyle(color: Colors.white),
        textInputAction: TextInputAction.search,
        onSubmitted: (v) {
          context.read<AudioProvider>().buscarEstacoes(v.trim());
          setState(() => _busca = v);
        },
        decoration: InputDecoration(
          hintText: 'Buscar estacao (ex.: nova, fm, rock)',
          hintStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: kDarkBlack,
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon: IconButton(
            tooltip: 'Buscar na API',
            icon: audio.carregandoEstacoes
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, color: Colors.white70),
            onPressed: audio.carregandoEstacoes
                ? null
                : () {
                    context
                        .read<AudioProvider>()
                        .buscarEstacoes(_buscaController.text.trim());
                    setState(() => _busca = _buscaController.text);
                  },
          ),
        ),
        onChanged: (v) => setState(() => _busca = v),
      ),
    );
  }

  Widget _filtros(BuildContext context, AudioProvider audio) {
    if (audio.tags.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final tag in audio.tags)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(
                context,
                rotulo: tag,
                selecionado: audio.tagSelecionada == tag,
                onTap: () => context.read<AudioProvider>().setTag(tag),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String rotulo,
    required bool selecionado,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado
              ? kEmergencyRed.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selecionado ? kEmergencyRed : Colors.white24,
          ),
        ),
        child: Text(
          rotulo,
          style: TextStyle(
            color: selecionado ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _detalhes(EstacaoRadio e) {
    final partes = <String>[];
    if (e.state.isNotEmpty) partes.add(e.state);
    if (e.codec.isNotEmpty) partes.add(e.codec);
    if (e.bitrate > 0) partes.add('${e.bitrate} kbps');
    if (e.listaTags.isNotEmpty) partes.add(e.listaTags.take(2).join(', '));
    return partes.isEmpty ? 'Radio online' : partes.join(' - ');
  }

  Widget _lista(
    BuildContext context,
    AudioProvider audio,
    List<EstacaoRadio> estacoes,
  ) {
    if (audio.carregandoEstacoes && estacoes.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: kEmergencyRed),
      );
    }
    if (audio.erroRadio.isNotEmpty && estacoes.isEmpty) {
      return _vazio(
        icon: Icons.wifi_off,
        titulo: 'Sem conexao com o radio',
        subtitulo: audio.erroRadio,
        acao: FilledButton(
          onPressed: () => context.read<AudioProvider>().carregarPopulares(),
          child: const Text('Tentar de novo'),
        ),
      );
    }
    if (estacoes.isEmpty) {
      return _vazio(
        icon: Icons.radio_outlined,
        titulo: 'Nenhuma estacao encontrada',
        subtitulo: 'Tente outro termo de busca.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      itemCount: estacoes.length,
      itemBuilder: (_, i) {
        final e = estacoes[i];
        final ativo = audio.radioTocando && audio.radioEstacao == e.nome;
        return ListTile(
          dense: true,
          leading: Icon(
            ativo ? Icons.graphic_eq : Icons.play_circle_outline,
            color: ativo ? kEmergencyRed : Colors.white70,
          ),
          title: Text(
            e.nome,
            style: TextStyle(
              color: ativo ? kEmergencyRed : Colors.white,
              fontSize: 14,
              fontWeight: ativo ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _detalhes(e),
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: audio.ehFavorita(e) ? 'Remover favorito' : 'Favoritar',
            onPressed: () => context.read<AudioProvider>().alternarFavorita(e),
            icon: Icon(
              audio.ehFavorita(e) ? Icons.star : Icons.star_border,
              color: audio.ehFavorita(e) ? Colors.amber : Colors.white54,
            ),
          ),
          tileColor: ativo ? Colors.white10 : null,
          onTap: () => context.read<AudioProvider>().tocarEstacao(e),
        );
      },
    );
  }

  Widget _vazio({
    required IconData icon,
    required String titulo,
    String? subtitulo,
    Widget? acao,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white30, size: 42),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitulo,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
            if (acao != null) ...[const SizedBox(height: 16), acao],
          ],
        ),
      ),
    );
  }

  Widget _player(BuildContext context, AudioProvider audio) {
    if (!audio.radioTocando) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.graphic_eq, color: kEmergencyRed, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    audio.radioEstacao,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Pausar',
                  onPressed: () =>
                      context.read<AudioProvider>().alternarReproducao(),
                  icon: const Icon(Icons.pause_circle,
                      color: Colors.white70, size: 26),
                ),
                IconButton(
                  tooltip: 'Parar',
                  onPressed: () => context.read<AudioProvider>().pararRadio(),
                  icon: const Icon(Icons.stop_circle,
                      color: kEmergencyRed, size: 26),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.volume_down, color: Colors.white54, size: 18),
                Expanded(
                  child: Slider(
                    value: audio.volume,
                    onChanged: (v) =>
                        context.read<AudioProvider>().setVolume(v),
                    activeColor: kEmergencyRed,
                    inactiveColor: Colors.white24,
                  ),
                ),
                const Icon(Icons.volume_up, color: Colors.white54, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
