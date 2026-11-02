import 'package:flutter/material.dart';

import 'package:gps_camioneiro_pro/core/rota/manobra.dart';

class NavegacaoBanner extends StatelessWidget {
  final Manobra proxima;
  final double distancia;
  final double restante;

  const NavegacaoBanner({
    super.key,
    required this.proxima,
    required this.distancia,
    required this.restante,
  });

  IconData get _icone {
    final t = proxima.tipo;
    const mapa = <String, IconData>{
      'esquerda': Icons.turn_left,
      'direita': Icons.turn_right,
      'levemente_esquerda': Icons.turn_slight_left,
      'levemente_direita': Icons.turn_slight_right,
      'manter_esquerda': Icons.turn_sharp_left,
      'manter_direita': Icons.turn_sharp_right,
      'retorno': Icons.u_turn_right,
      'rotatoria': Icons.fork_right,
      'rotatoria_esquerda': Icons.fork_left,
      'rotatoria_direita': Icons.fork_right,
      'fusao': Icons.merge,
      'saida_esquerda': Icons.exit_to_app_rounded,
      'saida_direita': Icons.exit_to_app_rounded,
      'garfo_esquerda': Icons.fork_left,
      'garfo_direita': Icons.fork_right,
      'rampa': Icons.ramp_left,
      'chegada': Icons.place,
      'partida': Icons.trip_origin,
      'reto': Icons.straight,
    };
    return mapa[t] ?? Icons.straight;
  }

  String get _distanciaTexto {
    if (distancia >= 1000) {
      return '${(distancia / 1000).toStringAsFixed(1)} km';
    }
    return '${distancia.round()} m';
  }

  String get _restanteTexto {
    if (restante >= 1000) {
      return '${(restante / 1000).toStringAsFixed(0)} km restantes';
    }
    return '${restante.round()} m restantes';
  }

  @override
  Widget build(BuildContext context) {
    final faixas = proxima.faixas;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101820).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(_icone, color: Colors.amber, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_distanciaTexto — ${proxima.texto}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _restanteTexto,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          if (faixas.isNotEmpty) ...[
            const SizedBox(width: 8),
            _Faixas(faixas: faixas),
          ],
        ],
      ),
    );
  }
}

class _Faixas extends StatelessWidget {
  final List<FaixaRota> faixas;

  const _Faixas({required this.faixas});

  @override
  Widget build(BuildContext context) {
    const largura = 14.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          key: const ValueKey('lane_guidance'),
          children: [
            for (final f in faixas.take(6))
              _FaixaCone(
                borda: largura,
                ponta: f.eValida ? Colors.greenAccent : Colors.white24,
                portas: true,
              ),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          'faixas',
          style: TextStyle(color: Colors.white38, fontSize: 9),
        ),
      ],
    );
  }
}

class _FaixaCone extends StatelessWidget {
  final double borda;
  final Color ponta;
  final bool portas;

  const _FaixaCone({
    required this.borda,
    required this.ponta,
    this.portas = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(borda + 2, portas ? 22 : 16),
      painter: _FaixaPainter(borda: borda, cor: ponta),
    );
  }
}

class _FaixaPainter extends CustomPainter {
  final double borda;
  final Color cor;

  _FaixaPainter({required this.borda, required this.cor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = cor;
    final path = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(borda / 2 + 1, 2)
      ..lineTo(borda + 1, 2)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FaixaPainter old) =>
      old.cor != cor || old.borda != borda;
}
