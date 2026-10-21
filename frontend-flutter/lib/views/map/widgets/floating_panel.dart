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

  /// O painel foi ocultado pelo usuario (some do mapa).
  bool _oculto = false;

  /// As alcas de redimensionamento ficam escondidas: o painel fica limpo e
  /// elas aparecem com um toque longo no painel.
  bool _mostrarAlcas = false;
  bool _ladoEsquerdo = false;
  bool _carregado = false;

  String get _chavePos => 'panel.pos.${widget.id}';
  String get _chaveEstado => 'panel.state.${widget.id}';
  String get _chaveTamanho => 'panel.size.${widget.id}';
  String get _chaveOculto => 'panel.oculto.${widget.id}';

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
      final oculto = prefs.getBool(_chaveOculto) ?? false;
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
        _oculto = oculto;
        // Nunca abre fora da tela: o painel volta sempre visivel.
        if (x != null && y != null) {
          _offset = OrientacaoLayout.limitarTela(
            context,
            Offset(x, y),
            larguraPainel: _largura ?? widget.width,
            alturaPainel: _altura ?? widget.height,
          );
        }
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
      await prefs.setBool(_chaveOculto, _oculto);
      await prefs.setString(
          _chaveEstado, _minimizado ? 'min|${_ladoEsquerdo ? 'esq' : 'dir'}' : 'aberto');
    } catch (_) {}
  }

  /// Sem limite artificial: o painel pode ficar do tamanho que o motorista
  /// quiser (ate o tamanho da tela).
  double get _larguraMin => 40;
  double get _larguraMax => 4000;
  double get _alturaMin => 40;
  double get _alturaMax => 4000;

  /// Redimensiona o painel arrastando uma das alcas dos cantos.
  ///
  /// lado: 0 = inferior direito, 1 = inferior esquerdo,
  ///       2 = superior direito, 3 = superior esquerdo.
  /// Ao arrastar a alca da esquerda (ou de cima) o painel cresce para
  /// aquele lado, mantendo a borda oposta no lugar.
  void _redimensionar(DragUpdateDetails d, {required int lado}) {
    final cresceParaDireita = lado == 0 || lado == 2;
    final cresceParaBaixo = lado == 0 || lado == 1;
    setState(() {
      var largura = _largura ?? widget.width;
      var altura = _altura ?? widget.height;
      var dx = d.delta.dx;
      var dy = d.delta.dy;

      if (cresceParaDireita) {
        largura += dx;
      } else {
        largura -= dx;
        _offset = Offset(_offset.dx + dx, _offset.dy);
      }
      if (cresceParaBaixo) {
        altura += dy;
      } else {
        altura -= dy;
        _offset = Offset(_offset.dx, _offset.dy + dy);
      }

      _largura = largura.clamp(_larguraMin, _larguraMax);
      _altura = altura.clamp(_alturaMin, _alturaMax);
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

  /// Garante que o painel fique inteiro visivel na tela (nada de comando
  /// cortado ou painel fora da area util).
  void _manterNaTela() {
    final mq = MediaQuery.of(context).size;
    final largura = _largura ?? widget.width;
    final altura = _altura ?? widget.height;
    final maxX = (mq.width - largura).clamp(0.0, double.infinity);
    final maxY = (mq.height - altura).clamp(0.0, double.infinity);
    final x = _offset.dx.clamp(0.0, maxX);
    final y = _offset.dy.clamp(0.0, maxY);
    if (x != _offset.dx || y != _offset.dy) {
      _offset = Offset(x, y);
    }
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
    _manterNaTela();
    _salvar();
  }

  void _alternarMinimizado() {
    setState(() {
      _minimizado = !_minimizado;
      if (_minimizado) _ladoEsquerdo = _offset.dx < MediaQuery.of(context).size.width / 2;
    });
    _salvar();
  }

  /// Menu da tab lateral (estilo iPhone): expandir, redimensionar ou ocultar.
  void _menuDaTab(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.open_in_full),
              title: const Text('Expandir painel'),
              onTap: () {
                Navigator.pop(ctx);
                _alternarMinimizado();
              },
            ),
            ListTile(
              leading: const Icon(Icons.zoom_in),
              title: const Text('Aumentar'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _largura = ((_largura ?? widget.width) * 1.25)
                      .clamp(_larguraMin, _larguraMax);
                  _altura = ((_altura ?? widget.height) * 1.25)
                      .clamp(_alturaMin, _alturaMax);
                });
                _salvar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.zoom_out),
              title: const Text('Diminuir'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _largura = ((_largura ?? widget.width) * 0.8)
                      .clamp(_larguraMin, _larguraMax);
                  _altura = ((_altura ?? widget.height) * 0.8)
                      .clamp(_alturaMin, _alturaMax);
                });
                _salvar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.redAccent),
              title: const Text('Ocultar painel'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _oculto = true);
                _salvar();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Menu do painel (toque longo): redimensionar, mostrar as alcas ou ocultar.
  void _menuDoPainel(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.zoom_in),
              title: const Text('Aumentar painel'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _largura = ((_largura ?? widget.width) * 1.25)
                      .clamp(_larguraMin, _larguraMax);
                  _altura = ((_altura ?? widget.height) * 1.25)
                      .clamp(_alturaMin, _alturaMax);
                });
                _salvar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.zoom_out),
              title: const Text('Diminuir painel'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _largura = ((_largura ?? widget.width) * 0.8)
                      .clamp(_larguraMin, _larguraMax);
                  _altura = ((_altura ?? widget.height) * 0.8)
                      .clamp(_alturaMin, _alturaMax);
                });
                _salvar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_with),
              title: const Text('Mostrar as alças de redimensionar'),
              subtitle: const Text('Arraste as alças dos cantos'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _mostrarAlcas = !_mostrarAlcas);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.redAccent),
              title: const Text('Ocultar painel'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _oculto = true);
                _salvar();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_carregado || _oculto) {
      return const SizedBox.shrink();
    }

    if (_minimizado) {
      final mq = MediaQuery.of(context).size;
      return Positioned(
        left: _ladoEsquerdo ? 2 : mq.width - 46,
        top: _offset.dy.clamp(0.0, mq.height - 60),
        child: GestureDetector(
          onTap: _alternarMinimizado,
          onLongPress: () => _menuDaTab(context),
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
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _ladoEsquerdo ? Icons.chevron_right : Icons.chevron_left,
                    size: 13,
                    color: overlayTextMuted(context),
                  ),
                  const SizedBox(width: 2),
                  widget.minimizedChild ??
                      const Icon(Icons.open_in_full, size: 18),
                ],
              ),
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
                    // O menu fica no puxador (e nao no painel inteiro) para
                    // nao competir com o arraste - era isso que travava o
                    // arrasto dos paineis.
                    onLongPress: () {
                      setState(() => _mostrarAlcas = true);
                      _menuDoPainel(context);
                    },
                    child: widget.handle!,
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: _largura ?? widget.width,
                    maxWidth: _largura ?? widget.width,
                    minHeight: 0,
                    maxHeight: _altura ?? double.infinity,
                  ),
                  child: widget.child,
                ),
              ],
            ),
          ),
          if (widget.resizable) ...[
            _alcaResize(0), // inferior direito
            _alcaResize(1), // inferior esquerdo
            _alcaResize(2), // superior direito
            _alcaResize(3), // superior esquerdo
          ],
        ],
      ),
    );
  }

  /// Alca de redimensionamento: escondida (o painel fica limpo). As alcas
  /// so aparecem quando o usuario pede pelo menu do toque longo.
  Widget _alcaResize(int lado) {
    final alinhamento = switch (lado) {
      0 => Alignment.bottomRight,
      1 => Alignment.bottomLeft,
      2 => Alignment.topRight,
      _ => Alignment.topLeft,
    };
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_mostrarAlcas,
        child: Align(
          alignment: alinhamento,
          child: GestureDetector(
            onPanUpdate: (d) => _redimensionar(d, lado: lado),
            onPanEnd: (_) => _salvar(),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.open_in_full,
                size: 12,
                color: overlayTextMuted(context).withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

