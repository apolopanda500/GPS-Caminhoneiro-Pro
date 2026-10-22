import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';

/// Botao flutuante do radio digital sobre o mapa.
///
/// Usa FloatingActionButton padrao (heroTag unico) para nao conflitar com
/// o sistema de paineis arrastaveis do mapa.
class RadioFab extends StatefulWidget {
  final Color? surface;
  final Color? accent;
  final VoidCallback onPressed;
  final VoidCallback? onStop;

  const RadioFab({
    super.key,
    this.surface,
    this.accent,
    required this.onPressed,
    this.onStop,
  });

  @override
  State<RadioFab> createState() => _RadioFabState();
}

class _RadioFabState extends State<RadioFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

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
    final tocando = context.select<AudioProvider, bool>((a) => a.radioTocando);
    final settings = _ajustes(context);
    final cor = widget.accent ?? settings?.overlayColor ?? kEmergencyRed;
    final superficie = widget.surface ??
        overlaySurface(context,
            opacity: settings?.overlayOpacity ?? 1.0,
            accent: settings?.overlayColor);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final escala = tocando ? 1.0 + (_pulse.value * 0.08) : 1.0;
        return Transform.scale(scale: escala, child: child);
      },
      child: FloatingActionButton(
        heroTag: 'fab_radio',
        tooltip: tocando ? 'Rádio tocando' : 'Abrir rádio',
        onPressed: widget.onPressed,
        backgroundColor: superficie,
        foregroundColor: tocando ? cor : Colors.white,
        elevation: 2,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              tocando ? Icons.graphic_eq : Icons.radio_outlined,
              size: 22,
            ),
            if (tocando && widget.onStop != null)
              Positioned(
                right: -3,
                bottom: -3,
                child: GestureDetector(
                  onTap: widget.onStop,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: superficie,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.stop, size: 11, color: cor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
