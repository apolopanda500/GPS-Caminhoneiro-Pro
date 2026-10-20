import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Momentos do app em que um som personalizado pode ser disparado.
enum SlotSom {
  inicioApp('Inicio do app', 'Toca assim que o app abre'),
  entradaParada('Entrada na parada', 'Dispara ao chegar em uma entrega'),
  alertaRadar('Alerta de radar', 'Toca quando o radar esta proximo'),
  avisoGeral('Aviso geral', 'Som de aviso do app');

  const SlotSom(this.titulo, this.descricao);

  final String titulo;
  final String descricao;

  String get chave => name;

  static SlotSom? porChave(String chave) {
    for (final s in SlotSom.values) {
      if (s.chave == chave) return s;
    }
    return null;
  }
}

/// Som que o motorista escolheu para um [SlotSom].
class SomPersonalizado {
  final SlotSom slot;
  final String nome;
  final String caminho;

  const SomPersonalizado({
    required this.slot,
    required this.nome,
    required this.caminho,
  });
}

/// Guarda os sons personalizados que o motorista importou do aparelho.
///
/// Os arquivos sao copiados para a pasta privada do app, para que continuem
/// disponiveis mesmo que o usuario apague o original da midia.
class SonsProvider extends ChangeNotifier {
  static const _chavePref = 'sons.customizados';
  static const _extensoes = ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac'];

  final Map<SlotSom, SomPersonalizado> _sons = {};
  final AudioPlayer _player = AudioPlayer();

  Map<SlotSom, SomPersonalizado> get sons => Map.unmodifiable(_sons);

  bool temSom(SlotSom slot) => _sons.containsKey(slot);

  SomPersonalizado? som(SlotSom slot) => _sons[slot];

  /// Carrega os sons gravados e toca o som de inicio do app, se existir.
  ///
  /// [tocarInicio] pode ser desativado em testes, onde o plugin de audio
  /// nao esta disponivel.
  Future<void> carregar({bool tocarInicio = true}) async {
    await _restaurar();
    if (tocarInicio && _sons.containsKey(SlotSom.inicioApp)) {
      await tocar(SlotSom.inicioApp);
    }
  }

  Future<void> _restaurar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bruto = prefs.getString(_chavePref);
      if (bruto == null || bruto.isEmpty) return;
      for (final item in _decodificar(bruto)) {
        if (await File(item.caminho).exists()) {
          _sons[item.slot] = item;
        }
      }
    } catch (_) {}
  }

  /// Abre o seletor de arquivos e importa o som escolhido para [slot].
  /// Retorna true se um arquivo foi importado.
  Future<bool> importar(SlotSom slot) async {
    try {
      final arquivos = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _extensoes,
      );
      if (arquivos.isEmpty) return false;
      final arquivo = arquivos.first;
      if (arquivo.path == null) return false;

      final destino = await _copiarParaApp(arquivo.path!, arquivo.name);
      final anterior = _sons[slot];
      _sons[slot] = SomPersonalizado(
        slot: slot,
        nome: arquivo.name,
        caminho: destino,
      );
      if (anterior != null) await _apagarArquivo(anterior.caminho);
      await _salvar();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Copia o arquivo para a pasta de sons do app.
  Future<String> _copiarParaApp(String origem, String nomeArquivo) async {
    final dir = await getApplicationDocumentsDirectory();
    final pasta = Directory('${dir.path}/sons');
    if (!await pasta.exists()) {
      await pasta.create(recursive: true);
    }
    final seguro =
        nomeArquivo.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final destino =
        '${pasta.path}/${DateTime.now().millisecondsSinceEpoch}_$seguro';
    await File(origem).copy(destino);
    return destino;
  }

  /// Remove o som do slot e apaga o arquivo do app.
  Future<void> remover(SlotSom slot) async {
    final alvo = _sons.remove(slot);
    if (alvo == null) return;
    await _apagarArquivo(alvo.caminho);
    await _salvar();
    notifyListeners();
  }

  Future<void> _apagarArquivo(String caminho) async {
    try {
      final f = File(caminho);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Toca o som do slot. Retorna false se nao houver som ou der erro.
  Future<bool> tocar(SlotSom slot) async {
    final alvo = _sons[slot];
    if (alvo == null) return false;
    try {
      await _player.stop();
      await _player.setFilePath(alvo.caminho);
      await _player.setVolume(0.9);
      await _player.play();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _salvar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lista = _sons.values
          .map((s) => '${s.slot.chave}\u001f${s.nome}\u001f${s.caminho}')
          .toList();
      await prefs.setString(_chavePref, lista.join('\u001e'));
    } catch (_) {}
  }

  /// Formato: slot\u001fname\u001fcaminho, com registros separados por \u001e.
  List<SomPersonalizado> _decodificar(String bruto) {
    final resultado = <SomPersonalizado>[];
    for (final linha in bruto.split('\u001e')) {
      if (linha.isEmpty) continue;
      final partes = linha.split('\u001f');
      if (partes.length < 3) continue;
      final slot = SlotSom.porChave(partes[0]);
      if (slot == null) continue;
      resultado.add(SomPersonalizado(
        slot: slot,
        nome: partes[1],
        caminho: partes.sublist(2).join('\u001f'),
      ));
    }
    return resultado;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}