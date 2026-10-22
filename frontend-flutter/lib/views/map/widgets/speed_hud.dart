import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';

/// HUD de velocidade: a leitura principal do motorista.
///
/// Numero grande (e o que se olha), unidade pequena, limite da via e o
/// nome da rua embaixo. Cabe em uma linha e nao cobre a estrada.
class SpeedHUD extends StatelessWidget {
  final double speedKmh;
  final int? limitKmh;
  final String? streetName;

  const SpeedHUD({
    super.key,
    this.speedKmh = 0,
    this.limitKmh,
    this.streetName,
  });

  bool get _overLimit => limitKmh != null && speedKmh > (limitKmh! + 8);

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
    final limit = limitKmh;
    final settings = _ajustes(context);
    final corPrincipal = _overLimit
        ? const Color(0xFFFF5252)
        : (settings?.overlayColor ?? kEmergencyRed);
    final corTexto = overlayText(context);
    final rua = (streetName ?? '').trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: overlaySurface(context,
            opacity: settings?.overlayOpacity ?? 1.0,
            accent: settings?.overlayColor),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: corPrincipal, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Icon(Icons.speed, color: corPrincipal, size: 22),
              const SizedBox(width: 8),
              // Numero grande: e o que o motorista le de relance.
              Text(
                speedKmh.toStringAsFixed(0),
                style: TextStyle(
                  color: corPrincipal,
                  fontSize: 32,
                  height: 1.0,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 4),
              // Unidade menor: nao compete com o numero.
              Text(
                'km/h',
                style: TextStyle(
                  color: corTexto.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (limit != null && limit > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: overlayTextMuted(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _overLimit
                          ? const Color(0xFFFF5252)
                          : overlayTextMuted(context).withValues(alpha: 0.30),
                    ),
                  ),
                  child: Text(
                    'máx $limit',
                    style: TextStyle(
                      color: _overLimit
                          ? const Color(0xFFFF5252)
                          : overlayTextMuted(context),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (rua.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_outlined,
                    size: 12, color: corTexto.withValues(alpha: 0.55)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    rua,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: corTexto.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
