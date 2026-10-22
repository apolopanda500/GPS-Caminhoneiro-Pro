import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'radio_models.dart';
import 'radio_service.dart';

export 'radio_models.dart';
export 'radio_service.dart';

class AudioProvider extends ChangeNotifier {
  AudioProvider({RadioService? servico}) : _servico = servico ?? RadioService();

  final RadioService _servico;
  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _radio = AudioPlayer();

  bool musicaLigada = false;
  bool estacaoLigada = true;
  bool radioTocando = false;
  String radioEstacao = '';
  double _volume = 1.0;
  bool _carregando = false;
  String _erro = '';
  List<EstacaoRadio> _estacoes = [];
  List<String> _tags = [];
  List<EstacaoRadio> _favoritos = [];
  List<EstacaoRadio> _recentes = [];
  OrdenacaoRadio _ordenacao = OrdenacaoRadio.popular;
  FiltroRadio _filtro = FiltroRadio.todas;
  String _tagSelecionada = '';

  List<EstacaoRadio> get estacoes => List.unmodifiable(_estacoes);
  List<String> get tags => List.unmodifiable(_tags);
  List<EstacaoRadio> get favoritos => List.unmodifiable(_favoritos);
  List<EstacaoRadio> get recentes => List.unmodifiable(_recentes);
  bool get carregandoEstacoes => _carregando;
  String get erroRadio => _erro;
  double get volume => _volume;
  bool get radioAtivo => radioTocando;
  OrdenacaoRadio get ordenacao => _ordenacao;
  FiltroRadio get filtro => _filtro;
  String get tagSelecionada => _tagSelecionada;

  /// Estacao atualmente em reproducao (objeto completo), se houver.
  EstacaoRadio? get estacaoAtual {
    if (!radioTocando) return null;
    for (final e in [..._recentes, ..._favoritos, ..._estacoes]) {
      if (e.nome == radioEstacao) return e;
    }
    return null;
  }

  bool ehFavorita(EstacaoRadio e) =>
      _favoritos.any((f) => f.chave == e.chave);

  /// Carrega apenas favoritos e recentes, sem tocar audio.
  /// Usado em testes, onde o plugin de audio nao esta disponivel.
  Future<void> carregarFavoritosERecentes() async {
    await _carregarFavoritos();
    await _carregarRecentes();
  }

  Future<void> carregarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    musicaLigada = prefs.getBool('audio_musica') ?? true;
    estacaoLigada = prefs.getBool('audio_estacao') ?? true;
    await carregarFavoritosERecentes();
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

  /// Abaixa o radio (duck) enquanto a voz fala.
  Future<void> abaixarRadio() async {
    try {
      if (radioTocando) await _radio.setVolume(0.15);
    } catch (_) {}
  }

  /// Devolve o volume do radio depois da voz.
  Future<void> restaurarRadio() async {
    try {
      if (radioTocando) await _radio.setVolume(_volume);
    } catch (_) {}
  }

  /// Para a musica de entrada (usada so no splash e na tela de login).
  Future<void> pararMusica() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// Callback que toca o som personalizado de entrada, quando houver.
  /// Retorna true se tocou (evitando o sino padrao).
  /// Definido em `main.dart` para amarrar os dois providers.
  Future<bool> Function()? tocadorEntrada;

