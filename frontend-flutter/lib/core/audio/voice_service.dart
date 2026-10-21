import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Como a voz anuncia as paradas.
enum ModoFalaParada {
  /// "Chegou na parada numero 2 de 5"
  numero,

  /// "Chegou na empresa do cliente Joao"
  nomeCliente,
}

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
    final buf = StringBuffer();
    if (modoFalaParada == ModoFalaParada.nomeCliente &&
        nome != null &&
        nome.trim().isNotEmpty) {
      buf.write('Próxima parada: ${nome.trim()}');
    } else if (numero != null) {
      buf.write('Próxima parada, número $numero');
    } else {
      buf.write('Rota concluída');
    }
    if (distanciaKm != null && distanciaKm > 0) {
      if (distanciaKm < 0.1) {
        buf.write(', logo ali');
      } else if (distanciaKm < 1) {
        buf.write(', a menos de um quilômetro');
      } else {
        buf.write(', a ${distanciaKm.toStringAsFixed(0)} quilometros');
      }
    }
    await falar(buf.toString());
  }

  /// Fala o inicio da rota: quantas paradas tem, qual e a proxima e o
  /// "bom trabalho".
  ///
  /// A proxima parada pode ser falada pelo **numero** ou pelo **nome do
  /// cliente**, conforme o motorista escolheu em Som e voz.
  Future<void> rotaIniciada({
    required int totalParadas,
    int? proximoNumero,
    String? proximoNome,
    bool temRetornoEmpresa = false,
  }) async {
    final buf = StringBuffer();
    buf.write('Rota iniciada');
    if (totalParadas > 0) {
      buf.write(', com $totalParadas parada${totalParadas == 1 ? '' : 's'}');
      if (temRetornoEmpresa) buf.write(' e retorno a empresa');
    }
    buf.write('. ');

    if (modoFalaParada == ModoFalaParada.nomeCliente &&
        proximoNome != null &&
        proximoNome.trim().isNotEmpty) {
      buf.write('Próxima parada: ${proximoNome.trim()}. ');
    } else if (proximoNumero != null) {
      buf.write('Próxima parada, número $proximoNumero. ');
    }

    buf.write('Bom trabalho!');
    await falar(buf.toString());
  }

  /// Fala a chegada na empresa: a rota acabou.
  Future<void> chegadaNaEmpresa() async {
    await falar(
      'Você chegou na empresa. Viagem concluída com sucesso. Bom trabalho!',
    );
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
    final buf = StringBuffer();
    final porNome = modoFalaParada == ModoFalaParada.nomeCliente;

    if (numero >= total) {
      buf.write('Ultima entrega concluida. Agora volte para a empresa.');
    } else if (porNome && proximoNome != null && proximoNome.trim().isNotEmpty) {
      buf.write('Chegou em $proximoNome. ');
      buf.write(_fraseProxima(proximoNumero, proximoNome, distanciaProximaKm, true));
    } else {
      buf.write('Chegou na parada numero $numero de $total. ');
      buf.write(_fraseProxima(proximoNumero, proximoNome, distanciaProximaKm, porNome));
    }
    await falar(buf.toString());
  }

  /// Frase com a proxima parada (numero, nome e distancia).
  String _fraseProxima(
    int? proximoNumero,
    String? proximoNome,
    double? distanciaProximaKm,
    bool porNome,
  ) {
    final buf = StringBuffer();
    if (proximoNumero != null) {
      buf.write('Proxima parada');
      if (porNome && proximoNome != null && proximoNome.trim().isNotEmpty) {
        buf.write(', $proximoNome');
      } else {
        buf.write(', numero $proximoNumero');
      }
    } else if (proximoNome != null && proximoNome.trim().isNotEmpty) {
      buf.write('Proxima parada, $proximoNome');
    } else {
      buf.write('A proxima parada esta esperando por voce.');
      return buf.toString();
    }
    if (distanciaProximaKm != null && distanciaProximaKm > 0) {
      if (distanciaProximaKm < 0.1) {
        buf.write(', logo ali');
      } else if (distanciaProximaKm < 1) {
        buf.write(', a menos de um quilometro');
      } else {
        buf.write(', a ${distanciaProximaKm.toStringAsFixed(0)} quilometros');
      }
    } else {
      buf.write('.');
    }
    return buf.toString();
  }


  Future<void> viagemConcluida() async {
    await falar('Viagem concluída. Bom trabalho, caminhoneiro!');
  }
}
