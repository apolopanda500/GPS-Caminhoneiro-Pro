import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audios do app', () {
    test('tema de entrada original e sino existem (so sons embutidos)', () {
      final entrada = File('assets/audio/tema_entrada.wav');
      final sino = File('assets/audio/estacao.wav');

      expect(entrada.existsSync(), isTrue,
          reason: 'tema de entrada (assets/audio/tema_entrada.wav)');
      expect(sino.existsSync(), isTrue,
          reason: 'sino da estacao (assets/audio/estacao.wav)');

      expect(entrada.lengthSync(), greaterThan(100000));
      expect(sino.lengthSync(), greaterThan(1000));
    });

    test('nao existe som importado do celular no APK', () {
      expect(File('assets/audio/musica_custom.mp3').existsSync(), isFalse);
      expect(File('assets/audio/tema_loop.wav').existsSync(), isFalse);
    });

    test('o tema de entrada e um WAV valido', () {
      final bytes = File('assets/audio/tema_entrada.wav').readAsBytesSync();
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
      expect(String.fromCharCodes(bytes.skip(8).take(4)), 'WAVE');
    });

    test('o provider de audio tem o sino e a musica de entrada', () {
      final audio = AudioProvider();
      // Sem o plugin de audio no teste, as chamadas nao podem estourar.
      expect(audio.tocarChegada, isA<Function>());
      expect(audio.tocarMusica, isA<Function>());
      expect(audio.volume, 1.0);
      expect(audio.radioTocando, isFalse);
    });
  });
}
