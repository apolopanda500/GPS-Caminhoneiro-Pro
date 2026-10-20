// Motor de respostas do "Assistente da Estrada".
//
// Camada real de IA: modelo Gemini com uma equipe de agentes (Rota, Sinais,
// Velocidade, Clima, Socorro) alimentada por contexto em tempo real do app.
// Sem chave/sem rede, cai para o motor local baseado em estado.
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';

class AssistantEngine {
  static String? _erroLLM;

  /// Consulta o LLM real (Gemini) com a equipe de agentes e o estado atual.
  /// Retorna null quando IA nao esta configurada/falhou (caller faz fallback).
  static Future<String?> perguntarLLM({
    required String pergunta,
    required Map<String, dynamic> contexto,
    List<({String papel, String papelConteudo})> historico = const [],
  }) async {
    if (!AppConstants.iaConfigured) {
      _erroLLM = 'Sem chave GEMINI_API_KEY no keys.json.';
      return null;
    }
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '${AppConstants.geminiModel}:generateContent?key=${AppConstants.geminiApiKey}');

    final agentes = StringBuffer()
      ..writeln('AGENTE ROTA: ${contexto['rota'] ?? 'sem rota montada.'}')
      ..writeln('AGENTE SINAIS: ${contexto['sinais'] ?? 'nenhum sinal ativo.'}')
      ..writeln('AGENTE VELOCIDADE: ${contexto['velocidade'] ?? 'sem leitura de GPS.'}')
      ..writeln('AGENTE CLIMA: ${contexto['clima'] ?? 'sem dado de clima.'}')
      ..writeln('AGENTE FLOTA/REDE: ${contexto['rede'] ?? 'sem peers por perto.'}')
      ..writeln('AGENTE PERFIL: ${contexto['perfil'] ?? 'sem perfil carregado.'}');

    final instr = StringBuffer()
      ..writeln('Voce e a IA de bordo de um app para caminhoneiros '
          '(GPS Caminhoneiro Pro). Voce comanda equipes de agentes e cada '
          'agente entrega dados em tempo real a seguir.')
      ..writeln(agentes.toString())
      ..writeln('Regras: responda curto e direto (ate 3 frases), em '
          'portugues do Brasil, com base APENAS nos dados dos agentes '
          'acima e no bom senso; nunca invente dados que os agentes nao '
          'trouxeram; se faltar dado, diga o que esta disponivel e '
          'recomende a acao no app (ex.: "toque em Rota"). Quando houver '
          'perigo real, avise com urgencia.');

    for (final h in historico.take(6)) {
      instr.writeln('${h.papel}: ${h.papelConteudo}');
    }

    final corpo = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': instr.toString()},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': pergunta},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 300,
      },
    });

    try {
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: corpo,
          )
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) {
        _erroLLM = 'HTTP ${resp.statusCode}';
        return null;
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final candidatos = data['candidates'] as List<dynamic>? ?? const [];
      if (candidatos.isEmpty) return null;
      final conteudo = (candidatos.first as Map<String, dynamic>)['content']
          as Map<String, dynamic>?;
      final parts = conteudo?['parts'] as List<dynamic>? ?? const [];
      final texto = parts
          .map((p) => (p as Map<String, dynamic>)['text']?.toString() ?? '')
          .join(' ')
          .trim();
      if (texto.isEmpty) return null;
      _erroLLM = null;
      return texto;
    } catch (_) {
      _erroLLM = 'sem rede';
      return null;
    }
  }

  static String get ultimoErroIA => _erroLLM ?? '';

  static bool get iaAtiva => AppConstants.iaConfigured;

  /// Respostas prontas: cada uma reconhece palavras-chave e devolve a
  /// resposta com os dados reais do app.
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
