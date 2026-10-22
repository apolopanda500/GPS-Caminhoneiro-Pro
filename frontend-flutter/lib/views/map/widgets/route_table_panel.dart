import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/utils/confirm.dart';
import 'package:gps_camioneiro_pro/core/network/directions_service.dart';
import 'package:gps_camioneiro_pro/providers/route_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';

/// Cores disponiveis para a linha da rota (mesma lista do painel do mapa).
const List<String> kCoresLinhaRota = [
  '#FF6D00',
  '#E53935',
  '#1D4ED8',
  '#15803D',
  '#7C3AED',
  '#FACC15',
];

/// Painel "Tabela de rotas": lista as paradas com status, permite arrastar,
/// redimensionar e minimizar sem cobrir o mapa.
class RouteTablePanel extends StatefulWidget {
  final VoidCallback onShowRoute;
  final VoidCallback onShare;
  final VoidCallback onStart;
  final VoidCallback onConfirmNext;
  final VoidCallback onClose;

  /// Limpa a rota do mapa (some com a linha e as paradas).
  final VoidCallback? onLimparRota;

  /// Abre a busca de enderecos para adicionar uma parada na rota.
  final VoidCallback? onAddStop;

  /// Recalcula a rota depois de uma edicao (paradas novas/removidas).
  final VoidCallback? onRecalcular;

  /// Ajudante apenas acompanha: nao monta nem inicia rota.
  final bool canManageRoute;

  /// Secao das rotas compartilhadas do grupo (linha + paradas ao vivo).
  final Widget? sharedRoutesChild;

  const RouteTablePanel({
    super.key,
    required this.onShowRoute,
    required this.onShare,
    required this.onStart,
    required this.onConfirmNext,
    required this.onClose,
    this.onLimparRota,
    this.onAddStop,
    this.onRecalcular,
    this.canManageRoute = true,
    this.sharedRoutesChild,
  });

  @override
  State<RouteTablePanel> createState() => _RouteTablePanelState();
}

class _RouteTablePanelState extends State<RouteTablePanel> {
  double _width = 320;
  double _height = 220;
  bool _minimized = false;

  /// Modo edicao: permite mover, remover e adicionar paradas mesmo com a
  /// rota ja montada ou em andamento.
  bool _editando = false;

