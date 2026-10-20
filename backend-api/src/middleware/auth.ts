import { Request, Response, NextFunction } from 'express';
import { tokenDaRequisicao, verificarToken } from '../utils/session';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      driverId?: string;
    }
  }
}

/**
 * Exige um token de sessao valido.
 * Anexa `req.driverId` para o controller usar como identidade real.
 */
export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const sessao = verificarToken(tokenDaRequisicao(req));
  if (!sessao) {
    res.status(401).json({
      error: 'Sessao invalida ou expirada. Faca login novamente.',
    });
    return;
  }
  req.driverId = sessao.driverId;
  next();
}
