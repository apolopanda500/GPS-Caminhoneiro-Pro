import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audios do app', () {
    test('musica de entrada, sino da parada e tema existem', () {
      final entrada = File('assets/audio/musica_custom.mp3');
      final sino = File('assets/audio/estacao.wav');
      final tema = File('assets/audio/tema_loop.wav');

      expect(entrada.existsSync(), isTrue,
          reason: 'musica de entrada (assets/audio/musica_custom.mp3)');
      expect(sino.existsSync(), isTrue,
          reason: 'sino da estacao (assets/audio/estacao.wav)');
      expect(tema.existsSync(), isTrue,
          reason: 'tema em loop (assets/audio/tema_loop.wav)');

      expect(entrada.lengthSync(), greaterThan(100000));
      expect(sino.lengthSync(), greaterThan(1000));
    });

    test('a musica de entrada e um MP3 valido (ID3)', () {
      final bytes = File('assets/audio/musica_custom.mp3').readAsBytesSync();
      final cabecalho = String.fromCharCodes(bytes.take(3));
      expect(cabecalho, 'ID3', reason: 'o arquivo deve ser um MP3 com tag ID3');
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
