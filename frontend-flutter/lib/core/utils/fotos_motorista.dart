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

  /// Bytes da foto (data URL decodificado ou http baixado).
  static Uint8List? bytes(String url) {
    if (_vazia(url)) return null;
    if (url.startsWith('data:')) {
      final partes = url.split(',');
      if (partes.length < 2) return null;
      try {
        return base64Decode(partes[1]);
      } catch (_) {
        return null;
      }
    }
    return null;
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
      image: p,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
