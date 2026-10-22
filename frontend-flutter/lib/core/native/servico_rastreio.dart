import 'dart:async';

import 'package:flutter/services.dart';

/// Ponte com o Android para o servico em primeiro plano.
///
/// Enquanto o servico estiver ligado, o Android mantem o processo vivo
/// mesmo com a tela apagada ou o app em segundo plano: e a mesma tecnologia
/// que faz o YouTube Premium continuar tocando com o app fechado.
///
/// O GPS e o socket continuam sendo cuidados pelo Flutter; o servico so
/// segura o processo e mostra a notificacao permanente exigida pelo sistema.
class ServicoRastreio {
  ServicoRastreio._();
  static final ServicoRastreio instancia = ServicoRastreio._();

  static const MethodChannel _canal =
      MethodChannel('com.gpscamioneiro.gps_camioneiro_pro/nativo');

  bool _ligado = false;
  bool get ligado => _ligado;

  /// Liga o rastreio em segundo plano.
  Future<bool> iniciar(
      {String titulo = 'GPS Caminhoneiro Pro',
      String texto = 'Rastreando sua viagem'}) async {
    try {
      await _canal.invokeMethod<bool>('servico/iniciar', {
        'titulo': titulo,
        'texto': texto,
      });
      _ligado = true;
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Desliga o rastreio em segundo plano.
  Future<bool> parar() async {
    try {
      await _canal.invokeMethod<bool>('servico/parar');
      _ligado = false;
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// O servico esta rodando agora?
  Future<bool> ativo() async {
    try {
      final r = await _canal.invokeMethod<bool>('servico/ativo');
      _ligado = r ?? false;
      return _ligado;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// True quando o app esta na mini janela (Picture-in-Picture).
  bool get emPip => _emPip;
  bool _emPip = false;

  /// Notifica quando o Android entra ou sai da mini janela.
  void onPipChanged(void Function(bool emPip) callback) {
    _canal.setMethodCallHandler((call) async {
      if (call.method == 'pip/estado') {
        _emPip = call.arguments == true;
        callback(_emPip);
      }
    });
  }

  /// O aparelho suporta mini janela?
  Future<bool> pipPermitido() async {
    try {
      final r = await _canal.invokeMethod<bool>('pip/permitido');
      return r ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Coloca o app na mini janela flutuante (Picture-in-Picture).
  Future<bool> entrarNoPip() async {
    try {
      final r = await _canal.invokeMethod<bool>('pip/entrar');
      return r ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Mantem a tela acesa durante a viagem (sem travar a tela do celular).
  Future<bool> manterTelaLigada(bool ligada) async {
    try {
      await _canal.invokeMethod<bool>('tela/ligar', {'ligada': ligada});
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Abre a tela do Android para o usuario tirar o app do "economizador de
  /// bateria". Sem isso o Android mata o app em segundo plano.
  Future<bool> pedirIsencaoDeBateria() async {
    try {
      final r = await _canal.invokeMethod<bool>('energia/otimizacao');
      return r ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
