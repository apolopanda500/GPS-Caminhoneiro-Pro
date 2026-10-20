/// Motor de respostas do "Assistente da Estrada".
///
/// Funciona 100% offline com base no estado real do app (rota, alertas,
/// limites de velocidade, clima) e pode serniaenciado por um LLM no backend
/// (POST /api/assistant) quando houver chave configurada la.
class AssistantEngine {
  /// Respostas prontas: cada uma reconhece palavras-chave e devolve a
  /// resposta com os dados reais do app.
  static String responder({
    required String pergunta,
    String? rotaResumo,
    int totalParadas = 0,
    int entregasFeitas = 0,
    List<String> alertas = const [],
    double? velocidade,
    double? limiteVelocidade,
    String? rua,
    String? clima,
    List<String> sugestoes = const [],
  }) {
    final q = pergunta.toLowerCase().trim();

    if (q.isEmpty) {
      return 'Me pergunte sobre a rota, os sinais da estrada, o limite de '
          'velocidade ou o clima. Eu respondo com os dados do seu app.';
    }

    if (_contem(q, ['rota', 'parada', 'entrega', 'cliente'])) {
      if (totalParadas == 0) {
        return 'Voce ainda nao montou rota. Toque em "Rota" na barra lateral '
            'para montar a rota com seus clientes.';
      }
      final resposta = StringBuffer('Sua rota tem $totalParadas parada(s)');
      if (entregasFeitas > 0) {
        resposta.write(' e $entregasFeitas ja entregada(s)');
      }
      if (rotaResumo != null && rotaResumo.isNotEmpty) {
        resposta.write('. $rotaResumo');
      }
      return resposta.toString();
    }

    if (_contem(q, ['sinal', 'alerta', 'aviso', 'perigo', 'acidente'])) {
      if (alertas.isEmpty) {
        return 'Nenhum sinal ativo por perto de voce agora. Se vir perigo, '
            'toque em "Sinalizar" e avise a rede.';
      }
      return 'Sinais ativos na sua regiao (${alertas.length}): '
          '${alertas.take(4).join('; ')}.';
    }

    if (_contem(q, ['velocidade', 'limite', 'radar', 'multa'])) {
      if (velocidade == null) {
        return 'Sem leitura de velocidade agora. O limite aparece quando o '
            'GPS esti com sinal.';
      }
      if (limiteVelocidade == null || limiteVelocidade <= 0) {
        return 'Voce esta a ${velocidade.toStringAsFixed(0)} km/h. O limite '
            'desta via ainda nao foi identificado.';
      }
      final acima = velocidade > limiteVelocidade + 8;
      return 'Voce esta a ${velocidade.toStringAsFixed(0)} km/h e o limite e '
          '${limiteVelocidade.toStringAsFixed(0)} km/h'
          '${acima ? ' — ACIMA DO LIMITE, reduza!' : ' — dentro do limite.'}'
          '${rua != null && rua.isNotEmpty ? ' Rua: $rua.' : ''}';
    }

    if (_contem(q, [
      'clima',
      'chuva',
      'chovendo',
      'chove',
      'tempestade',
      'terremoto',
      'desastre'
    ])) {
      if (clima == null || clima.isEmpty) {
        return 'Sem alerta de clima ou desastre ativo na sua regiao.';
      }
      return clima;
    }

    if (_contem(q, ['ajudante', 'socorro', 'guincho', 'ajuda'])) {
      return 'Voce pode chamar um ajudante pela rede: use "Sinalizar" e escolha '
          'o tipo de ajuda. Ajudantes veem seu sinal e podem oferecer suporte.';
    }

    if (_contem(q, ['ajuda', 'como funciona', 'o que voce faz', 'oq voce faz'])) {
      return 'Sou o assistente da estrada. Eu leio o estado do seu app e '
          'respondo sobre rota, paradas, sinais da rede, limite de velocidade, '
          'clima e como pedir ajuda. Pode perguntar a qualquer momento.';
    }

    if (_contem(q, ['rastreador', 'gps', 'posicao'])) {
      return 'Seu GPS esta ativo e a sua posicao e compartilhada com a rede '
          'V2X enquanto a tela estiver aberta.';
    }

    final extra = sugestoes.isEmpty ? '' : '\n\nSugestoes: ${sugestoes.join(', ')}.';
    return 'Nao tenho certeza dessa informacao aqui. Posso ajudar com rota, '
        'paradas, sinais da rede, limite de velocidade e clima.$extra';
  }

  static bool _contem(String texto, List<String> termos) =>
      termos.any((t) => texto.contains(t));
}
