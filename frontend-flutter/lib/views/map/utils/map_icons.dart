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

  /// Marcador com foto do motorista: anel vermelho (motorista), turquesa
  /// (ajudante) e azul (eu). Ajudantes aparecem menores e mais translucidos.
  static Future<Uint8List> photoBadge(
    Uint8List? photo, {
    required bool helper,
    required bool mine,
    double size = 128,
    Color ring = const Color(0xFFD32F2F),
    Color? helperRing = const Color(0xFF26A69A),
  }) async {
    final key = 'photo_${helper ? 'h' : 'd'}_${mine ? 'me' : 'peer'}_'
        '${photo?.length ?? 0}_${photo == null ? 0 : photo[0]}';
    final cached = _cache[key];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final r = size / 2;
    final ringColor = helper ? (helperRing ?? ring) : ring;

    canvas.drawCircle(
      Offset(r, r),
      r - 3,
      Paint()..color = const Color(0xE6000000),
    );

    if (photo != null) {
      final image = await _decodeImage(photo);
      if (image != null) {
        final clip = Path()
          ..addOval(Rect.fromCircle(center: Offset(r, r), radius: r - 8));
        canvas.save();
        canvas.clipPath(clip);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromCircle(center: Offset(r, r), radius: r - 8),
          Paint()..filterQuality = FilterQuality.medium,
        );
        canvas.restore();
      }
    }

    canvas.drawCircle(
      Offset(r, r),
      r - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * (helper ? 0.05 : 0.075)
        ..color = ringColor,
    );

    if (helper) {
      final badge = Offset(r + r * 0.52, r + r * 0.52);
      canvas.drawCircle(
          badge, r * 0.3, Paint()..color = const Color(0xFF0A0A0A));
      canvas.drawCircle(
        badge,
        r * 0.3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.04
          ..color = ringColor,
      );
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        text: TextSpan(
          text: '🤝',
          style: TextStyle(fontSize: r * 0.34),
        ),
      )..layout();
      tp.paint(canvas, Offset(badge.dx - tp.width / 2, badge.dy - tp.height / 2));
    }

    _cache[key] = await _finish(recorder, size);
    return _cache[key]!;
  }

  static Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> peerBubble(String name,
      {double width = 260, double height = 76}) async {
    final key = 'peer_bubble_$name';
    final cached = _cache[key];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, width - 8, height - 26),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0xF21A1F26)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFF6D00),
    );

    final tail = Path()
      ..moveTo(width / 2 - 12, height - 24)
      ..lineTo(width / 2 + 12, height - 24)
      ..lineTo(width / 2, height - 4)
      ..close();
    canvas.drawPath(tail, Paint()..color = const Color(0xF21A1F26));
    canvas.drawPath(
      tail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFF6D00),
    );

    final label = name.trim().isEmpty ? 'Caminhão' : name.trim();
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFFF2F2F2),
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
      ),
    )..layout(maxWidth: width - 40);
    tp.paint(
        canvas, Offset((width - tp.width) / 2, (height - 26 - tp.height) / 2 + 4));

    _cache[key] = await _finishRect(recorder, width, height);
    return _cache[key]!;
  }

  static Future<Uint8List> _finishRect(
      ui.PictureRecorder recorder, double width, double height) async {
    final img = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
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
