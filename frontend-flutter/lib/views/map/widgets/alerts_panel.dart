import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/utils/overlay_style.dart';
import 'package:gps_camioneiro_pro/data/models/alert_model.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';

/// Painel flutuante de sinais e alertas da estrada.
///
/// Fica sobre o mapa sem travar a tela: pode ser arrastado, minimizado
/// (some com a lista e deixa só o contador) e fechado pelo usuário.
class AlertsPanel extends StatefulWidget {
  final List<AlertModel> alerts;
  final Color? surface;
  final Color? accent;
  final VoidCallback onClose;
  final Offset initialOffset;

  const AlertsPanel({
    super.key,
    required this.alerts,
    this.surface,
    this.accent,
    required this.onClose,
    this.initialOffset = const Offset(16, 96),
  });

  @override
  State<AlertsPanel> createState() => _AlertsPanelState();
}

class _AlertsPanelState extends State<AlertsPanel> {
  bool _minimized = false;

  static const double _maxHeight = 260;
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

    // Sem Positioned: quem posiciona e o FloatingPanel que envolve o painel.
    return SizedBox(
      width: _width,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: _maxHeight),
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
              if (!_minimized && alerts.isNotEmpty)
                Flexible(child: _lista(alerts, texto)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cabecalho(int total, Color texto, Color cor) {
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
                    total == 0
                        ? 'Sinais da estrada'
                        : 'Sinais da estrada ($total)',
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
                  decoration: const BoxDecoration(
                    color: Color(0xFF39FF14),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
            IconButton(
              tooltip: _minimized ? 'Expandir' : 'Minimizar',
              iconSize: 18,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: EdgeInsets.zero,
              icon: Icon(
                _minimized ? Icons.expand_less : Icons.expand_more,
                color: texto,
              ),
              onPressed: () => setState(() => _minimized = !_minimized),
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

  Widget _lista(List<AlertModel> alerts, Color texto) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        final cor = _corDoTipo(alert.type);
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cor.withValues(alpha: 0.5)),
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
                      '[${alert.type.toUpperCase()}] '
                      '${alert.message ?? 'Sem mensagem'}',
                      style: TextStyle(color: texto, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _idade(alert.createdAt),
                      style: TextStyle(
                        color: texto.withValues(alpha: 0.55),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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
