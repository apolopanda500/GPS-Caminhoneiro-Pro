import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:gps_camioneiro_pro/providers/settings_provider.dart';

/// Perfil real do aparelho (RAM, nucleos, taxa de atualizacao da tela).
///
/// Serve para o app usar o MAXIMO do que o celular aguenta quando o modo
/// economia de bateria esta desligado, e cair para o basico quando ligado.
class PerfilDoAparelho {
  const PerfilDoAparelho({
    required this.ramMb,
    required this.nucleos,
    required this.refreshHz,
    required this.lowRam,
    required this.modelo,
    required this.androide,
    required this.sdk,
  });

  final int ramMb;
  final int nucleos;
  final double refreshHz;
  final bool lowRam;
  final String modelo;
  final String androide;
  final int sdk;

  static const _canal = MethodChannel(
    'com.gpscamioneiro.gps_camioneiro_pro/nativo',
  );

  /// Detecta o aparelho. Se a leitura nativa falhar, usa o que o Dart sabe.
  static Future<PerfilDoAparelho> detectar() async {
    var ramMb = 0;
    var nucleos = Platform.numberOfProcessors;
    var refreshHz = 60.0;
    var lowRam = false;
    var modelo = Platform.operatingSystem;
    var androide = '';
    var sdk = 0;
    try {
      final info = await _canal.invokeMapMethod<String, dynamic>('aparelho/info');
      if (info != null) {
        ramMb = (info['ramMb'] as num?)?.toInt() ?? 0;
        nucleos = (info['nucleos'] as num?)?.toInt() ?? nucleos;
        refreshHz = (info['refreshHz'] as num?)?.toDouble() ?? refreshHz;
        lowRam = info['lowRam'] as bool? ?? false;
        modelo = info['modelo']?.toString() ?? modelo;
        androide = info['androide']?.toString() ?? '';
        sdk = (info['sdk'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('PerfilDoAparelho: leitura nativa falhou ($e)');
    }
    if (refreshHz <= 0) refreshHz = 60;
    return PerfilDoAparelho(
      ramMb: ramMb,
      nucleos: nucleos,
      refreshHz: refreshHz,
      lowRam: lowRam,
      modelo: modelo,
      androide: androide,
      sdk: sdk,
    );
  }

  /// FPS que a tela do aparelho realmente entrega (30, 60 ou 120).
  int get fpsMaximo {
    if (refreshHz >= 110) return 120;
    if (refreshHz >= 50) return 60;
    return 30;
  }

  /// Qualidade grafica maxima que este aparelho aguenta com folga.
  RenderQuality get qualidadeSugerida {
    if (lowRam) return RenderQuality.economy;
    final potente = ramMb >= 5500 && nucleos >= 8;
    if (potente && refreshHz >= 90) return RenderQuality.ultra;
    if (ramMb == 0 || ramMb >= 3500) return RenderQuality.balanced;
    return RenderQuality.economy;
  }

  String get resumo {
    final memoria = ramMb > 0 ? '$ramMb MB' : 'RAM ?';
    final hz = refreshHz.toStringAsFixed(0);
    return '$modelo | $nucleos nucleos | $memoria | ${hz}Hz'
        '${lowRam ? ' | low-RAM' : ''}';
  }
}
