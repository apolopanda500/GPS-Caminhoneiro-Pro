/// Perfis de voz do app - como o GPS fala com o motorista.
///
/// Cada perfil tem o seu jeito de falar (curto, direto, numero ou nome).
/// O padrao do app e "resumido": fala o essencial e nao enche linguiça.
enum PerfilVoz {
  padrao('Padrão', 'Resumido: só o essencial'),
  waze('Waze', 'Muito curto, tipo Waze'),
  uber('Uber', 'Objetivo, com o número da parada'),
  noventa9('99', 'Mínimo: número e ação');

  const PerfilVoz(this.rotulo, this.descricao);

  final String rotulo;
  final String descricao;

  /// Perfis "curtos" (Waze e 99) speak ainda menos.
  bool get curto => this == PerfilVoz.waze || this == PerfilVoz.noventa9;

  static PerfilVoz porChave(String chave) {
    for (final p in PerfilVoz.values) {
      if (p.name == chave) return p;
    }
    return PerfilVoz.padrao;
  }
}

/// Como falar as paradas.
enum ModoFalaParada {
  numero('Número da parada'),
  nomeCliente('Nome do cliente');

  const ModoFalaParada(this.rotulo);

  final String rotulo;
}

/// Monta as frases da voz.
///
/// Tudo aqui e texto puro (sem TTS): assim da para testar em bateria
/// exatamente o que o motorista vai ouvir.
class Falas {
  const Falas._();

  /// "Próxima parada 3, a 2 quilômetros" (curto, sem enrolação).
  static String proximaParada({
    required PerfilVoz perfil,
    int? numero,
    String? nome,
    double? distanciaKm,
    bool porNome = false,
  }) {
    final buf = StringBuffer();
    final alvo =
        porNome && (nome ?? '').trim().isNotEmpty ? nome!.trim() : null;

    if (perfil == PerfilVoz.waze) {
      // Waze: "Próxima: 3" e a distancia so quando ta perto.
      buf.write('Próxima: ');
      buf.write(alvo ?? (numero != null ? '$numero' : 'a próxima'));
      final perto = distanciaKm != null && distanciaKm < 0.5;
      if (perto) buf.write(', logo ali');
      return buf.toString();
    }

    if (perfil == PerfilVoz.noventa9) {
      // 99: "3, logo ali" / "3, 2 km".
      buf.write(alvo ?? (numero != null ? '$numero' : 'próxima'));
      if (distanciaKm != null && distanciaKm > 0) {
        if (distanciaKm < 0.15) {
          buf.write(', chegou');
        } else if (distanciaKm < 1) {
          buf.write(', perto');
        } else {
          buf.write(', ${distanciaKm.toStringAsFixed(0)} km');
        }
      }
      return buf.toString();
    }

    if (perfil == PerfilVoz.uber) {
      buf.write('Próxima parada é ');
      buf.write(alvo ?? (numero != null ? 'a número $numero' : 'a próxima'));
      _distancia(buf, distanciaKm, compacto: true);
      return buf.toString();
    }

    // Padrao (resumido).
    buf.write('Próxima parada ');
    buf.write(alvo ?? (numero != null ? '$numero' : 'a seguir'));
    _distancia(buf, distanciaKm, compacto: true);
    return buf.toString();
  }

  /// Fala da chegada na parada.
  static String chegada({
    required PerfilVoz perfil,
    required int numero,
    required int total,
    int? proximoNumero,
    String? nome,
    double? distanciaProximaKm,
    bool porNome = false,
  }) {
    if (numero >= total) {
      return perfil.curto
          ? 'Última entrega. Volte para a empresa.'
          : 'Última entrega concluída. Volte para a empresa.';
    }
    final buf = StringBuffer();
    if (perfil == PerfilVoz.waze) {
      buf.write('Chegou. ');
    } else if (perfil == PerfilVoz.noventa9) {
      buf.write('$numero. ');
    } else {
      buf.write(porNome && (nome ?? '').trim().isNotEmpty
          ? 'Chegou em ${nome!.trim()}. '
          : 'Chegou na parada $numero. ');
    }
    buf.write(proximaParada(
      perfil: perfil,
      numero: proximoNumero,
      nome: nome,
      distanciaKm: distanciaProximaKm,
      porNome: porNome,
    ));
    return buf.toString();
  }

  /// Fala do inicio da rota.
  static String rotaIniciada({
    required PerfilVoz perfil,
    required int totalParadas,
    int? proximoNumero,
    String? nome,
    bool porNome = false,
    bool temRetornoEmpresa = false,
  }) {
    final buf = StringBuffer();
    if (perfil == PerfilVoz.waze) {
      buf.write('Rota com $totalParadas paradas. ');
    } else if (perfil == PerfilVoz.noventa9) {
      buf.write('$totalParadas paradas. ');
    } else {
      buf.write('Rota iniciada, $totalParadas paradas');
      if (temRetornoEmpresa) buf.write(' e retorno a empresa');
      buf.write('. ');
    }
    buf.write(proximaParada(
      perfil: perfil,
      numero: proximoNumero,
      nome: nome,
      porNome: porNome,
    ));
    return buf.toString();
  }

  /// Chegada na empresa (rotina acabando).
  static String empresa({required PerfilVoz perfil}) => perfil.curto
      ? 'Empresa. Rota concluída.'
      : 'Você chegou na empresa. Viagem concluída.';

  /// Fim da viagem.
  static String viagemConcluida({required PerfilVoz perfil}) =>
      perfil.curto ? 'Viagem concluída.' : 'Viagem concluída. Bom trabalho!';

  /// Distancia curta (sem "quilometros" quando perto).
  static void _distancia(StringBuffer buf, double? distanciaKm,
      {bool compacto = false}) {
    if (distanciaKm == null || distanciaKm <= 0) return;
    if (distanciaKm < 0.12) {
      buf.write(', logo ali');
    } else if (distanciaKm < 1) {
      buf.write(compacto ? ', perto' : ', a menos de um quilômetro');
    } else {
      final km = distanciaKm.toStringAsFixed(0);
      buf.write(compacto ? ', $km km' : ', a $km quilometros');
    }
  }
}
