import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final FlutterTts _tts = FlutterTts();
  bool _iniciado = false;
  bool ligada = true;

  Future<void> carregarPreferencia() async {
    final prefs = await SharedPreferences.getInstance();
    ligada = prefs.getBool('audio_voz') ?? true;
  }

  Future<void> alternar(bool ativar) async {
    ligada = ativar;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_voz', ativar);
    if (!ativar) {
      try {
        await _tts.stop();
      } catch (_) {}
    }
  }

  Future<void> _garantir() async {
    if (_iniciado) return;
    try {
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _iniciado = true;
    } catch (_) {}
  }

  Future<void> falar(String texto) async {
    if (!ligada) return;
    await _garantir();
    if (!_iniciado) return;
    try {
      await _tts.speak(texto);
    } catch (_) {}
  }

  /// "Chegou no ponto 1... chegou no ponto 2..." ate o ultimo cliente.
  Future<void> chegadaNaParada(int numero, int total, {String? proxima}) async {
    final buf = StringBuffer();
    if (numero >= total) {
      buf.write('Rota concluída. Volte para a empresa.');
    } else {
      buf.write(
          'Chegou no ponto $numero de $total. ${proxima ?? 'A próxima parada está esperando por você.'}');
    }
    await falar(buf.toString());
  }

  Future<void> viagemConcluida() async {
    await falar('Viagem concluída. Bom trabalho, caminhoneiro!');
  }
}
