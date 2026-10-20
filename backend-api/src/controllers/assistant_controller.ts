import { Request, Response } from 'express';
import { Client } from 'pg';
import { env } from '../config/env';
import { responderLocal, ContextoAssistente } from '../utils/assistant';

/**
 * Assistente da estrada.
 *
 * Resposta local (sempre funciona) + upgrade opcional por LLM quando houver
 * chave configurada (OPENAI_API_KEY ou ANTHROPIC_API_KEY no Render).
 */
export class AssistantController {
  constructor(private db: Client) {}

  async ask(req: Request, res: Response): Promise<void> {
    const { pergunta, contexto } = req.body ?? {};
    if (!pergunta || typeof pergunta !== 'string') {
      res.status(400).json({ error: 'Pergunta obrigatoria.' });
      return;
    }

    const dados = await this.montarContexto(contexto ?? {});
    const local = responderLocal(pergunta, dados);

    const llm = await this.perguntarAoLlm(pergunta, dados);
    res.json({
      resposta: llm ?? local,
      origem: llm ? 'llm' : 'local',
      contexto: dados,
    });
  }

  private async montarContexto(contexto: any): Promise<ContextoAssistente> {
    const base: ContextoAssistente = {
      totalParadas: Number(contexto.totalParadas ?? 0),
      entregasFeitas: Number(contexto.entregasFeitas ?? 0),
      velocidade: contexto.velocidade ?? null,
      limiteVelocidade: contexto.limiteVelocidade ?? null,
      rua: contexto.rua ?? null,
      alertas: Array.isArray(contexto.alertas) ? contexto.alertas : [],
      clima: contexto.clima ?? null,
    };
    try {
      const count = await this.db.query(
        'SELECT COUNT(*)::int AS total FROM road_alerts WHERE created_at > NOW() - INTERVAL \'6 hours\'',
      );
      base.alertasNoBanco = count.rows[0]?.total ?? 0;
    } catch {
      base.alertasNoBanco = 0;
    }
    return base;
  }

  private async perguntarAoLlm(
    pergunta: string,
    dados: ContextoAssistente,
  ): Promise<string | null> {
    const sistema =
      'Voce e o assistente de uma rede de caminhoneiros. Responda em portugues ' +
      'do Brasil, de forma curta e pratica, usando os dados do app. ' +
      `Dados: ${JSON.stringify(dados)}`;

    try {
      if (env.geminiApiKey) {
        const resp = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${env.geminiModel}:generateContent?key=${env.geminiApiKey}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              systemInstruction: { parts: [{ text: sistema }] },
              contents: [{ role: 'user', parts: [{ text: pergunta }] }],
              generationConfig: { maxOutputTokens: 300 },
            }),
          },
        );
        if (resp.ok) {
          const data: any = await resp.json();
          const texto = data?.candidates?.[0]?.content?.parts?.[0]?.text;
          if (typeof texto === 'string' && texto.trim().length > 0) {
            return texto.trim();
          }
        }
      }

      if (env.openaiApiKey) {
        const resp = await fetch('https://api.openai.com/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${env.openaiApiKey}`,
          },
          body: JSON.stringify({
            model: 'gpt-4o-mini',
            messages: [
              { role: 'system', content: sistema },
              { role: 'user', content: pergunta },
            ],
            max_tokens: 200,
          }),
        });
        if (resp.ok) {
          const data: any = await resp.json();
          const texto = data?.choices?.[0]?.message?.content;
          if (typeof texto === 'string' && texto.trim().length > 0) {
            return texto.trim();
          }
        }
      }

      if (env.anthropicApiKey) {
        const resp = await fetch('https://api.anthropic.com/v1/messages', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': env.anthropicApiKey,
            'anthropic-version': '2023-06-01',
          },
          body: JSON.stringify({
            model: 'claude-3-5-haiku-latest',
            max_tokens: 200,
            system: sistema,
            messages: [{ role: 'user', content: pergunta }],
          }),
        });
        if (resp.ok) {
          const data: any = await resp.json();
          const texto = data?.content?.[0]?.text;
          if (typeof texto === 'string' && texto.trim().length > 0) {
            return texto.trim();
          }
        }
      }
    } catch (err) {
      console.error('[assistant] LLM indisponivel, usando resposta local.');
    }
    return null;
  }
}
