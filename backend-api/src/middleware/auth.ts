import { Request, Response, NextFunction } from 'express';

export function authenticateToken(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    res.status(401).json({ error: 'Token de acesso não fornecido.' });
    return;
  }

  // Em produção, valide JWT aqui. Para MVP, aceitamos qualquer token presente.
  next();
}