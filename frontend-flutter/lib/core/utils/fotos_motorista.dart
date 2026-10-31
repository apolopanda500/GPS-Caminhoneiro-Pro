import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Utilitario de foto do motorista.
///
/// O banco guarda a foto como **data URL** (base64) e a rede tambem pode
/// mandar data URL. Antes, o app so sabia ler http(s) - por isso todo
/// caminhoneiro aparecia com o icone padrao (foto "igual" para todos).
class FotosMotorista {
  const FotosMotorista._();

  static bool _vazia(String url) =>
      url.isEmpty || url.startsWith('https://placehold.co');

  /// Cache dos bytes ja decodificados (foto grande nao pode ser decodificada
  /// a cada frame: era isso que fazia a foto piscar).
  static final Map<String, Uint8List?> _cache = {};

  /// Bytes da foto (data URL decodificado ou http baixado).
  static Uint8List? bytes(String url) {
    if (_vazia(url)) return null;
    if (!url.startsWith('data:')) return null;
    if (_cache.containsKey(url)) return _cache[url];
    final partes = url.split(',');
    if (partes.length < 2) return null;
    try {
      final dados = base64Decode(partes[1]);
      if (_cache.length > 8) _cache.remove(_cache.keys.first);
      _cache[url] = dados;
      return dados;
    } catch (_) {
      return null;
    }
  }

  /// Imagem paraavatar/badges: data URL vira MemoryImage, http vira NetworkImage.
  static ImageProvider? provider(String url) {
    if (_vazia(url)) return null;
    if (url.startsWith('data:')) {
      final b = bytes(url);
      return b == null ? null : MemoryImage(b);
    }
    return NetworkImage(url);
  }

  /// Widget de imagem que aceita data URL e http (com fallback).
  static Widget imagem(
    String url, {
    BoxFit fit = BoxFit.cover,
    Widget fallback = const SizedBox.shrink(),
  }) {
    final p = provider(url);
    if (p == null) return fallback;
    return Image(
      key: ValueKey(url),
      image: p,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
