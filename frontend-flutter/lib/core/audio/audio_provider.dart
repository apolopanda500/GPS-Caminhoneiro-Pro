import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EstacaoRadio {
  final String nome;
  final String url;
  EstacaoRadio({required this.nome, required this.url});

  factory EstacaoRadio.fromJson(Map<String, dynamic> j) => EstacaoRadio(
        nome: (j['name'] ?? 'Estação').toString(),
        url: (j['url'] ?? '').toString(),
      );

  Map<String, dynamic> toMap() => {'nome': nome, 'url': url};
}

class AudioProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _radio = AudioPlayer();

  bool musicaLigada = false;
  bool estacaoLigada = true;
  bool radioTocando = false;
  String radioEstacao = '';
  double _volume = 1.0;
  bool _carregando = false;
  List<EstacaoRadio> _estacoes = [];

  List<EstacaoRadio> get estacoes => List.unmodifiable(_estacoes);
  bool get carregandoEstacoes => _carregando;
  double get volume => _volume;
  bool get radioAtivo => radioTocando;

  Future<void> carregarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    musicaLigada = prefs.getBool('audio_musica') ?? true;
    estacaoLigada = prefs.getBool('audio_estacao') ?? true;
    if (musicaLigada) await tocarMusica();
    notifyListeners();
  }

  Future<void> alternarMusica(bool ligar) async {
    musicaLigada = ligar;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_musica', ligar);
    if (ligar) {
      await tocarMusica();
    } else {
      await _player.stop();
    }
    notifyListeners();
  }

  Future<void> tocarMusica() async {
    try {
      try {
        await _player.setAsset('assets/audio/musica_custom.mp3');
      } catch (_) {
        try {
          await _player.setAsset('assets/audio/tema_loop.wav');
        } catch (_) {
          return;
        }
      }
      await _player.setVolume(0.55);
      await _player.setLoopMode(LoopMode.one);
      await _player.play();
    } catch (_) {}
  }

  /// Som de chegada (sino de estacao) na parada.
  /// Se o radio estiver tocando, abaixa o volume (duck), toca o sino
  /// e devolve o volume do radio em seguida.
  Future<void> tocarChegada() async {
    if (!estacaoLigada) return;
    final salvarVolume = _radio.volume;
    final radioAtivo = radioTocando;
    try {
      if (radioAtivo) await _radio.setVolume(0.2);
    } catch (_) {}
    final p = AudioPlayer();
    try {
      try {
        await p.setAsset('assets/audio/estacao_custom.wav');
      } catch (_) {
        await p.setAsset('assets/audio/estacao.wav');
      }
      await p.setVolume(0.9);
      await p.play();
      await p.playerStateStream
          .firstWhere((s) => s.processingState == ProcessingState.completed)
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
    await p.dispose();
    if (radioAtivo) {
      try {
        await _radio.setVolume(salvarVolume <= 0 ? 1.0 : salvarVolume);
      } catch (_) {}
    }
  }

  Future<void> alternarEstacao(bool ligar) async {
    estacaoLigada = ligar;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_estacao', ligar);
    notifyListeners();
  }

  Future<bool> buscarEstacoes([String? nome]) async {
    _carregando = true;
    notifyListeners();
    try {
      final q = Uri.encodeQueryComponent(nome ?? '');
      final resp = await http.get(
        Uri.parse(
            'https://de1.api.radio-browser.info/json/stations/search?countrycode=BR&limit=30&hidebroken=true&order=votes&name=$q'),
        headers: {'User-Agent': 'GPS-Caminhoneiro-Pro/1.0'},
      );
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        _estacoes = list
            .map((e) => EstacaoRadio.fromJson(e as Map<String, dynamic>))
            .where((e) => e.url.isNotEmpty && e.url.startsWith('http'))
            .toList();
      }
    } catch (_) {}
    _carregando = false;
    notifyListeners();
    return _estacoes.isNotEmpty;
  }

  Future<void> tocarEstacao(EstacaoRadio e) async {
    try {
      await _player.stop();
      await _radio.setUrl(e.url);
      await _radio.setVolume(_volume);
      await _radio.play();
      radioTocando = true;
      radioEstacao = e.nome;
      notifyListeners();
    } catch (_) {
      radioTocando = false;
      radioEstacao = '';
      notifyListeners();
    }
  }

  /// Volume do radio (0 a 1).
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    try {
      await _radio.setVolume(_volume);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> pararRadio() async {    await _radio.stop();
    await _radio.setVolume(_volume);
    radioTocando = false;
    radioEstacao = '';
    if (musicaLigada) await tocarMusica();
    notifyListeners();
  }

  Future<void> pararTudo() async {
    await _player.stop();
    await _radio.stop();
    radioTocando = false;
    radioEstacao = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    _radio.dispose();
    super.dispose();
  }
}
