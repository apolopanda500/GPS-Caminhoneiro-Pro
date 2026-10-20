import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/radio_sheet.dart';

/// Botao flutuante do radio digital sobre o mapa.
///
/// Usa FloatingActionButton padrao (heroTag unico) para nao conflitar com
/// o sistema de paineis arrastaveis do mapa.
class RadioFab extends StatefulWidget {
  final Color surface;
  final Color accent;
  final VoidCallback onPressed;

  const RadioFab({
    super.key,
    required this.surface,
    required this.accent,
    required this.onPressed,
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

  @override
  Widget build(BuildContext context) {
    final tocando = context.select<AudioProvider, bool>((a) => a.radioTocando);
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
        backgroundColor: widget.surface,
        foregroundColor: tocando ? widget.accent : Colors.white,
        elevation: 2,
        child: Icon(
          tocando ? Icons.graphic_eq : Icons.radio_outlined,
          size: 22,
        ),
      ),
    );
  }
}

/// Atalho que abre o sheet de radio do agente A.
Future<void> abrirRadioDigital(BuildContext context) =>
    RadioSheet.open(context);
