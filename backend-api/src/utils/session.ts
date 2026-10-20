import crypto from 'crypto';
import { env } from '../config/env';

export interface Sessao {
  driverId: string;
  expiraEm: number;
}

const VALIDADE_MS = 30 * 24 * 60 * 60 * 1000;

function assinatura(payload: string): string {
  return crypto
    .createHmac('sha256', env.jwtSecret)
    .update(payload)
    .digest('hex');
}

/** Cria um token de sessao assinado (driverId + validade). */
export function criarToken(driverId: string): string {
  const expiraEm = Date.now() + VALIDADE_MS;
  const payload = Buffer.from(
    JSON.stringify({ driverId, expiraEm } satisfies Sessao),
  ).toString('base64url');
  return `${payload}.${assinatura(payload)}`;
}

/** Valida o token e devolve a sessao, ou null se invalido/expirado. */
export function verificarToken(token: string | undefined): Sessao | null {
  if (!token) return null;
  const partes = token.split('.');
  if (partes.length !== 2) return null;
  const [payload, assinaturaRecebida] = partes;
  const esperada = assinatura(payload);
  const a = Buffer.from(assinaturaRecebida);
  const b = Buffer.from(esperada);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  try {
    const sessao = JSON.parse(
      Buffer.from(payload, 'base64url').toString('utf8'),
    ) as Sessao;
    if (!sessao.driverId || !sessao.expiraEm) return null;
    if (sessao.expiraEm < Date.now()) return null;
    return sessao;
  } catch {
    return null;
  }
}

/** Extrai o token do header Authorization ou x-gps-token. */
export function tokenDaRequisicao(req: {
  headers: Record<string, unknown>;
}): string | undefined {
  const auth = req.headers['authorization'];
  if (typeof auth === 'string' && auth.startsWith('Bearer ')) {
    return auth.slice(7).trim();
  }
  const alternativo = req.headers['x-gps-token'];
  if (typeof alternativo === 'string') return alternativo.trim();
  return undefined;
}