  /// Preferencias de aparencia (transparencia e cor). Pode faltar em testes.
  SettingsProvider? _ajustes(BuildContext context) {
    try {
      return context.watch<SettingsProvider>();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RouteProvider>();
    final settings = _ajustes(context);
    final route = provider.result;
    final stops = provider.stops;

    return SizedBox(
      width: _width,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxHeight: _height),
          decoration: BoxDecoration(
            color: overlaySurface(context,
                opacity: settings?.overlayOpacity ?? 1.0,
                accent: settings?.overlayColor),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: overlayBorder(context, accent: settings?.overlayColor),
                width: 1.4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _cabecalho(provider, route),
              if (!_minimized) ...[
                Flexible(child: _tabela(provider, stops)),
                if (_editando) _barraEdicao(provider),
                if (widget.sharedRoutesChild != null) widget.sharedRoutesChild!,
                _rodape(provider),
                _alcaResize(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cabecalho(RouteProvider provider, dynamic route) {
    final total = provider.totalStops;
    final entregues = provider.deliveredCount;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: const BoxDecoration(
        color: Color(0x33000000),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          const Icon(Icons.table_rows, color: Colors.redAccent, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tabela de rotas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: overlayText(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  total == 0
                      ? 'Sem paradas'
                      : '$entregues de $total concluídas${route != null ? ' • ${route.distanceKm.toStringAsFixed(1)} km' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: overlayTextMuted(context), fontSize: 11),
                ),
                if (route != null) _chegada(context, route),
              ],
            ),
          ),
          _botaoCabecalho(
              Icons.center_focus_strong, 'Mostrar rota', widget.onShowRoute),
          _botaoCorRota(),
          _botaoCabecalho(
              Icons.share_location, 'Compartilhar rota', widget.onShare),
          _botaoCabecalho(Icons.edit, 'Editar rota', () {
            setState(() => _editando = !_editando);
          }, ativo: widget.canManageRoute),
          _botaoCabecalho(
            _minimized ? Icons.expand_less : Icons.expand_more,
            _minimized ? 'Expandir' : 'Minimizar',
            () => setState(() => _minimized = !_minimized),
          ),
          _botaoCabecalho(Icons.close, 'Fechar', widget.onClose),
        ],
      ),
    );
  }

  /// Botao da cor da linha da rota: um toque Troca para a proxima cor
  /// (e um toque longo abre a lista de cores).
  Widget _botaoCorRota() {
    final settings = _ajustes(context);
    final cor = settings?.corRota ?? '#FF6D00';
    const lista = kCoresLinhaRota;
    final indice = lista.indexWhere(
      (c) => c.toUpperCase() == cor.toUpperCase(),
    );
    return Tooltip(
      message: 'Cor da linha da rota (toque para trocar)',
      child: GestureDetector(
        onTap: () {
          if (settings == null) return;
          final proximo = (indice + 1) % lista.length;
          settings.setCorRota(lista[indice < 0 ? 0 : proximo]);
        },
        onLongPress: () => _escolherCorRota(context, settings),
        child: Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color:
                Color(int.parse('FF${cor.replaceFirst('#', '')}', radix: 16)),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 1),
          ),
        ),
      ),
    );
  }

  /// Lista de cores para a linha da rota.
  void _escolherCorRota(BuildContext context, SettingsProvider? settings) {
    if (settings == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: overlaySurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cor da linha da rota',
                style: TextStyle(
                  color: overlayText(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kCoresLinhaRota.map((c) {
                  final sel = settings.corRota.toUpperCase() == c.toUpperCase();
                  return GestureDetector(
                    onTap: () {
                      settings.setCorRota(c);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse('FF${c.replaceFirst('#', '')}', radix: 16),
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel ? Colors.white : Colors.white24,
                          width: sel ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Botao compacto do cabecalho (deixa espaco para o titulo da tabela).
  Widget _botaoCabecalho(
    IconData icone,
    String dica,
    VoidCallback? onPressed, {
    bool ativo = true,
  }) {
    return IconButton(
      tooltip: dica,
      iconSize: 16,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: ativo ? onPressed : null,
      icon: Icon(
        icone,
        color: ativo
            ? overlayTextMuted(context)
            : overlayTextMuted(context).withValues(alpha: 0.3),
      ),
    );
  }

  /// Hora estimada de chegada no destino (recalculada a cada atualizacao).
  Widget _chegada(BuildContext context, RouteResult rota) {
    final chegada = DateTime.now().add(rota.duration);
    final hora =
        '${chegada.hour.toString().padLeft(2, '0')}:${chegada.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 12, color: overlayAccent(context)),
          const SizedBox(width: 4),
          Text(
            'Chegada $hora (${rota.etaText})',
            style: TextStyle(
              color: overlayAccent(context),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabela(RouteProvider provider, List<RouteStopEntry> stops) {
    if (stops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          'Monte a rota no botão "Rota" para ver a tabela de clientes aqui.',
          textAlign: TextAlign.center,
          style: TextStyle(color: overlayTextMuted(context), fontSize: 12),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Text('#',
                    style: TextStyle(
                        color: overlayTextMuted(context), fontSize: 10)),
              ),
              Expanded(
                child: Text('CLIENTE',
                    style: TextStyle(
                        color: overlayTextMuted(context), fontSize: 10)),
              ),
              SizedBox(
                width: 74,
                child: Text('STATUS',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: overlayTextMuted(context), fontSize: 10)),
              ),
            ],
          ),
        ),
        Divider(
            color: overlayTextMuted(context).withValues(alpha: 0.18),
            height: 1),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            itemCount: stops.length,
            itemBuilder: (context, index) {
              final stop = stops[index];
              final status = provider.statusOf(index);
              final isProximo = provider.nextStopIndex == index;
              final cor = provider.isCompanyStop(index)
                  ? const Color(0xFF9C27B0)
                  : status == StopStatus.delivered
                      ? const Color(0xFF4CAF50)
                      : status == StopStatus.arrived
                          ? const Color(0xFF2196F3)
                          : const Color(0xFFFF9800);
              final rotulo = status == StopStatus.delivered
                  ? 'ENTREGUE'
                  : status == StopStatus.arrived
                      ? 'NO LOCAL'
                      : isProximo
                          ? 'PRÓXIMA'
                          : 'PENDENTE';
              return InkWell(
                onTap: () => _confirmarEntrega(index),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isProximo
                        ? overlayTextMuted(context).withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: cor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stop.customer.isNotEmpty
                                  ? stop.customer
                                  : stop.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: overlayText(context), fontSize: 12),
                            ),
                            if (stop.neighborhood.isNotEmpty)
                              Text(
                                stop.neighborhood,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: overlayTextMuted(context),
                                    fontSize: 10),
                              ),
                          ],
                        ),
                      ),
                      if (_editando)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _botaoEditar(
                              icone: Icons.keyboard_arrow_up,
                              dica: 'Subir',
                              ativo: index > 0,
                              onPressed: () => _moverParada(index, index - 1),
                            ),
                            _botaoEditar(
                              icone: Icons.keyboard_arrow_down,
                              dica: 'Descer',
                              ativo: index < stops.length - 1,
                              onPressed: () => _moverParada(index, index + 1),
                            ),
                            _botaoEditar(
                              icone: Icons.delete_outline,
                              dica: 'Remover',
                              ativo: true,
                              cor: const Color(0xFFE53935),
                              onPressed: () => _removerParada(index),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: 74,
                          child: Text(
                            rotulo,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: cor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Botao pequeno do modo edicao.
  Widget _botaoEditar({
    required IconData icone,
    required String dica,
    required bool ativo,
    required VoidCallback onPressed,
    Color? cor,
  }) {
    final c = cor ?? overlayAccent(context);
    return IconButton(
      tooltip: dica,
      iconSize: 15,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      onPressed: ativo ? onPressed : null,
      icon: Icon(
        icone,
        color: ativo ? c : overlayTextMuted(context).withValues(alpha: 0.3),
      ),
    );
  }

  /// Barra do modo edicao: adicionar parada e recalcular a rota.
  Widget _barraEdicao(RouteProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onAddStop,
              icon: const Icon(Icons.add_location_alt, size: 15),
              label: const Text('PARADA'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                textStyle: const TextStyle(fontSize: 10),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onRecalcular,
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('RECALCULAR'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                textStyle: const TextStyle(fontSize: 10),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Move a parada para outra posicao da rota.
  void _moverParada(int de, int para) {
    final provider = context.read<RouteProvider>();
    if (de < 0 || de >= provider.stops.length) return;
    if (para < 0 || para >= provider.stops.length) return;
    provider.move(de, para);
    widget.onRecalcular?.call();
  }

  /// Remove a parada (com confirmacao).
  Future<void> _removerParada(int index) async {
    final provider = context.read<RouteProvider>();
    if (index < 0 || index >= provider.stops.length) return;
    final stop = provider.stops[index];
    final nome = stop.customer.isNotEmpty ? stop.customer : stop.label;
    final resposta = await confirmarAcao(
      context,
      titulo: 'Remover parada',
      mensagem: 'Remover "$nome" da rota?',
      textoConfirmar: 'REMOVER',
      destrutivo: true,
      icone: Icons.delete_outline,
    );
    if (resposta != Confirmacao.confirmado) return;
    provider.removeStopAt(index);
    widget.onRecalcular?.call();
  }

  /// Confirmacao real antes de marcar a entrega.
  Future<void> _confirmarEntrega(int index) async {
    final provider = context.read<RouteProvider>();
    final stops = provider.stops;
    if (index < 0 || index >= stops.length) return;
    final stop = stops[index];
    final cliente = stop.customer.isNotEmpty
        ? stop.customer
        : (stop.label.isNotEmpty ? stop.label : 'parada ${index + 1}');
    final resposta = await confirmarAcao(
      context,
      titulo: 'Confirmar entrega',
      mensagem:
          'Confirmar a entrega em "$cliente"?\n\nA parada fica marcada como entregue e nao podera ser desfeita aqui.',
      textoConfirmar: 'CONFIRMAR ENTREGA',
      icone: Icons.check_circle_outline,
    );
    if (resposta == Confirmacao.confirmado) {
      provider.confirmDelivery(index);
    }
  }

  Widget _rodape(RouteProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: provider.progress,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Limpar rota do mapa',
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: widget.onLimparRota,
            icon: Icon(Icons.delete_sweep, color: overlayTextMuted(context)),
          ),
          if (!widget.canManageRoute)
            Text(
              'Apenas o motorista pode iniciar a rota.',
              style: TextStyle(
                color: overlayTextMuted(context),
                fontSize: 11,
              ),
            )
          else if (!provider.started)
            ElevatedButton(
              onPressed: widget.onStart,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 32),
              ),
              child: const Text('INICIAR ROTA', style: TextStyle(fontSize: 11)),
            )
          else
            TextButton.icon(
              onPressed: widget.onConfirmNext,
              icon: const Icon(Icons.check_circle_outline,
                  size: 16, color: Colors.greenAccent),
              label: const Text('Confirmar',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  /// Ajusta o tamanho do painel (usado pelo gesto de redimensionar).
  void resize(double deltaWidth, double deltaHeight) {
    setState(() {
      _width = (_width + deltaWidth).clamp(240.0, 420.0);
      _height = (_height + deltaHeight).clamp(150.0, 420.0);
    });
  }

  Widget _alcaResize() {
    return GestureDetector(
      onHorizontalDragUpdate: (d) => resize(d.delta.dx, 0),
      onVerticalDragUpdate: (d) => resize(0, d.delta.dy),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 4),
          child: Icon(Icons.drag_handle,
              size: 16, color: kEmergencyRed.withValues(alpha: 0.8)),
        ),
      ),
    );
  }
}
