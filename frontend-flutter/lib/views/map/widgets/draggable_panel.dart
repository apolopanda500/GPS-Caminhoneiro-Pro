import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Painel flutuante que pode ser arrastado para qualquer canto do mapa.
///
/// Quando recebe um [id], a posicao fica salva em SharedPreferences
/// (chave `panel.pos.<id>`) e e restaurada no proximo app aberto.
class DraggablePanel extends StatefulWidget {
  final Widget child;
  final Offset initial;
  final EdgeInsets clampPadding;

  /// Identificador do painel. Se null, a posicao nao e persistida.
  final String? id;

  const DraggablePanel({
    super.key,
    required this.child,
    this.initial = const Offset(16, 96),
    this.clampPadding = const EdgeInsets.all(8),
    this.id,
  });

  @override
  State<DraggablePanel> createState() => _DraggablePanelState();
}

class _DraggablePanelState extends State<DraggablePanel> {
  late Offset _offset = widget.initial;

  static String _chave(String id) => 'panel.pos.$id';

  @override
  void initState() {
    super.initState();
    _restaurarPosicao();
  }

  Future<void> _restaurarPosicao() async {
    final id = widget.id;
    if (id == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble('${_chave(id)}.x');
      final y = prefs.getDouble('${_chave(id)}.y');
      if (!mounted || x == null || y == null) return;
      setState(() {
        _offset = Offset(x, y);
      });
    } catch (_) {}
  }

  Future<void> _salvarPosicao() async {
    final id = widget.id;
    if (id == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('${_chave(id)}.x', _offset.dx);
      await prefs.setDouble('${_chave(id)}.y', _offset.dy);
    } catch (_) {}
  }

  void _mover(DragUpdateDetails d) {
    final mq = MediaQuery.of(context).size;
    final pad = widget.clampPadding;
    setState(() {
      _offset += d.delta;
      _offset = Offset(
        _offset.dx.clamp(pad.left, mq.width - pad.right - 60),
        _offset.dy.clamp(pad.top, mq.height - pad.bottom - 60),
      );
    });
  }

  void _soltar() {
    _salvarPosicao();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanUpdate: _mover,
        onPanEnd: (_) => _soltar(),
        child: widget.child,
      ),
    );
  }
}
