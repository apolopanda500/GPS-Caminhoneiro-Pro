import { Request, Response } from 'express';
import { Client } from 'pg';
import crypto from 'crypto';
import { sendVerificationCode, mailerConfigured } from '../utils/mailer';

const CODE_TTL_MINUTES = 10;

function generateCode(): string {
  return crypto.randomInt(100000, 1000000).toString();
}

export class AuthController {
  constructor(private db: Client) {}

  private async issueCode(email: string, purpose: string): Promise<boolean> {
    const code = generateCode();
    await this.db.query(
      `INSERT INTO verification_codes (email, code, purpose, expires_at)
       VALUES ($1, $2, $3, NOW() + ($4 || ' minutes')::interval)`,
      [email, code, purpose, CODE_TTL_MINUTES]
    );
    try {
      return await sendVerificationCode(email, code);
    } catch (err) {
      console.error('[auth] falha ao enviar e-mail:', err);
      return false;
    }
  }

  async register(req: Request, res: Response): Promise<void> {
    const { email, password, name, height, weight, role, helpType } = req.body;
    if (!email || !password) {
      res.status(400).json({ error: 'E-mail e senha são obrigatórios.' });
      return;
    }

    const hash = crypto.createHash('sha256').update(password).digest('hex');
    const id = 'drv_' + Math.random().toString(36).substring(2, 9);
    const safeRole = role === 'ajudante' ? 'ajudante' : 'motorista';
    const precisaVerificar = mailerConfigured();

    try {
      await this.db.query(
        'INSERT INTO drivers (driver_id, email, password_hash, name, truck_height, truck_weight, role, help_type, email_verified) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)',
        [id, email, hash, name || '', height || 4.40, weight || 45.00, safeRole, helpType || null, precisaVerificar ? false : true]
      );
      let emailSent = false;
      if (precisaVerificar) {
        emailSent = await this.issueCode(email, 'signup');
      }
      res.status(201).json({
        success: true,
        driverId: id,
        name,
        role: safeRole,
        helpType: helpType || null,
        requiresVerification: precisaVerificar,
        emailSent,
        smtpConfigured: mailerConfigured(),
      });
    } catch (err: any) {
      if (err.code === '23505') {
        res.status(400).json({ error: 'E-mail já cadastrado.' });
      } else {
        res.status(500).json({ error: 'Erro interno ao cadastrar.' });
      }
    }
  }

  async verifyCode(req: Request, res: Response): Promise<void> {
    const { email, code } = req.body;
    if (!email || !code) {
      res.status(400).json({ error: 'E-mail e código são obrigatórios.' });
      return;
    }
    try {
      const found = await this.db.query(
        `SELECT id FROM verification_codes
         WHERE email = $1 AND code = $2 AND consumed = FALSE AND expires_at > NOW()
         ORDER BY created_at DESC LIMIT 1`,
        [email, code]
      );
      if (found.rows.length === 0) {
        res.status(400).json({ error: 'Código inválido ou expirado.' });
        return;
      }
      await this.db.query(
        'UPDATE verification_codes SET consumed = TRUE WHERE id = $1',
        [found.rows[0].id]
      );
      await this.db.query(
        'UPDATE drivers SET email_verified = TRUE, verified_at = NOW() WHERE email = $1',
        [email]
      );
      const result = await this.db.query(
        'SELECT driver_id, name, is_premium, avatar_url, truck_photo_url, truck_model, cargo_type FROM drivers WHERE email = $1',
        [email]
      );
      const d = result.rows[0] ?? {};
      res.json({
        driverId: d.driver_id,
        name: d.name,
        isPremium: d.is_premium ?? false,
        avatarUrl: d.avatar_url,
        truckPhotoUrl: d.truck_photo_url,
        truckModel: d.truck_model,
        cargoType: d.cargo_type,
      });
    } catch {
      res.status(500).json({ error: 'Erro ao validar o código.' });
    }
  }

  async resendCode(req: Request, res: Response): Promise<void> {
    const { email } = req.body;
    if (!email) {
      res.status(400).json({ error: 'E-mail é obrigatório.' });
      return;
    }
    try {
      const result = await this.db.query(
        'SELECT driver_id, email_verified FROM drivers WHERE email = $1',
        [email]
      );
      if (result.rows.length === 0) {
        res.status(404).json({ error: 'Conta não encontrada.' });
        return;
      }
      if (result.rows[0].email_verified) {
        res.status(400).json({ error: 'Conta já confirmada.' });
        return;
      }
      const emailSent = await this.issueCode(email, 'signup');
      res.json({ success: true, emailSent, smtpConfigured: mailerConfigured() });
    } catch {
      res.status(500).json({ error: 'Erro ao reenviar o código.' });
    }
  }

  async login(req: Request, res: Response): Promise<void> {
    const { email, password } = req.body;
    const hash = crypto.createHash('sha256').update(password).digest('hex');

    try {
      const result = await this.db.query(
        'SELECT driver_id, name, is_premium, avatar_url, truck_photo_url, truck_model, cargo_type, role, help_type, company_name, company_lat, company_lon, email_verified FROM drivers WHERE email = $1 AND password_hash = $2',
        [email, hash]
      );
      if (result.rows.length === 0) {
        res.status(401).json({ error: 'E-mail ou senha inválidos.' });
        return;
      }
      if (mailerConfigured() && result.rows[0].email_verified === false) {
        res.status(403).json({
          requiresVerification: true,
          error: 'Confirme sua conta com o código enviado por e-mail.',
        });
        return;
      }
      res.json({
        driverId: result.rows[0].driver_id,
        name: result.rows[0].name,
        isPremium: result.rows[0].is_premium ?? false,
        avatarUrl: result.rows[0].avatar_url,
        truckPhotoUrl: result.rows[0].truck_photo_url,
        truckModel: result.rows[0].truck_model,
        cargoType: result.rows[0].cargo_type,
        role: result.rows[0].role ?? 'motorista',
        helpType: result.rows[0].help_type,
        companyName: result.rows[0].company_name,
        companyLat: result.rows[0].company_lat,
        companyLon: result.rows[0].company_lon,
      });
    } catch {
      res.status(500).json({ error: 'Erro interno ao fazer login.' });
    }
  }

  async updateProfile(req: Request, res: Response): Promise<void> {
    const { driverId, name, truckModel, cargoType, avatarUrl, truckPhotoUrl, role, helpType, companyName, companyLat, companyLon } = req.body;
    try {
      await this.db.query(
        `UPDATE drivers SET name = COALESCE($2, name), truck_model = COALESCE($3, truck_model),
          cargo_type = COALESCE($4, cargo_type), avatar_url = COALESCE($5, avatar_url),
          truck_photo_url = COALESCE($6, truck_photo_url), role = COALESCE($7, role),
          help_type = COALESCE($8, help_type), company_name = COALESCE($9, company_name),
          company_lat = COALESCE($10, company_lat), company_lon = COALESCE($11, company_lon)
          WHERE driver_id = $1`,
        [driverId, name, truckModel, cargoType, avatarUrl, truckPhotoUrl, role, helpType, companyName, companyLat, companyLon]
      );
      res.json({ success: true });
    } catch {
      res.status(500).json({ error: 'Erro ao atualizar perfil.' });
    }
  }
}
