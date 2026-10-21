import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/utils/overlay_style.dart';
import 'package:gps_camioneiro_pro/data/models/alert_model.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';

/// Painel flutuante dos sinais da estrada.
///
/// Mostra tudo que acontece na estrada em tempo real. Tocar em um sinal o
/// seleciona e devolve a coordenada para o mapa destacar o local, deixando o
/// motorista ver rapido onde o sinal esta.
class AlertsPanel extends StatefulWidget {
  final List<AlertModel> alerts;
  final Color? surface;
  final Color? accent;
  final VoidCallback onClose;

  /// Cria um sinal na estrada (usado quando nao ha nenhum).
  final VoidCallback? onCriarSinal;

  /// Chamado quando o motorista toca em um sinal: devolve o sinal escolhido
  /// para o mapa destacar (ou null quando o sinal esta sem coordenada).
  final ValueChanged<AlertModel?>? onSelect;

  /// Sinal que esta selecionado no mapa.
  final String? selectedId;

  const AlertsPanel({
    super.key,
    required this.alerts,
    this.surface,
    this.accent,
    required this.onClose,
    this.onCriarSinal,
    this.onSelect,
    this.selectedId,
  });

  @override
  State<AlertsPanel> createState() => _AlertsPanelState();
}

class _AlertsPanelState extends State<AlertsPanel> {
  bool _minimizado = false;

  /// Largura padrao do painel (o FloatingPanel pode redimensionar).
  static const double _width = 300;

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
    final alerts = widget.alerts;
    final texto = overlayText(context);
    final settings = _ajustes(context);
    final cor = widget.accent ?? settings?.overlayColor ?? kOverlayAccents.first;
    final superficie = widget.surface ??
        overlaySurface(context, opacity: settings?.overlayOpacity ?? 1.0);

    // Sem Positioned: quem posiciona e o FloatingPanel que envelopa o painel.
    return SizedBox(
      width: _width,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: superficie,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: overlayBorder(context, accent: cor),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _cabecalho(alerts.length, texto, cor),
                if (!_minimizado && alerts.isEmpty)
                  _vazio(context, texto, cor)
                else if (!_minimizado && alerts.isNotEmpty)
                  Flexible(child: _lista(alerts, texto, cor)),
              ],
            ),
        ),
      ),
    );
  }

  /// Estado vazio: nenhum sinal na estrada. Oferece avisar a comunidade.
  Widget _vazio(BuildContext context, Color texto, Color cor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: cor, size: 30),
          const SizedBox(height: 8),
          Text(
            'Nenhum sinal por perto agora.',
            textAlign: TextAlign.center,
            style: TextStyle(color: texto, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Avise a comunidade sobre radar, buraco, ponte baixa ou '
            'estrada interditada. Todos os caminhoneiros veem na hora.',
            textAlign: TextAlign.center,
            style: TextStyle(color: texto.withValues(alpha: 0.6), fontSize: 11),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onCriarSinal,
              icon: const Icon(Icons.add_location_alt, size: 17),
              label: const Text('AVISAR A COMUNIDADE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cabecalho(int total, Color texto, Color cor) {
    final aoVivo = total > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.18),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: cor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    total == 0 ? 'Sinais da estrada' : 'Sinais da estrada ($total)',
                    style: TextStyle(
                      color: texto,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: aoVivo
                        ? const Color(0xFF39FF14)
                        : texto.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _minimizado ? 'Expandir' : 'Minimizar',
            iconSize: 18,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            icon: Icon(
              _minimizado ? Icons.expand_less : Icons.expand_more,
              color: texto,
            ),
            onPressed: () => setState(() => _minimizado = !_minimizado),
          ),
          IconButton(
            tooltip: 'Fechar painel',
            iconSize: 18,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.close, color: texto.withValues(alpha: 0.7)),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _lista(List<AlertModel> alerts, Color texto, Color destaque) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        final cor = _corDoTipo(alert.type);
        final selecionado = widget.selectedId != null &&
            widget.selectedId == alert.id;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {});
              widget.onSelect?.call(selecionado ? null : alert);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: cor.withValues(alpha: selecionado ? 0.34 : 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cor.withValues(alpha: selecionado ? 1 : 0.5),
                  width: selecionado ? 2 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: cor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '[${_tipoAmigavel(alert.type)}] '
                          '${alert.message ?? 'Sem mensagem'}',
                          style: TextStyle(
                            color: texto,
                            fontSize: 12,
                            fontWeight:
                                selecionado ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_idade(alert.createdAt)} - toque para destacar no mapa',
                          style: TextStyle(
                            color: texto.withValues(alpha: 0.55),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selecionado)
                    Icon(Icons.my_location, size: 16, color: destaque),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Nome curto do tipo, para o motorista entender sem saber o codigo.
  String _tipoAmigavel(String type) {
    switch (type.toLowerCase()) {
      case 'sinal':
      case 'signal':
        return 'SINAL';
      case 'texto_livre':
      case 'texto':
        return 'AVISO';
      default:
        return type.toUpperCase();
    }
  }

  /// Idade do sinal (ha quanto tempo foi criado), para o motorista saber
  /// se o sinal ainda e recente.
  String _idade(DateTime quando) {
    final minutos = DateTime.now().difference(quando).inMinutes;
    if (minutos < 1) return 'agora mesmo';
    if (minutos < 60) return 'há $minutos min';
    final horas = minutos ~/ 60;
    if (horas < 24) return 'há $horas h';
    return 'há ${horas ~/ 24} d';
  }

  Color _corDoTipo(String type) {
    switch (type.toLowerCase()) {
      case 'sinal':
      case 'signal':
        return const Color(0xFFFFB300);
      case 'acidente':
      case 'accident':
        return const Color(0xFFE53935);
      case 'bloqueio':
      case 'block':
        return const Color(0xFF8E24AA);
      case 'velocidade':
      case 'speed':
        return const Color(0xFF1E88E5);
      default:
        return const Color(0xFF43A047);
    }
  }
}
