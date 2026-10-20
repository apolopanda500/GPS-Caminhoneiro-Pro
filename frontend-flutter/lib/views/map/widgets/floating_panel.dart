import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Painel flutuante organizavel.
///
/// - Arrasta para qualquer lugar da tela (o toque continua funcionando: o
///   arrasto e do painel, o clique e do conteudo).
/// - Solta na borda esquerda/direita: o painel **minimiza** naquele lado e
///   vira uma tab compacta. Tocar na tab expande de novo.
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

  /// Mostra o botao de minimizar/expandir no canto do painel.
  final bool showToggle;

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
    this.showToggle = true,
  });

  @override
  State<FloatingPanel> createState() => _FloatingPanelState();
}

class _FloatingPanelState extends State<FloatingPanel> {
  late Offset _offset = widget.initial;
  bool _minimizado = false;
  bool _ladoEsquerdo = false;
  bool _carregado = false;

  String get _chavePos => 'panel.pos.${widget.id}';
  String get _chaveEstado => 'panel.state.${widget.id}';

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
      if (!mounted) return;
      setState(() {
        if (x != null && y != null) _offset = Offset(x, y);
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
      await prefs.setString(
          _chaveEstado, _minimizado ? 'min|${_ladoEsquerdo ? 'esq' : 'dir'}' : 'aberto');
    } catch (_) {}
  }

  void _arrastar(DragUpdateDetails d) {
    final mq = MediaQuery.of(context).size;
    setState(() {
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
                widget.child,
              ],
            ),
          ),
          if (widget.showToggle)
            Positioned(
              top: 2,
              right: 2,
              child: _BotaoMinimizar(
                minimizado: _minimizado,
                onTap: () {
                  setState(() => _minimizado = !_minimizado);
                  _salvar();
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Botao pequeno de minimizar/expandir do painel flutuante.
class _BotaoMinimizar extends StatelessWidget {
  final bool minimizado;
  final VoidCallback onTap;

  const _BotaoMinimizar({
    required this.minimizado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: minimizado ? 'Expandir painel' : 'Minimizar painel',
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(
              minimizado ? Icons.open_in_full : Icons.minimize,
              size: 13,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
