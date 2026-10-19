import 'package:flutter/services.dart';

class AlertNotifier {
  // ALARME DE RADAR: Vibração intermitente curta para chamar a atenção para a velocidade
  static void triggerRadarWarning() {
    // Padrão de vibração: Espera 0ms, vibra 100ms, espera 200ms, vibra 100ms
    HapticFeedback.vibrate();
    Future.delayed(const Duration(milliseconds: 300), () {
      HapticFeedback.vibrate();
    });

    // Comando nativo para tocar o bipe de velocidade do sistema Android
    SystemSound.play(SystemSoundType.click);
  }

  // ALARME CRÍTICO (Ponte Baixa / Fio Caído / Rua Proibida): Vibração pesada contínua
  static void triggerCriticalDangerAlarm() {
    // Faz o celular tremer de forma violenta para o motorista frear o caminhão imediatamente
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.heavyImpact());
    Future.delayed(const Duration(milliseconds: 400), () => HapticFeedback.heavyImpact());
    Future.delayed(const Duration(milliseconds: 600), () => HapticFeedback.heavyImpact());

    // Aqui integra o alerta de áudio por voz text-to-speech da IA Edge local
  }

  // ALARME DE PEDÁGIO: Vibração única média
  static void triggerTollAlert() {
    HapticFeedback.mediumImpact();
  }
}