import 'package:flutter/material.dart';

import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/utils/orientacao_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Painel flutuante organizavel.
///
/// - Arrasta para qualquer lugar da tela (o toque continua funcionando: o
///   arrasto e do painel, o clique e do conteudo).
/// - Solta na borda esquerda/direita: o painel **minimiza** naquele lado e
///   vira uma tab compacta. Tocar na tab expande de novo.
/// - Nao ha botao de minimizar no painel: arrastar para a lateral ja fecha
///   (minimiza) e o toque na tab reabre.
/// - A posicao e o estado (aberto/minimizado) ficam salvos por [id].
class FloatingPanel extends StatefulWidget {
  final String id;
  final Widget child;

  /// Conteudo compacto quando o painel esta minimizado (icone/atalho).
  final Widget? minimizedChild;

  /// Posicao inicial (usada quando ainda nao foi salvo).
  final Offset initial;

  /// Largura do painel (para calcular as bordas).
  final double width;

  /// Altura aproximada (para a tab compacta).
  final double height;

  /// Se true, o painel nao pode ser minimizado (fica sempre aberto).
  final bool alwaysOpen;

  /// Puxador de arraste. Se null, o arrasto funciona em todo o painel
  /// (use apenas em paineis sem lista/scroll).
  final Widget? handle;

  /// Arrastar funciona em todo o conteudo (ignore o [handle]).
  final bool dragWholeChild;

  /// Mostra a alca para aumentar/diminuir o painel.
  final bool resizable;

  const FloatingPanel({
    super.key,
    required this.id,
    required this.child,
    this.minimizedChild,
    this.initial = const Offset(16, 96),
    this.width = 220,
    this.height = 120,
    this.alwaysOpen = false,
    this.handle,
    this.dragWholeChild = false,
    this.resizable = true,
  });

  @override
  State<FloatingPanel> createState() => _FloatingPanelState();
}

class _FloatingPanelState extends State<FloatingPanel> {
  late Offset _offset = widget.initial;

  /// Tamanho do painel depois do redimensionamento. Enquanto for null o
  /// painel usa o tamanho natural do seu conteudo.
  double? _largura;
  double? _altura;

  bool _minimizado = false;
  bool _ladoEsquerdo = false;
  bool _carregado = false;

  String get _chavePos => 'panel.pos.${widget.id}';
  String get _chaveEstado => 'panel.state.${widget.id}';
  String get _chaveTamanho => 'panel.size.${widget.id}';

  @override
  void initState() {
    super.initState();
    _restaurar();
  }

