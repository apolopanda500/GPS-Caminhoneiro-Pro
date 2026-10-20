import 'package:flutter/material.dart';

/// Painel flutuante que pode ser arrastado para qualquer canto do mapa.
class DraggablePanel extends StatefulWidget {
  final Widget child;
  final Offset initial;
  final EdgeInsets clampPadding;

  const DraggablePanel({
    super.key,
    required this.child,
    this.initial = const Offset(16, 96),
    this.clampPadding = const EdgeInsets.all(8),
  });

  @override
  State<DraggablePanel> createState() => _DraggablePanelState();
}

class _DraggablePanelState extends State<DraggablePanel> {
  late Offset _offset = widget.initial;

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

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanUpdate: _mover,
        child: widget.child,
      ),
    );
  }
}
