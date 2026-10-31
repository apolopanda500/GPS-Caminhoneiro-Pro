import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:gps_camioneiro_pro/core/utils/moon.dart';
import 'package:gps_camioneiro_pro/core/utils/solar.dart';

/// Camada de "modo realista": escurece o mapa conforme o sol e a lua reais.
///
/// Nao troca o estilo do mapa (isso recarregaria tudo); aplica apenas um veu
/// de cor sobre ele, com transicao suave. De dia fica transparente, no
/// crepusculo ganha um tom alaranjado e a noite vira azul profundo, com
/// estrelas e mais claro quando a lua esta cheia.
class RealismoOverlay extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final bool ativo;

  const RealismoOverlay({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.ativo,
  });

  @override
  State<RealismoOverlay> createState() => _RealismoOverlayState();
}

class _RealismoOverlayState extends State<RealismoOverlay> {
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _relogio = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.latitude;
    final lon = widget.longitude;
    if (!widget.ativo || lat == null || lon == null) {
      return const SizedBox.shrink();
    }
    final solar = calcularSolar(latitude: lat, longitude: lon);
    final lua = calcularLua();
    final escuridao = fatorEscuridao(
      elevacaoGraus: solar.elevacaoGraus,
      iluminacaoLua: lua.iluminacao,
    );
    if (escuridao <= 0.01) return const SizedBox.shrink();
    final cores = _coresDoCeu(solar.elevacaoGraus);
    final noiteFechada = solar.elevacaoGraus < -6;
    final opacidadeEstrelas = noiteFechada
        ? ((escuridao - 0.3) * 0.9 * (1 - lua.iluminacao / 100 * 0.6))
            .clamp(0.0, 0.55)
        : 0.0;

    return IgnorePointer(
      child: SizedBox.expand(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cores.$1.withValues(alpha: escuridao),
                cores.$2.withValues(alpha: escuridao),
              ],
            ),
          ),
          child: opacidadeEstrelas > 0.01
              ? CustomPaint(
                  painter: _EstrelasPainter(opacidade: opacidadeEstrelas),
                  size: Size.infinite,
                )
              : null,
        ),
      ),
    );
  }

  (Color, Color) _coresDoCeu(double elevacao) {
    if (elevacao >= 6) {
      return (Colors.transparent, Colors.transparent);
    }
    if (elevacao >= 0) {
      final t = (1 - elevacao / 6).clamp(0.0, 1.0);
      return (
        Color.lerp(const Color(0xFFFFB26B), const Color(0xFF3E2F6B), t) ??
            Colors.transparent,
        Color.lerp(const Color(0xFFFF8A5B), const Color(0xFF241B47), t) ??
            Colors.transparent,
      );
    }
    final t = (-elevacao / 12).clamp(0.0, 1.0);
    return (
      Color.lerp(const Color(0xFF16213E), const Color(0xFF050914), t) ??
          const Color(0xFF050914),
      Color.lerp(const Color(0xFF2A3B63), const Color(0xFF0B1026), t) ??
          const Color(0xFF0B1026),
    );
  }
}

/// Estrelas discretas no ceu noturno (deterministicas por hora).
class _EstrelasPainter extends CustomPainter {
  final double opacidade;

  _EstrelasPainter({required this.opacidade});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final hora = DateTime.now();
    final rnd = math.Random(hora.year * 10000 + hora.month * 500 +
        hora.day * 31 + hora.hour);
    final paint = Paint()..color = Colors.white.withValues(alpha: opacidade);
    final quantidade = (size.width * size.height / 9000).clamp(30, 120).toInt();
    for (var i = 0; i < quantidade; i++) {
      final raio = rnd.nextDouble() * 1.3 + 0.3;
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        raio,
        paint..color = Colors.white
            .withValues(alpha: opacidade * (0.4 + rnd.nextDouble() * 0.6)),
      );
    }
  }

  @override
  bool shouldRepaint(_EstrelasPainter oldDelegate) =>
      oldDelegate.opacidade != opacidade;
}