  Future<void> _restaurar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble('$_chavePos.x');
      final y = prefs.getDouble('$_chavePos.y');
      final estado = prefs.getString(_chaveEstado);
      final largura = prefs.getDouble('$_chaveTamanho.w');
      final altura = prefs.getDouble('$_chaveTamanho.h');
      if (!mounted) return;
      setState(() {
        if (x != null && y != null) {
          _offset = OrientacaoLayout.limitarTela(
            context,
            Offset(x, y),
            larguraPainel: widget.width,
            alturaPainel: widget.height,
          );
        }
        if (largura != null) _largura = largura.clamp(_larguraMin, _larguraMax);
        if (altura != null) _altura = altura.clamp(_alturaMin, _alturaMax);
        if (estado != null) {
          final partes = estado.split('|');
          _minimizado = partes.isNotEmpty && partes[0] == 'min';
          _ladoEsquerdo = partes.length > 1 && partes[1] == 'esq';
        }
        _carregado = true;
      });
    } catch (_) {
      if (mounted) setState(() => _carregado = true);
    }
  }

  Future<void> _salvar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('$_chavePos.x', _offset.dx);
      await prefs.setDouble('$_chavePos.y', _offset.dy);
      if (_largura != null) await prefs.setDouble('$_chaveTamanho.w', _largura!);
      if (_altura != null) await prefs.setDouble('$_chaveTamanho.h', _altura!);
      await prefs.setString(
          _chaveEstado, _minimizado ? 'min|${_ladoEsquerdo ? 'esq' : 'dir'}' : 'aberto');
    } catch (_) {}
  }

  double get _larguraMin => widget.width * 0.6;
  double get _larguraMax => widget.width * 2.2;
  double get _alturaMin => 64.0;
  double get _alturaMax => widget.height * 2.2;

  /// Redimensiona o painel arrastando a alca no canto inferior direito.
  void _redimensionar(DragUpdateDetails d) {
    setState(() {
      _largura = ((_largura ?? widget.width) + d.delta.dx)
          .clamp(_larguraMin, _larguraMax);
      _altura = ((_altura ?? widget.height) + d.delta.dy)
          .clamp(_alturaMin, _alturaMax);
    });
  }

  void _arrastar(DragUpdateDetails d) {
    setState(() {
      final mq = MediaQuery.of(context).size;
      _offset = Offset(
        (_offset.dx + d.delta.dx).clamp(-40.0, mq.width - 40.0),
        (_offset.dy + d.delta.dy).clamp(0.0, mq.height - 40.0),
      );
      _ladoEsquerdo = _offset.dx < mq.width / 2;
    });
  }

  void _soltar() {
    final mq = MediaQuery.of(context).size;
    setState(() {});
    // Soltou muito perto da borda: minimiza para aquele lado.
    if (!widget.alwaysOpen) {
      const margem = 24.0;
      if (_offset.dx <= margem) {
        setState(() {
          _minimizado = true;
          _ladoEsquerdo = true;
        });
      } else if (_offset.dx >= mq.width - margem) {
        setState(() {
          _minimizado = true;
          _ladoEsquerdo = false;
        });
      }
    }
    _salvar();
  }

  void _alternarMinimizado() {
    setState(() {
      _minimizado = !_minimizado;
      if (_minimizado) _ladoEsquerdo = _offset.dx < MediaQuery.of(context).size.width / 2;
    });
    _salvar();
  }
  @override
  Widget build(BuildContext context) {
    if (!_carregado) {
      return const SizedBox.shrink();
    }

    if (_minimizado) {
      final mq = MediaQuery.of(context).size;
      return Positioned(
        left: _ladoEsquerdo ? 4 : mq.width - 52,
        top: _offset.dy.clamp(0.0, mq.height - 60),
        child: GestureDetector(
          onTap: _alternarMinimizado,
          onVerticalDragUpdate: (d) => setState(() {
            _offset = Offset(
              _offset.dx,
              (_offset.dy + d.delta.dy).clamp(0.0, mq.height - 60),
            );
          }),
          onVerticalDragEnd: (_) => _salvar(),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            shape: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: widget.minimizedChild ??
                  const Icon(Icons.open_in_full, size: 20),
            ),
          ),
        ),
      );
    }

    // Sem puxador definido, o arrasto funciona no painel inteiro.
    final arrastarTudo = widget.dragWholeChild || widget.handle == null;

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onPanUpdate: arrastarTudo ? _arrastar : null,
            onPanEnd: arrastarTudo ? (_) => _soltar() : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.handle != null)
                  GestureDetector(
                    onPanUpdate: _arrastar,
                    onPanEnd: (_) => _soltar(),
                    onDoubleTap: () =>
                        setState(() => _minimizado = !_minimizado),
                    child: widget.handle!,
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: _largura ?? 0,
                    maxWidth: _largura ?? double.infinity,
                    minHeight: 0,
                    maxHeight: _altura ?? double.infinity,
                  ),
                  child: widget.child,
                ),
              ],
            ),
          ),
          if (widget.resizable)
            Positioned(
              right: 2,
              bottom: 2,
              child: GestureDetector(
                onPanUpdate: _redimensionar,
                onPanEnd: (_) => _salvar(),
                child: Tooltip(
                  message: 'Arraste para redimensionar',
                  child: Icon(
                    Icons.open_in_full,
                    size: 13,
                    color: overlayTextMuted(context).withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

