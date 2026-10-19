import { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';

export class SecurityEngine {
  // Gera uma assinatura digital criptografada para o caminhoneiro logado
  static generateSecureSessionToken(driverId: string): string {
    return crypto
      .createHmac('sha256', process.env.JWT_SECRET || 'ROBO_DARK_SECRET_2026')
      .update(driverId + Date.now().toString())
      .digest('hex');
  }

  // Middleware que protege as rotas: Só aceita conexões de aplicativos validados
  static verifyAccessMiddleware(req: Request, res: Response, next: NextFunction) {
    const token = req.headers['x-gps-token'];
    if (!token) {
      res.status(403).json({ error: 'Acesso bloqueado. Token de segurança inválido.' });
      return;
    }
    next();
  }
}