  /// Som de chegada (sino de estacao) na parada.
  /// Se o radio estiver tocando, abaixa o volume (duck), toca o sino
  /// e devolve o volume do radio em seguida.
  Future<void> tocarChegada() async {
    if (!estacaoLigada) return;
    final personalizado = tocadorEntrada;
    if (personalizado != null) {
      final tocou = await personalizado();
      if (tocou) return;
    }
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
  /// Carrega as estacoes do Brasil com os filtros/ordenacao atuais.
  ///
  /// Retorna true quando a lista foi preenchida com sucesso.
  Future<bool> buscarEstacoes([String? nome]) async {
    _carregando = true;
    _erro = '';
    notifyListeners();
    try {
      final lista = await _servico.buscar(
        nome: nome ?? '',
        tag: _tagSelecionada,
        ordenacao: _ordenacao,
        limite: 60,
      );
      _estacoes = lista;
      if (_tags.isEmpty) {
        _tags = await _servico.tagsBrasil();
      }
      return _estacoes.isNotEmpty;
    } on RadioException catch (e) {
      _erro = e.mensagem;
      return false;
    } catch (_) {
      _erro = 'Falha ao carregar as estacoes de radio.';
      return false;
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Busca as estacoes mais clicadas do Brasil (lista inicial).
  Future<bool> carregarPopulares() async {
    _carregando = true;
    _erro = '';
    notifyListeners();
    try {
      _estacoes = await _servico.maisClicadas(limite: 60);
      if (_tags.isEmpty) {
        _tags = await _servico.tagsBrasil();
      }
      return _estacoes.isNotEmpty;
    } on RadioException catch (e) {
      _erro = e.mensagem;
      return false;
    } catch (_) {
      _erro = 'Falha ao carregar as estacoes de radio.';
      return false;
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Troca a ordenacao e recarrega a lista.
  Future<void> setOrdenacao(OrdenacaoRadio ordenacao) async {
    if (_ordenacao == ordenacao) return;
    _ordenacao = ordenacao;
    notifyListeners();
    await carregarPopulares();
  }

  /// Seleciona uma tag e recarrega a lista.
  Future<void> setTag(String tag) async {
    _tagSelecionada = _tagSelecionada == tag ? '' : tag;
    _filtro = _tagSelecionada.isEmpty ? FiltroRadio.todas : FiltroRadio.tags;
    notifyListeners();
    await carregarPopulares();
  }

  /// Define o filtro principal da lista.
  Future<void> setFiltro(FiltroRadio filtro) async {
    _filtro = filtro;
    notifyListeners();
    if (filtro == FiltroRadio.populares || filtro == FiltroRadio.tags) {
      await carregarPopulares();
    }
  }

  /// Toca a estacao informada, salvando-a na lista de recentes.
  Future<bool> tocarEstacao(EstacaoRadio e) async {
    try {
      await _player.stop();
      await _radio.setUrl(e.url);
      await _radio.setVolume(_volume);
      await _radio.play();
      radioTocando = true;
      radioEstacao = e.nome;
      await _registrarRecente(e);
      unawaited(_servico.reportarClique(e));
      notifyListeners();
      return true;
    } catch (_) {
      radioTocando = false;
      radioEstacao = '';
      _erro = 'Nao foi possivel tocar esta estacao.';
      notifyListeners();
      return false;
    }
  }

  /// Lista de rejeicao (favoritos + recentes + estacoes) do tocador.
  List<EstacaoRadio> get filaDoTocador {
    final lista = <EstacaoRadio>[];
    final vistos = <String>{};
    for (final e in [..._recentes, ..._favoritos, ..._estacoes]) {
      if (vistos.add(e.nome)) lista.add(e);
    }
    return lista;
  }

  /// Proxima estacao da fila (estilo tocador de musica).
  Future<void> proximaEstacao() async {
    final fila = filaDoTocador;
    if (fila.isEmpty) return;
    final atual = fila.indexWhere((e) => e.nome == radioEstacao);
    final proxima = fila[(atual + 1) % fila.length];
    await tocarEstacao(proxima);
  }

  /// Estacao anterior da fila.
  Future<void> anteriorEstacao() async {
    final fila = filaDoTocador;
    if (fila.isEmpty) return;
    final atual = fila.indexWhere((e) => e.nome == radioEstacao);
    final anterior = fila[(atual - 1 + fila.length) % fila.length];
    await tocarEstacao(anterior);
  }

  /// Pausa ou retoma a reproducao atual.
  Future<void> alternarReproducao() async {    if (!radioTocando) return;
    try {
      if (_radio.playing) {
        await _radio.pause();
        radioTocando = false;
      } else {
        await _radio.play();
        radioTocando = true;
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Alterna a estacao entre favorita e normal.
  Future<void> _registrarRecente(EstacaoRadio e) async {
    _recentes.removeWhere((r) => r.chave == e.chave);
    _recentes.insert(0, e);
    if (_recentes.length > 30) _recentes.removeLast();
    await _salvarRecentes();
  }

  Future<void> _carregarFavoritos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bruto = prefs.getString('radio.favoritos');
      if (bruto == null || bruto.isEmpty) return;
      _favoritos = _decodificar(bruto);
    } catch (_) {}
  }

  Future<void> _salvarFavoritos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('radio.favoritos', _codificar(_favoritos));
    } catch (_) {}
  }

  Future<void> _carregarRecentes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bruto = prefs.getString('radio.recentes');
      if (bruto == null || bruto.isEmpty) return;
      _recentes = _decodificar(bruto);
    } catch (_) {}
  }

  Future<void> _salvarRecentes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('radio.recentes', _codificar(_recentes));
    } catch (_) {}
  }

  String _codificar(List<EstacaoRadio> lista) =>
      lista.map((e) => '${e.chave}\u001f${e.nome}\u001f${e.url}').join('\u001e');

  List<EstacaoRadio> _decodificar(String bruto) {
    final resultado = <EstacaoRadio>[];
    for (final linha in bruto.split('\u001e')) {
      if (linha.isEmpty) continue;
      final partes = linha.split('\u001f');
      if (partes.length < 3) continue;
      resultado.add(EstacaoRadio(
        nome: partes[1],
        url: partes[2],
        uuid: partes[0],
      ));
    }
    return resultado;
  }

  Future<void> alternarFavorita(EstacaoRadio e) async {
    final existe = _favoritos.any((f) => f.chave == e.chave);
    if (existe) {
      _favoritos.removeWhere((f) => f.chave == e.chave);
    } else {
      _favoritos.insert(0, e);
      if (_favoritos.length > 60) _favoritos.removeLast();
    }
    await _salvarFavoritos();
    notifyListeners();
  }

  /// Volume do radio (0 a 1).
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    try {
      await _radio.setVolume(_volume);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> pararRadio() async {
    await _radio.stop();
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
    _servico.dispose();
    super.dispose();
  }
}

