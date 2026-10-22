import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/providers/shared_routes_provider.dart';

/// Painel das **rotas compartilhadas** do grupo.
///
/// - O motorista escolhe quais rotas quer ver (1 de 10, 9 de 10, todas).
/// - Quem acompanha ve as paradas do outro motorista mudando em tempo real.
/// - O dono pode remover a rota do grupo.
class SharedRoutesPanel extends StatelessWidget {
  final String driverId;
  final void Function(SharedRoute rota) onSeguir;
  final void Function(SharedRoute rota) onPararDeSeguir;
  final void Function(SharedRoute rota) onRemover;
  final void Function(SharedRoute rota) onCentralizar;

  const SharedRoutesPanel({
    super.key,
    required this.driverId,
    required this.onSeguir,
    required this.onPararDeSeguir,
    required this.onRemover,
    required this.onCentralizar,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharedRoutesProvider>();
    final tema = Theme.of(context);
    final ink = tema.colorScheme.onSurface;
    final rotas = provider.todas;

    if (rotas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Text(
          'Nenhuma rota compartilhada no grupo ainda.\n'
          'Na aba Grupos, compartilhe a sua rota para o comboio acompanhar.',
          style: TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'ROTAS COMPARTILHADAS (${provider.totalVisiveis} de ${provider.total} visíveis)',
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Ver todas',
                icon: const Icon(Icons.visibility_outlined, size: 18),
                onPressed: provider.mostrarTodas,
              ),
              IconButton(
                tooltip: 'Ocultar todas',
                icon: const Icon(Icons.visibility_off_outlined, size: 18),
                onPressed: provider.ocultarTodas,
              ),
            ],
          ),
        ),
        ...rotas.map((rota) {
          final minha = rota.ownerDriverId == driverId;
          final visivel = provider.isVisivel(rota.shareId);
          final seguindo = provider.isSeguindo(rota.shareId);
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            decoration: BoxDecoration(
              color: visivel
                  ? kEmergencyRed.withValues(alpha: 0.10)
                  : tema.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: visivel
                    ? kEmergencyRed.withValues(alpha: 0.35)
                    : Colors.white12,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      minha ? Icons.local_shipping : Icons.route,
                      size: 16,
                      color: visivel ? kEmergencyRed : ink.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${minha ? 'Minha rota' : rota.ownerName}'
                            '${rota.nome.isNotEmpty ? ' • ${rota.nome}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ink,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${rota.totalParadas} paradas • '
                            '${rota.entregues} entregues • '
                            '${rota.chegadas} no local',
                            style: TextStyle(
                              color: ink.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: visivel ? 'Ocultar rota' : 'Ver rota',
                      icon: Icon(
                        visivel
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                      onPressed: () => provider.alternarVisibilidade(rota.shareId),
                    ),
                  ],
                ),
                if (visivel && rota.stops.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < rota.stops.length; i++)
                          _ChipParada(
                            indice: i,
                            status: rota.statusDaParada(i),
                            rotulo: rota.stops[i].customer.isNotEmpty
                                ? rota.stops[i].customer
                                : '${i + 1}',
                          ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => onCentralizar(rota),
                      icon: const Icon(Icons.my_location, size: 16),
                      label: const Text('VER NO MAPA', style: TextStyle(fontSize: 11)),
                    ),
                    const Spacer(),
                    if (!minha)
                      TextButton.icon(
                        onPressed: () =>
                            seguindo ? onPararDeSeguir(rota) : onSeguir(rota),
                        icon: Icon(
                          seguindo ? Icons.stop_circle_outlined : Icons.play_circle,
                          size: 16,
                          color: seguindo ? kEmergencyRed : null,
                        ),
                        label: Text(
                          seguindo ? 'PARAR' : 'ACOMPANHAR',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    if (minha)
                      IconButton(
                        tooltip: 'Remover do grupo',
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => onRemover(rota),
                      ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Etiqueta do status de uma parada compartilhada.
class _ChipParada extends StatelessWidget {
  const _ChipParada({
    required this.indice,
    required this.status,
    required this.rotulo,
  });

  final int indice;
  final String status;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    Color cor;
    String icone;
    switch (status) {
      case StatusParadaCompartilhada.entregue:
        cor = const Color(0xFF2E7D32);
        icone = '✓';
        break;
      case StatusParadaCompartilhada.chegou:
        cor = const Color(0xFFF9A825);
        icone = '●';
        break;
      default:
        cor = Colors.white24;
        icone = '○';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.6)),
      ),
      child: Text(
        '$icone ${indice + 1}. $rotulo',
        style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
