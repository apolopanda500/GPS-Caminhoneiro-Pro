import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/core/audio/falas.dart';

export 'package:gps_camioneiro_pro/core/audio/falas.dart';

/// Uma voz disponivel no aparelho.
class VozDisponivel {
  final String nome;
  final String local;
  final String? genero;

  const VozDisponivel({
    required this.nome,
    required this.local,
    this.genero,
  });

  String get rotulo {
    final g = (genero ?? '').toLowerCase();
    final tipo = g.startsWith('f') ? 'feminina' : (g.startsWith('m') ? 'masculina' : '');
    return tipo.isEmpty ? nome : '$nome ($tipo)';
  }
}

class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final FlutterTts _tts = FlutterTts();
  bool _iniciado = false;
  bool ligada = true;

  /// Como falar as paradas: numero ou nome do cliente.
  ModoFalaParada modoFalaParada = ModoFalaParada.numero;

  /// Perfil de fala (Padrão, Waze, Uber, 99).
  PerfilVoz perfil = PerfilVoz.padrao;

  /// Quando ligado, o app toca **apenas os sinos** (sem falar as ruas).
  bool somenteSino = false;

  /// Voz escolhida (nome) e tom da fala.
  String? vozEscolhida;
  double velocidade = 0.48;
  double tom = 1.0;

  /// Chamado antes/depois de falar para abaixar o radio (duck) e devolver o
  /// volume. Definido pelo app no main.dart.
  Future<void> Function()? antesDeFalar;
  Future<void> Function()? depoisDeFalar;

  Future<void> carregarPreferencia() async {
    final prefs = await SharedPreferences.getInstance();
    ligada = prefs.getBool('audio_voz') ?? true;
    modoFalaParada = (prefs.getString('audio_vozModo') ?? 'numero') == 'nome'
        ? ModoFalaParada.nomeCliente
        : ModoFalaParada.numero;
    perfil = PerfilVoz.porChave(prefs.getString('audio_vozPerfil') ?? 'padrao');
    somenteSino = prefs.getBool('audio_vozSomenteSino') ?? false;
    vozEscolhida = prefs.getString('audio_vozNome');
    velocidade = prefs.getDouble('audio_vozVelocidade') ?? 0.48;
    tom = prefs.getDouble('audio_vozTom') ?? 1.0;
  }

  /// Escolhe o modo de falar as paradas (numero ou nome do cliente).
  Future<void> definirModoFala(ModoFalaParada modo) async {
    modoFalaParada = modo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audio_vozModo', modo == ModoFalaParada.nomeCliente ? 'nome' : 'numero');
  }

  /// Troca o perfil de fala (Padrão, Waze, Uber, 99).
  Future<void> definirPerfil(PerfilVoz novo) async {
    perfil = novo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audio_vozPerfil', novo.name);
  }

  /// Só o sino (sem falar as ruas).
  Future<void> definirSomenteSino(bool v) async {
    somenteSino = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_vozSomenteSino', v);
  }

  /// Troca a voz do aparelho.
  Future<void> definirVoz(String? nome, {String local = 'pt-BR'}) async {
    vozEscolhida = nome;
    final prefs = await SharedPreferences.getInstance();
    if (nome == null) {
      await prefs.remove('audio_vozNome');
    } else {
      await prefs.setString('audio_vozNome', nome);
    }
    _iniciado = false;
    await _garantir();
  }

  /// Ajusta a velocidade e o tom da fala.
  Future<void> definirVozAjustes({double? velocidade, double? tom}) async {
    if (velocidade != null) this.velocidade = velocidade;
    if (tom != null) this.tom = tom;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('audio_vozVelocidade', this.velocidade);
    await prefs.setDouble('audio_vozTom', this.tom);
    _iniciado = false;
    await _garantir();
  }

  /// Vozes de fala em portugues disponibles no aparelho.
  Future<List<VozDisponivel>> listarVozes() async {
    try {
      final bruta = await _tts.getVoices;
      if (bruta is! List) return const [];
      final lista = <VozDisponivel>[];
      for (final v in bruta) {
        if (v is Map) {
          final local = v['locale']?.toString() ?? '';
          if (!local.toLowerCase().startsWith('pt')) continue;
          lista.add(VozDisponivel(
            nome: v['name']?.toString() ?? '',
            local: local,
            genero: v['gender']?.toString(),
          ));
        }
      }
      lista.sort((a, b) => a.nome.compareTo(b.nome));
      return lista;
    } catch (_) {
      return const [];
    }
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
      await _tts.setSpeechRate(velocidade);
      await _tts.setPitch(tom);
      await _tts.awaitSpeakCompletion(true);
      final voz = vozEscolhida;
      if (voz != null && voz.isNotEmpty) {
        await _tts.setVoice({'name': voz, 'locale': 'pt-BR'});
      }
      _iniciado = true;
    } catch (_) {}
  }

  Future<void> falar(String texto) async {
    if (!ligada) return;
    if (somenteSino) return; // so o sino: sem falar as ruas
    await _garantir();
    if (!_iniciado) return;
    try {
      await antesDeFalar?.call();
    } catch (_) {}
    try {
      await _tts.speak(texto);
    } catch (_) {}
    try {
      await depoisDeFalar?.call();
    } catch (_) {}
  }

  /// Fala a proxima parada quando o caminhao comeca a andar (saiu da
  /// parada anterior).
  Future<void> proximaParada({
    int? numero,
    String? nome,
    double? distanciaKm,
    int totalParadas = 0,
  }) async {
    await falar(
      Falas.proximaParada(
        perfil: perfil,
        numero: numero,
        nome: nome,
        distanciaKm: distanciaKm,
        porNome: modoFalaParada == ModoFalaParada.nomeCliente,
      ),
    );
  }

  /// Fala o inicio da rota: quantas paradas tem e qual e a proxima.
  ///
  /// A proxima parada pode ser falada pelo **numero** ou pelo **nome do
  /// cliente**, conforme o motorista escolheu em Som e voz.
  Future<void> rotaIniciada({
    required int totalParadas,
    int? proximoNumero,
    String? proximoNome,
    bool temRetornoEmpresa = false,
  }) async {
    await falar(
      Falas.rotaIniciada(
        perfil: perfil,
        totalParadas: totalParadas,
        proximoNumero: proximoNumero,
        nome: proximoNome,
        porNome: modoFalaParada == ModoFalaParada.nomeCliente,
        temRetornoEmpresa: temRetornoEmpresa,
      ),
    );
  }

  /// Fala a chegada na empresa: a rota acabou.
  Future<void> chegadaNaEmpresa() async {
    await falar(Falas.empresa(perfil: perfil));
  }

  /// "Chegou na parada numero 1... chegou na parada numero 2..." ate o
  /// ultimo cliente, dizendo sempre a proxima parada com o numero certo.
  ///
  /// O motorista escolhe no app se a voz fala o **numero** da parada ou o
  /// **nome do cliente** ([modoFalaParada]).
  Future<void> chegadaNaParada(
    int numero,
    int total, {
    int? proximoNumero,
    String? proximoNome,
    double? distanciaProximaKm,
  }) async {
    await falar(
      Falas.chegada(
        perfil: perfil,
        numero: numero,
        total: total,
        proximoNumero: proximoNumero,
        nome: proximoNome,
        distanciaProximaKm: distanciaProximaKm,
        porNome: modoFalaParada == ModoFalaParada.nomeCliente,
      ),
    );
  }

  Future<void> viagemConcluida() async {
    await falar(Falas.viagemConcluida(perfil: perfil));
  }
}
