import { Request, Response } from 'express';
import { Client } from 'pg';

export class PaymentController {
  constructor(private db: Client) {}

  // Cria a intenção de compra do plano Premium Pro (PIX Mercado Pago / Stripe)
  async createPixPayment(req: Request, res: Response): Promise<void> {
    const { driverId, email } = req.body;
    try {
      // Simulação da chamada da API do Mercado Pago / Stripe de 2026
      const paymentGatewayId = 'pay_' + Math.random().toString(36).substring(2, 9);
      const qrCodePixBase64 =
        '00020101021226830014br.gov.bcb.pix2561seu-qrcode-pix-aqui...';

      // Salva no banco que o motorista iniciou uma tentativa de compra
      await this.db.query(
        'INSERT INTO payments (driver_id, gateway_id, amount, status) VALUES ($1, $2, $3, $4)',
        [driverId, paymentGatewayId, 29.90, 'pending']
      );

      res.json({
        success: true,
        paymentId: paymentGatewayId,
        pixQrCode: qrCodePixBase64,
        copyAndPastePix: '00020101021226830014br.gov.bcb.pix...',
        value: 29.90,
      });
    } catch (err) {
      res.status(500).json({ error: 'Falha ao gerar o gateway de pagamento.' });
    }
  }

  // Confirma pagamento e libera recursos Premium no banco
  async confirmPremium(req: Request, res: Response): Promise<void> {
    const { driverId, paymentId } = req.body;
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