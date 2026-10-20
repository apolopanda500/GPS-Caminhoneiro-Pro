import { Request, Response } from 'express';
import { Client } from 'pg';
import crypto from 'crypto';
import { sendVerificationCode, sendPasswordResetCode, mailerConfigured } from '../utils/mailer';
import { criarToken } from '../utils/session';

const CODE_TTL_MINUTES = 10;

function generateCode(): string {
  return crypto.randomInt(100000, 1000000).toString();
}

/** Normaliza o e-mail igual em cadastro, login e recuperacao. */
function normalizarEmail(email: unknown): string {
  return String(email ?? '').trim().toLowerCase();
}

function emailValido(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email);
}

export class AuthController {
  constructor(private db: Client) {}

  private async issueCode(
    email: string,
    purpose: string,
    remetente: (to: string, code: string) => Promise<boolean> = sendVerificationCode
  ): Promise<boolean> {
    const code = generateCode();
    await this.db.query(
      `INSERT INTO verification_codes (email, code, purpose, expires_at)
       VALUES ($1, $2, $3, NOW() + ($4 || ' minutes')::interval)`,
      [email, code, purpose, CODE_TTL_MINUTES]
    );
    try {
      return await remetente(email, code);
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
    const emailLimpo = normalizarEmail(email);
    if (!emailValido(emailLimpo)) {
      res.status(400).json({ error: 'E-mail inválido.' });
      return;
    }
    if (String(password).length < 6) {
      res.status(400).json({ error: 'A senha precisa ter ao menos 6 caracteres.' });
      return;
    }
    if (!mailerConfigured()) {
      res.status(503).json({
        error:
          'Validação por e-mail indisponível no momento. Tente novamente mais tarde.',
      });
      return;
    }

    const hash = crypto.createHash('sha256').update(password).digest('hex');
    const id = 'drv_' + crypto.randomUUID().replace(/-/g, '').substring(0, 16);
    const safeRole = role === 'ajudante' ? 'ajudante' : 'motorista';

    try {
      await this.db.query(
        'INSERT INTO drivers (driver_id, email, password_hash, name, truck_height, truck_weight, role, help_type, email_verified) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, FALSE)',
        [id, emailLimpo, hash, name || '', height || 4.40, weight || 45.00, safeRole, helpType || null]
      );
      const emailSent = await this.issueCode(emailLimpo, 'signup');
      res.status(201).json({
        success: true,
        driverId: id,
        token: criarToken(id),
        name,
        role: safeRole,
        helpType: helpType || null,
        requiresVerification: true,
        emailSent,
        smtpConfigured: true,
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
    const emailLimpo = normalizarEmail(email);
    const purpose = String(req.body.purpose ?? '').trim();
    // Sem purpose explicito, aceita os codigos de confirmacao de conta
    // (cadastro ou login) — o de reset de senha exige purpose = 'reset'.
    const purposes =
      purpose === 'reset' ? ['reset'] : ['signup', 'login'];
    try {
      const found = await this.db.query(
        `SELECT id FROM verification_codes
         WHERE email = $1 AND code = $2 AND purpose = ANY($3::text[])
           AND consumed = FALSE AND expires_at > NOW()
         ORDER BY created_at DESC LIMIT 1`,
        [emailLimpo, String(code).trim(), purposes]
      );
      if (found.rows.length === 0) {
        res.status(400).json({ error: 'Código inválido ou expirado.' });
        return;
      }
      await this.db.query(
        'UPDATE verification_codes SET consumed = TRUE WHERE id = $1',
        [found.rows[0].id]
      );
      if (purpose === 'reset') {
        // A senha nova e o codigo de reset sao tratados em resetPassword.
        res.json({ success: true, requiresPasswordReset: true });
        return;
      }
      await this.db.query(
        'UPDATE drivers SET email_verified = TRUE, verified_at = NOW() WHERE email = $1',
        [emailLimpo]
      );
      const result = await this.db.query(
        'SELECT driver_id, name, is_premium, avatar_url, truck_photo_url, truck_model, cargo_type, role, help_type FROM drivers WHERE email = $1',
        [emailLimpo]
      );
      const d = result.rows[0] ?? {};
      res.json({
        driverId: d.driver_id,
        token: criarToken(d.driver_id),
        name: d.name,
        isPremium: d.is_premium ?? false,
        avatarUrl: d.avatar_url,
        truckPhotoUrl: d.truck_photo_url,
        truckModel: d.truck_model,
        cargoType: d.cargo_type,
        role: d.role ?? 'motorista',
        helpType: d.help_type,
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
    const emailLimpo = normalizarEmail(email);
    try {
      const result = await this.db.query(
        'SELECT driver_id, email_verified FROM drivers WHERE email = $1',
        [emailLimpo]
      );
      if (result.rows.length === 0) {
        res.status(404).json({ error: 'Conta não encontrada.' });
        return;
      }
      if (result.rows[0].email_verified) {
        res.status(400).json({ error: 'Conta já confirmada.' });
        return;
      }
      const emailSent = await this.issueCode(emailLimpo, 'signup');
      res.json({ success: true, emailSent, smtpConfigured: mailerConfigured() });
    } catch {
      res.status(500).json({ error: 'Erro ao reenviar o código.' });
    }
  }

  /**
   * Envia o codigo de redefinicao de senha.
   * Nao revela se o e-mail existe (sempre responde a mesma coisa).
   */
  async requestPasswordReset(req: Request, res: Response): Promise<void> {
    const { email } = req.body;
    if (!email) {
      res.status(400).json({ error: 'E-mail é obrigatório.' });
      return;
    }
    const emailLimpo = normalizarEmail(email);
    if (!emailValido(emailLimpo)) {
      res.status(400).json({ error: 'E-mail inválido.' });
      return;
    }
    if (!mailerConfigured()) {
      res.status(503).json({
        error:
          'Recuperação de senha indisponível no momento. Tente novamente mais tarde.',
      });
      return;
    }
    try {
      const result = await this.db.query(
        'SELECT driver_id FROM drivers WHERE email = $1',
        [emailLimpo]
      );
      if (result.rows.length > 0) {
        await this.issueCode(emailLimpo, 'reset', sendPasswordResetCode);
      }
      res.json({
        success: true,
        message:
          'Se o e-mail estiver cadastrado, enviamos o código de redefinição de senha.',
      });
    } catch {
      res.status(500).json({ error: 'Erro ao solicitar a redefinição de senha.' });
    }
  }

  /** Troca a senha depois de confirmar o codigo de redefinicao. */
  async resetPassword(req: Request, res: Response): Promise<void> {
    const { email, code, password } = req.body;
    if (!email || !code || !password) {
      res.status(400).json({ error: 'E-mail, código e nova senha são obrigatórios.' });
      return;
    }
    const emailLimpo = normalizarEmail(email);
    if (String(password).length < 6) {
      res.status(400).json({ error: 'A senha precisa ter ao menos 6 caracteres.' });
      return;
    }
    const hash = crypto.createHash('sha256').update(String(password)).digest('hex');
    try {
      const found = await this.db.query(
        `SELECT id FROM verification_codes
         WHERE email = $1 AND code = $2 AND purpose = 'reset'
           AND consumed = FALSE AND expires_at > NOW()
         ORDER BY created_at DESC LIMIT 1`,
        [emailLimpo, String(code).trim()]
      );
      if (found.rows.length === 0) {
        res.status(400).json({ error: 'Código inválido ou expirado.' });
        return;
      }
      const updated = await this.db.query(
        'UPDATE drivers SET password_hash = $2 WHERE email = $1',
        [emailLimpo, hash]
      );
      if ((updated.rowCount ?? 0) === 0) {
        res.status(404).json({ error: 'Conta não encontrada.' });
        return;
      }
      await this.db.query(
        'UPDATE verification_codes SET consumed = TRUE WHERE id = $1',
        [found.rows[0].id]
      );
      res.json({ success: true });
    } catch {
      res.status(500).json({ error: 'Erro ao redefinir a senha.' });
    }
  }

  async login(req: Request, res: Response): Promise<void> {
    const { email, password } = req.body;
    if (!email || !password) {
      res.status(400).json({ error: 'E-mail e senha são obrigatórios.' });
      return;
    }
    const emailLimpo = normalizarEmail(email);
    const hash = crypto.createHash('sha256').update(String(password)).digest('hex');

    try {
      const result = await this.db.query(
        'SELECT driver_id, email, name, is_premium, avatar_url, truck_photo_url, truck_model, cargo_type, role, help_type, company_name, company_lat, company_lon, email_verified FROM drivers WHERE email = $1 AND password_hash = $2',
        [emailLimpo, hash]
      );
      if (result.rows.length === 0) {
        res.status(401).json({ error: 'E-mail ou senha inválidos.' });
        return;
      }
      if (result.rows[0].email_verified === false) {
        const emailSent = await this.issueCode(
          result.rows[0].email ?? emailLimpo,
          'login'
        );
        res.status(403).json({
          requiresVerification: true,
          emailSent,
          error: 'Confirme sua conta com o código enviado por e-mail.',
        });
        return;
      }
      res.json({
        driverId: result.rows[0].driver_id,
        token: criarToken(result.rows[0].driver_id),
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
    const { name, truckModel, cargoType, avatarUrl, truckPhotoUrl, role, helpType, companyName, companyLat, companyLon } = req.body;
    // A identidade vem do token de sessao, nunca do corpo da requisicao.
    const driverId = req.driverId;
    if (!driverId) {
      res.status(401).json({ error: 'Sessao invalida. Faca login novamente.' });
      return;
    }
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

  async updatePhoto(req: Request, res: Response): Promise<void> {
    const { data, kind } = req.body as { data?: string; kind?: string };
    const driverId = req.driverId;
    if (!driverId) {
      res.status(401).json({ error: 'Sessao invalida. Faca login novamente.' });
      return;
    }
    if (!data) {
      res.status(400).json({ error: 'driverId e data obrigatorios.' });
      return;
    }
    const isDataUrl = /^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/=\s]+$/.test(data);
    if (!isDataUrl) {
      res.status(400).json({ error: 'Formato de imagem invalido.' });
      return;
    }
    if (data.length > 900_000) {
      res.status(413).json({ error: 'Imagem grande demais. Envie ate ~650KB.' });
      return;
    }
    const column = kind === 'truck' ? 'truck_photo_url' : 'avatar_url';
    try {
      await this.db.query(`UPDATE drivers SET ${column} = $2 WHERE driver_id = $1`, [driverId, data]);
      res.json({ success: true });
    } catch {
      res.status(500).json({ error: 'Erro ao salvar a foto.' });
    }
  }

  async getPhoto(req: Request, res: Response): Promise<void> {
    const driverId = req.params.driverId;
    try {
      const row = await this.db.query(
        'SELECT avatar_url, truck_photo_url FROM drivers WHERE driver_id = $1',
        [driverId],
      );
      const d = row.rows[0];
      if (!d) {
        res.status(404).json({ error: 'Motorista nao encontrado.' });
        return;
      }
      res.json({ avatarUrl: d.avatar_url, truckPhotoUrl: d.truck_photo_url });
    } catch {
      res.status(500).json({ error: 'Erro ao buscar a foto.' });
    }
  }
}
