import 'package:flutter/material.dart';

import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';

/// Onda de aviso: um circulo que cresce a partir do ponto tocado, como o
/// "pulso" de um radar. Usado quando o motorista compartilha a posicao ou
/// marca um sinal, para chamar atencao de quem esta perto.
class OndaAviso extends StatefulWidget {
  final Offset posicao;
  final Color cor;
  final double raioMaximo;
  final VoidCallback? aoTerminar;

  const OndaAviso({
    super.key,
    required this.posicao,
    this.cor = kEmergencyRed,
    this.raioMaximo = 260,
    this.aoTerminar,
  });

  @override
  State<OndaAviso> createState() => _OndaAvisoState();
}

class _OndaAvisoState extends State<OndaAviso>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      if (widget.aoTerminar != null) widget.aoTerminar!();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_controller.value);
        return IgnorePointer(
          child: Stack(
            children: [
              Positioned(
                left: widget.posicao.dx - widget.raioMaximo * t,
                top: widget.posicao.dy - widget.raioMaximo * t,
                width: widget.raioMaximo * 2 * t,
                height: widget.raioMaximo * 2 * t,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.cor.withValues(alpha: 0.75 * (1 - t)),
                      width: 3.5,
                    ),
                    color: widget.cor.withValues(alpha: 0.12 * (1 - t)),
                  ),
                ),
              ),
              Positioned(
                left: widget.posicao.dx - 26,
                top: widget.posicao.dy - 26,
                width: 52,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.cor.withValues(alpha: 0.85),
                    boxShadow: [
                      BoxShadow(
                        color: widget.cor.withValues(alpha: 0.5),
                        blurRadius: 18,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.campaign, color: Colors.white, size: 26),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
