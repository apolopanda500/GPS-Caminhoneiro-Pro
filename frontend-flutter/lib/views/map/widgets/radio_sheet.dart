import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/radio_player.dart';

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
            tooltip: 'Salvar uma estacao (nome + link do stream)',
            onPressed: () => _abrirEstacao(context),
            icon: const Icon(Icons.playlist_add, color: Colors.white70),
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
          trailing: _acoesEstacao(context, audio, e),
          tileColor: ativo ? Colors.white10 : null,
          onTap: () => context.read<AudioProvider>().tocarEstacao(e),
        );
      },
    );
  }

  /// Botoes de comando de cada estacao (favoritar, tocar, editar, excluir).
  Widget _acoesEstacao(
      BuildContext context, AudioProvider audio, EstacaoRadio e) {
    final propria = audio.minhasEstacoes.any((m) => m.url == e.url);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: audio.ehFavorita(e) ? 'Remover favorito' : 'Favoritar',
          onPressed: () => context.read<AudioProvider>().alternarFavorita(e),
          icon: Icon(
            audio.ehFavorita(e) ? Icons.star : Icons.star_border,
            color: audio.ehFavorita(e) ? Colors.amber : Colors.white54,
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Mais comandos',
          icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
          onSelected: (valor) {
            final provider = context.read<AudioProvider>();
            switch (valor) {
              case 'tocar':
                provider.tocarEstacao(e);
                break;
              case 'favorita':
                provider.alternarFavorita(e);
                break;
              case 'editar':
                _abrirEstacao(context, estacao: e);
                break;
              case 'excluir':
                provider.removerEstacao(e);
                break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'tocar', child: Text('Tocar agora')),
            PopupMenuItem(
              value: 'favorita',
              child: Text(audio.ehFavorita(e)
                  ? 'Remover dos favoritos'
                  : 'Salvar nos favoritos'),
            ),
            if (propria)
              const PopupMenuItem(
                  value: 'editar', child: Text('Editar estacao')),
            if (propria)
              const PopupMenuItem(
                  value: 'excluir', child: Text('Excluir estacao')),
          ],
        ),
      ],
    );
  }

  /// Cadastro/edicao de uma estacao digitada pelo motorista.
  Future<void> _abrirEstacao(BuildContext ctx,
      {EstacaoRadio? estacao}) async {
    final nome = TextEditingController(text: estacao?.nome ?? '');
    final url = TextEditingController(text: estacao?.url ?? '');
    final editando = estacao != null;
    final resultado = await showDialog<bool>(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: Text(editando ? 'Editar estacao' : 'Salvar estacao'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nome,
              decoration: const InputDecoration(labelText: 'Nome da estacao'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Link do stream (http/https)',
                hintText: 'https://.../stream',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(editando ? 'SALVAR' : 'ADICIONAR'),
          ),
        ],
      ),
    );
    if (resultado != true || !ctx.mounted) {
      nome.dispose();
      url.dispose();
      return;
    }
    final audio = ctx.read<AudioProvider>();
    final ok = editando
        ? await audio.editarEstacao(estacao, nome: nome.text, url: url.text)
        : await audio.adicionarEstacao(nome: nome.text, url: url.text);
    nome.dispose();
    url.dispose();
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(ok
          ? (editando ? 'Estacao atualizada.' : 'Estacao salva na sua lista.')
          : 'Informe um nome e um link http/https valido (ou a estacao ja existe).'),
    ));
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
                  tooltip: 'Parar',
                  onPressed: () => context.read<AudioProvider>().pararRadio(),
                  icon: const Icon(Icons.stop_circle,
                      color: kEmergencyRed, size: 26),
                ),
                IconButton(
                  tooltip: 'Abrir o tocador',
                  onPressed: () => RadioPlayer.show(context),
                  icon: const Icon(Icons.open_in_full,
                      color: Colors.white70, size: 22),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: 'Estacao anterior',
                  onPressed: () =>
                      context.read<AudioProvider>().anteriorEstacao(),
                  icon: const Icon(Icons.skip_previous,
                      color: Colors.white70, size: 28),
                ),
                IconButton(
                  tooltip: audio.radioPausado ? 'Continuar' : 'Pausar',
                  onPressed: () =>
                      context.read<AudioProvider>().alternarReproducao(),
                  icon: Icon(
                    audio.radioPausado
                        ? Icons.play_circle
                        : Icons.pause_circle,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                IconButton(
                  tooltip: 'Proxima estacao',
                  onPressed: () =>
                      context.read<AudioProvider>().proximaEstacao(),
                  icon: const Icon(Icons.skip_next,
                      color: Colors.white70, size: 28),
                ),
                IconButton(
                  tooltip: audio.mudo ? 'Tirar do mudo' : 'Mudo',
                  onPressed: () => context.read<AudioProvider>().alternarMudo(),
                  icon: Icon(
                    audio.mudo ? Icons.volume_off : Icons.volume_up,
                    color: audio.mudo ? kEmergencyRed : Colors.white70,
                    size: 24,
                  ),
                ),
                IconButton(
                  tooltip: 'Programar para dormir',
                  onPressed: () => _programarDormir(context, audio),
                  icon: Icon(
                    Icons.bedtime_outlined,
                    color:
                        audio.dormirAte != null ? kEmergencyRed : Colors.white70,
                    size: 24,
                  ),
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

  /// Escolhe em quantos minutos o radio desliga sozinho.
  Future<void> _programarDormir(
      BuildContext ctx, AudioProvider audio) async {
    final minutos = await showModalBottomSheet<int>(
      context: ctx,
      backgroundColor: sheetBackground(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Dormir com o radio ligado',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text('O radio para sozinho depois do tempo escolhido.',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            for (final opcao in const [15, 30, 60, 90])
              ListTile(
                leading: const Icon(Icons.bedtime_outlined,
                    color: Colors.white70),
                title: Text('$opcao minutos',
                    style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(sheetContext, opcao),
              ),
            ListTile(
              leading: const Icon(Icons.timer_off_outlined,
                  color: Colors.white70),
              title: const Text('Desligar o timer',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(sheetContext, 0),
            ),
          ],
        ),
      ),
    );
    if (minutos == null) return;
    if (!ctx.mounted) return;
    ctx.read<AudioProvider>().programarDormir(minutos);
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(minutos == 0
          ? 'Timer do radio desligado.'
          : 'O radio vai parar em $minutos minutos.'),
    ));
  }
}
