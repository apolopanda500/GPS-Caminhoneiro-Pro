import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Mostra o FPS real medido pelo pipeline de render do Flutter.
/// Verde >= alvo, amarelo >= 45, vermelho abaixo.
class FpsOverlay extends StatefulWidget {
  final int targetFps;
  final bool compact;

  const FpsOverlay({super.key, this.targetFps = 60, this.compact = true});

  @override
  State<FpsOverlay> createState() => _FpsOverlayState();
}

class _FpsOverlayState extends State<FpsOverlay> {
  double _fps = 0;
  int _frames = 0;
  DateTime? _windowStart;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    _frames += timings.length;
    final now = DateTime.now();
    _windowStart ??= now;
    final elapsed = now.difference(_windowStart!).inMilliseconds;
    if (elapsed >= 500) {
      final fps = _frames * 1000 / elapsed;
      if (mounted) setState(() => _fps = fps);
      _frames = 0;
      _windowStart = now;
    }
  }

  Color get _color {
    if (_fps >= widget.targetFps - 3) return const Color(0xFF39FF14);
    if (_fps >= 45) return Colors.amber;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.speed, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            '${_fps.toStringAsFixed(0)} FPS',
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
