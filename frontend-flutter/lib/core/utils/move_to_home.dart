import 'dart:io';
import 'package:flutter/services.dart';

/// Minimiza o app (envia para a home) quando apertado o botao Voltar do Android,
/// em vez de fechar o app. No iOS/web nao faz nada.
Future<void> minimizarApp() async {
  if (!Platform.isAndroid) return;
  try {
    const channel = MethodChannel('gps.camioneiro.pro/move_to_home');
    await channel.invokeMethod('move/task/to/back');
  } catch (_) {}
}
