import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Gera imagens (PNG) para usar como marcadores do MapLibre.
/// O MapLibre nao renderiza widgets Flutter nem emoji em texto confiavelmente,
/// por isso desenhamos o marcador em um canvas e enviamos como imagem.
class MapIcons {
  static final Map<String, Uint8List> _cache = {};

  static Future<Uint8List> emojiBadge(String emoji, {double size = 96}) async {
    final key = 'emoji_$emoji';
    final cached = _cache[key];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final r = size / 2;

    canvas.drawCircle(
        Offset(r, r), r - 3, Paint()..color = const Color(0xCC000000));
    canvas.drawCircle(
      Offset(r, r),
      r - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.05
        ..color = const Color(0xFFD32F2F),
    );

    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      text: TextSpan(text: emoji, style: TextStyle(fontSize: size * 0.5)),
    )..layout();
    tp.paint(canvas, Offset(r - tp.width / 2, r - tp.height / 2));

    _cache[key] = await _finish(recorder, size);
    return _cache[key]!;
  }

  static Future<Uint8List> waypointBadge(
    int number, {
    double size = 96,
    Color color = const Color(0xFFD32F2F),
  }) async {
    final key = 'wp_${color.toARGB32()}_$number';
    final cached = _cache[key];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final r = size / 2;

    canvas.drawCircle(
        Offset(r, r), (r - 3) * 1.15, Paint()..color = const Color(0xAA000000));
    canvas.drawCircle(Offset(r, r), r - 3, Paint()..color = color);
    canvas.drawCircle(
      Offset(r, r),
      r - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.05
        ..color = Colors.white,
    );

    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      text: TextSpan(
        text: '$number',
        style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.45,
            fontWeight: FontWeight.bold),
      ),
    )..layout();
    tp.paint(canvas, Offset(r - tp.width / 2, r - tp.height / 2));

    _cache[key] = await _finish(recorder, size);
    return _cache[key]!;
  }

  static Future<Uint8List> truckIcon(String emoji,
      {double size = 96, bool mine = false}) async {
    final key = 'truck_${mine ? 'me' : 'peer'}_$emoji';
    final cached = _cache[key];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final r = size / 2;

    canvas.drawCircle(
        Offset(r, r), r - 3, Paint()..color = const Color(0xE6000000));
    canvas.drawCircle(
      Offset(r, r),
      r - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.06
        ..color = mine ? const Color(0xFF2196F3) : const Color(0xFFD32F2F),
    );

    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      text: TextSpan(text: emoji, style: TextStyle(fontSize: size * 0.5)),
    )..layout();
    tp.paint(canvas, Offset(r - tp.width / 2, r - tp.height / 2));

    _cache[key] = await _finish(recorder, size);
    return _cache[key]!;
  }

  static Future<Uint8List> truck({double size = 96}) async {
    final cached = _cache['truck'];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final r = size / 2;

    canvas.drawCircle(
        Offset(r, r), r - 3, Paint()..color = const Color(0xCC000000));
    canvas.drawCircle(
      Offset(r, r),
      r - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.05
        ..color = const Color(0xFFD32F2F),
    );
    _drawIcon(
        canvas, Icons.local_shipping, Icons.local_shipping.codePoint, size, r,
        color: const Color(0xFFFF5252));

    _cache['truck'] = await _finish(recorder, size);
    return _cache['truck']!;
  }

  static Future<Uint8List> alert({double size = 96}) async {
    final cached = _cache['alert'];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final r = size / 2;

    canvas.drawCircle(
        Offset(r, r), r - 3, Paint()..color = const Color(0xCC000000));
    canvas.drawCircle(
      Offset(r, r),
      r - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.05
        ..color = const Color(0xFFFF9800),
    );
    _drawIcon(canvas, Icons.warning_amber_rounded,
        Icons.warning_amber_rounded.codePoint, size, r,
        color: const Color(0xFFFFB74D));

    _cache['alert'] = await _finish(recorder, size);
    return _cache['alert']!;
  }

  static Future<Uint8List> me({double size = 96}) async {
    final cached = _cache['me'];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final r = size / 2;

    canvas.drawCircle(
        Offset(r, r), r - 2, Paint()..color = const Color(0x552196F3));
    canvas.drawCircle(
        Offset(r, r), r * 0.5, Paint()..color = const Color(0xFF2196F3));
    canvas.drawCircle(
      Offset(r, r),
      r * 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.05
        ..color = Colors.white,
    );

    _cache['me'] = await _finish(recorder, size);
    return _cache['me']!;
  }

  static void _drawIcon(
      Canvas canvas, IconData icon, int codePoint, double size, double r,
      {required Color color}) {
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      text: TextSpan(
        text: String.fromCharCode(codePoint),
        style: TextStyle(
          fontSize: size * 0.5,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
    )..layout();
    tp.paint(canvas, Offset(r - tp.width / 2, r - tp.height / 2));
  }

  static Future<Uint8List> _finish(
      ui.PictureRecorder recorder, double size) async {
    final img =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}
