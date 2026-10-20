import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/utils/confirm.dart';
import 'package:gps_camioneiro_pro/providers/route_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';

/// Painel "Tabela de rotas": lista as paradas com status, permite arrastar,
/// redimensionar e minimizar sem cobrir o mapa.
class RouteTablePanel extends StatefulWidget {
  final VoidCallback onShowRoute;
  final VoidCallback onShare;
  final VoidCallback onStart;
  final VoidCallback onConfirmNext;
  final VoidCallback onClose;

  /// Ajudante apenas acompanha: nao monta nem inicia rota.
  final bool canManageRoute;

  const RouteTablePanel({
    super.key,
    required this.onShowRoute,
    required this.onShare,
    required this.onStart,
    required this.onConfirmNext,
    required this.onClose,
    this.canManageRoute = true,
  });

  @override
  State<RouteTablePanel> createState() => _RouteTablePanelState();
}

class _RouteTablePanelState extends State<RouteTablePanel> {
  double _width = 320;
  double _height = 220;
  bool _minimized = false;

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
                color: overlayBorder(context,
                    accent: settings?.overlayColor),
                width: 1.4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _cabecalho(provider, route),
              if (!_minimized) ...[
                Flexible(child: _tabela(provider, stops)),
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
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tabela de rotas',
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
                  style: TextStyle(
                      color: overlayTextMuted(context), fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Mostrar rota',
            iconSize: 18,
            icon: Icon(Icons.center_focus_strong,
                color: overlayTextMuted(context)),
            onPressed: widget.onShowRoute,
          ),
          IconButton(
            tooltip: 'Compartilhar rota',
            iconSize: 18,
            icon: Icon(Icons.share_location, color: overlayTextMuted(context)),
            onPressed: widget.onShare,
          ),
          IconButton(
            tooltip: _minimized ? 'Expandir' : 'Minimizar',
            iconSize: 18,
            icon: Icon(
              _minimized ? Icons.expand_less : Icons.expand_more,
              color: overlayTextMuted(context),
            ),
            onPressed: () => setState(() => _minimized = !_minimized),
          ),
          IconButton(
            tooltip: 'Fechar',
            iconSize: 18,
            icon: Icon(Icons.close, color: overlayTextMuted(context)),
            onPressed: widget.onClose,
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
            color: overlayTextMuted(context).withValues(alpha: 0.18), height: 1),
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

  /// Confirmacao real antes de marcar a entrega.
  Future<void> _confirmarEntrega(int index) async {
    final provider = context.read<RouteProvider>();
    final stops = provider.stops;
    if (index < 0 || index >= stops.length) return;
    final stop = stops[index];
    final cliente =
        stop.customer.isNotEmpty ? stop.customer : (stop.label.isNotEmpty ? stop.label : 'parada ${index + 1}');
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
