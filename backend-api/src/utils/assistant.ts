/**
 * Respostas locais do assistente (sempre funcionam, sem internet).
 * Espelha a logica do app (core/ai/assistant_engine.dart).
 */
export interface ContextoAssistente {
  totalParadas: number;
  entregasFeitas: number;
  velocidade: number | null;
  limiteVelocidade: number | null;
  rua: string | null;
  alertas: string[];
  clima: string | null;
  alertasNoBanco?: number;
}

function contem(texto: string, termos: string[]): boolean {
  return termos.some((t) => texto.includes(t));
}

export function responderLocal(
  pergunta: string,
  ctx: ContextoAssistente,
): string {
  const q = (pergunta ?? '').toLowerCase().trim();

  if (!q) {
    return 'Me pergunte sobre a rota, os sinais da estrada, o limite de ' +
      'velocidade ou o clima. Eu respondo com os dados do seu app.';
  }

  if (contem(q, ['rota', 'parada', 'entrega', 'cliente'])) {
    if (!ctx.totalParadas) {
      return 'Voce ainda nao montou rota. Toque em "Rota" para montar a rota ' +
        'com seus clientes.';
    }
    let resposta = `Sua rota tem ${ctx.totalParadas} parada(s)`;
    if (ctx.entregasFeitas > 0) {
      resposta += ` e ${ctx.entregasFeitas} ja entregue(s)`;
    }
    return `${resposta}.`;
  }

  if (contem(q, ['sinal', 'alerta', 'aviso', 'perigo', 'acidente'])) {
    if (!ctx.alertas.length) {
      const noBanco = ctx.alertasNoBanco ?? 0;
      return noBanco > 0
        ? `Ha ${noBanco} aviso(s) registrado(s) na rede nas ultimas 6 horas, ` +
            'mas nenhum sinal ativo na sua regiao.'
        : 'Nenhum sinal ativo por perto de voce agora.';
    }
    return `Sinais ativos (${ctx.alertas.length}): ${ctx.alertas
      .slice(0, 4)
      .join('; ')}.`;
  }

  if (contem(q, ['velocidade', 'limite', 'radar', 'multa'])) {
    if (ctx.velocidade == null) {
      return 'Sem leitura de velocidade agora.';
    }
    if (!ctx.limiteVelocidade) {
      return `Voce esta a ${ctx.velocidade.toFixed(0)} km/h. O limite desta ` +
        'via ainda nao foi identificado.';
    }
    const acima = ctx.velocidade > ctx.limiteVelocidade + 8;
    return `Voce esta a ${ctx.velocidade.toFixed(0)} km/h e o limite e ` +
      `${ctx.limiteVelocidade.toFixed(0)} km/h` +
      `${acima ? ' — ACIMA DO LIMITE, reduza!' : ' — dentro do limite.'}` +
      `${ctx.rua ? ` Rua: ${ctx.rua}.` : ''}`;
  }

  if (contem(q, ['clima', 'chuva', 'chovendo', 'chove', 'tempestade', 'terremoto', 'desastre'])) {
    return ctx.clima || 'Sem alerta de clima ou desastre ativo na sua regiao.';
  }

  if (contem(q, ['ajudante', 'socorro', 'guincho', 'ajuda'])) {
    return 'Use "Sinalizar" e escolha o tipo de ajuda. Ajudantes da rede ' +
      'veem seu sinal e podem oferecer suporte.';
  }

  if (contem(q, ['ajuda', 'como funciona', 'o que voce faz'])) {
    return 'Sou o assistente da estrada. Respondo sobre rota, paradas, sinais ' +
      'da rede, limite de velocidade e clima.';
  }

  return 'Nao tenho certeza dessa informacao. Posso ajudar com rota, ' +
    'paradas, sinais da rede, limite de velocidade e clima.';
}
