import { Request, Response } from 'express';
import { Client } from 'pg';
import { buildPixPayload } from '../utils/pix';
import { env } from '../config/env';

export class PaymentController {
  constructor(private db: Client) {}

  // Gera o BR Code (PIX estatico) do plano Premium apontando para a conta
  // do desenvolvedor configurada em PIX_KEY.
  async createPixPayment(req: Request, res: Response): Promise<void> {
    const { driverId, amount, plan } = req.body;
    if (!driverId) {
      res.status(400).json({ error: 'driverId obrigatorio.' });
      return;
    }
    if (!env.pixKey) {
      res.status(503).json({
        error: 'PIX nao configurado no servidor (defina PIX_KEY).',
      });
      return;
    }
    const monthly = env.pixAmount;
    const annual = 29.99;
    const value = amount === annual ? annual : monthly;
    try {
      const paymentGatewayId =
        'pay_' + Math.random().toString(36).substring(2, 11);
      const copyAndPaste = buildPixPayload({
        key: env.pixKey,
        name: env.pixName,
        city: env.pixCity,
        amount: value,
        txid: `${plan || 'mensal'}_${paymentGatewayId}`,
        description: `${env.pixDescription} (${plan === 'anual' ? 'anual' : 'mensal'})`,
      });

      await this.db.query(
        'INSERT INTO payments (driver_id, gateway_id, amount, status) VALUES ($1, $2, $3, $4)',
        [driverId, paymentGatewayId, value, 'pending']
      );

      res.json({
        success: true,
        paymentId: paymentGatewayId,
        plan: plan === 'anual' ? 'anual' : 'mensal',
        copyAndPastePix: copyAndPaste,
        value,
        receiver: env.pixName,
      });
    } catch {
      res.status(500).json({ error: 'Falha ao gerar o pagamento PIX.' });
    }
  }

  // Confirma o pagamento (manual/administrativo) e libera o Premium.
  async confirmPremium(req: Request, res: Response): Promise<void> {
    const { driverId, paymentId } = req.body;
    const token = req.header('x-admin-token') || '';
    if (!env.adminToken || token !== env.adminToken) {
      res.status(403).json({
        error: 'Confirmacao manual exige o token administrativo.',
      });
      return;
    }
    if (!driverId) {
      res.status(400).json({ error: 'driverId obrigatorio.' });
      return;
    }
    try {
      await this.db.query(
        'UPDATE drivers SET is_premium = TRUE WHERE driver_id = $1',
        [driverId]
      );
      if (paymentId) {
        await this.db.query(
          "UPDATE payments SET status = 'paid', paid_at = NOW() WHERE gateway_id = $1",
          [paymentId]
        );
      }
      res.json({ success: true, message: 'Plano Premium ativado com sucesso.' });
    } catch {
      res.status(500).json({ error: 'Falha ao ativar plano Premium.' });
    }
  }
}
