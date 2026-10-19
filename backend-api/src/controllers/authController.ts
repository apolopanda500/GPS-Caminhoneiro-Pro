import { Request, Response } from 'express';
import { Client } from 'pg';
import crypto from 'crypto';

export class AuthController {
  constructor(private db: Client) {}

  async register(req: Request, res: Response): Promise<void> {
    const { email, password, name, height, weight } = req.body;
    if (!email || !password) {
      res.status(400).json({ error: 'E-mail e senha são obrigatórios.' });
      return;
    }

    const hash = crypto.createHash('sha256').update(password).digest('hex');
    const id = 'drv_' + Math.random().toString(36).substring(2, 9);

    try {
      await this.db.query(
        'INSERT INTO drivers (driver_id, email, password_hash, name, truck_height, truck_weight) VALUES ($1, $2, $3, $4, $5, $6)',
        [id, email, hash, name || '', height || 4.40, weight || 45.00]
      );
      res.status(201).json({ success: true, driverId: id, name });
    } catch (err: any) {
      if (err.code === '23505') {
        res.status(400).json({ error: 'E-mail já cadastrado.' });
      } else {
        res.status(500).json({ error: 'Erro interno ao cadastrar.' });
      }
    }
  }

  async login(req: Request, res: Response): Promise<void> {
    const { email, password } = req.body;
    const hash = crypto.createHash('sha256').update(password).digest('hex');

    try {
      const result = await this.db.query(
        'SELECT driver_id, name, is_premium, avatar_url, truck_photo_url, truck_model, cargo_type FROM drivers WHERE email = $1 AND password_hash = $2',
        [email, hash]
      );
      if (result.rows.length === 0) {
        res.status(401).json({ error: 'E-mail ou senha inválidos.' });
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
      });
    } catch {
      res.status(500).json({ error: 'Erro interno ao fazer login.' });
    }
  }

  async updateProfile(req: Request, res: Response): Promise<void> {
    const { driverId, name, truckModel, cargoType, avatarUrl, truckPhotoUrl } = req.body;
    try {
      await this.db.query(
        `UPDATE drivers SET name = COALESCE($2, name), truck_model = COALESCE($3, truck_model),
          cargo_type = COALESCE($4, cargo_type), avatar_url = COALESCE($5, avatar_url),
          truck_photo_url = COALESCE($6, truck_photo_url) WHERE driver_id = $1`,
        [driverId, name, truckModel, cargoType, avatarUrl, truckPhotoUrl]
      );
      res.json({ success: true });
    } catch {
      res.status(500).json({ error: 'Erro ao atualizar perfil.' });
    }
  }
}
