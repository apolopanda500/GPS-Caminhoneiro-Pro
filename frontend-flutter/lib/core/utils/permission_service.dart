import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';

class PermissionService {
  static const String _pedirKey = 'permissoes_pedidas_v1';

  static Future<bool> _jaPediu() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pedirKey) == _pedirKey;
  }

  static Future<void> marcarPedidas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pedirKey, _pedirKey);
  }

  /// Mostra um dialog explicativo e, se o usuario aceitar,
  /// requisita Localizacao, Notificacoes, Fotos e Armazenamento (Android).
  /// Retorna true se Localizacao ficou concedida.
  static Future<bool> pedirComConfirmacao(BuildContext context) async {
    final rejeitarDepois = await _jaPediu();
    if (!context.mounted) return false;

    final aceitar = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: sheetBackground(context),
            title: const Text('Permissões necessárias',
                style: TextStyle(color: Colors.white)),
            content: const Text(
              'Para o GPS funcionar 100%:\n\n'
              '📍 Localização — rastrear rota e alertas por proximidade\n'
              '🔔 Notificações — avisos da estrada em tempo real\n'
              '🖼️ Fotos — importar sua foto de perfil no mapa\n\n'
              'Nada é compartilhado fora da rede do app.',
              style: TextStyle(color: kLightText, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Agora não'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('PERMITIR'),
              ),
            ],
          ),
        ) ??
        (!rejeitarDepois);

    var locationOk = await Permission.locationWhenInUse.status.isGranted ||
        await Permission.locationAlways.status.isGranted;

    if (aceitar) {
      locationOk = await Permission.locationWhenInUse.request().isGranted;
      if (!locationOk) {
        locationOk = await Permission.locationAlways.request().isGranted;
      } else if (await Permission.locationAlways.status.isDenied) {
        await Permission.locationAlways.request();
      }
      await Permission.notification.request();
      final fotos = await Permission.photos.request();
      var granted = fotos.isGranted;
      if (!granted && await Permission.storage.status.isDenied) {
        final storage = await Permission.storage.request();
        granted = storage.isGranted;
      }
      await marcarPedidas();
    }

    return locationOk;
  }
}
