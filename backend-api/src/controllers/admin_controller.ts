import { Request, Response } from 'express';
import { Client } from 'pg';
import { env } from '../config/env';

const TABLES = [
  'drivers',
  'road_alerts',
  'truck_messages',
  'travel_history',
  'driver_contacts',
  'payments',
];

/**
 * Backup do banco pela propria API (sem depender de job pago no Render).
 * Exige o ADMIN_TOKEN do servidor.
 */
export class AdminController {
  constructor(private db: Client) {}

  async backup(req: Request, res: Response): Promise<void> {
    const token = req.headers['x-admin-token'];
    if (!env.adminToken || token !== env.adminToken) {
      res.status(401).json({ error: 'Token de administrador invalido.' });
      return;
    }
    try {
      const dump: Record<string, unknown[]> = {};
      for (const table of TABLES) {
        try {
          const result = await this.db.query(`SELECT * FROM ${table}`);
          dump[table] = result.rows;
        } catch {
          dump[table] = [];
        }
      }
      res.json({ geradoEm: new Date().toISOString(), tabelas: dump });
    } catch {
      res.status(500).json({ error: 'Falha ao gerar o backup.' });
    }
  }

  async health(req: Request, res: Response): Promise<void> {
    const token = req.headers['x-admin-token'];
    if (!env.adminToken || token !== env.adminToken) {
      res.status(401).json({ error: 'Token de administrador invalido.' });
      return;
    }
    try {
      const r = await this.db.query(
        `SELECT table_name FROM information_schema.tables
         WHERE table_schema = 'public' ORDER BY table_name`,
      );
      const contagens: Record<string, number> = {};
      for (const row of r.rows) {
        const tabela = row.table_name as string;
        try {
          const c = await this.db.query(`SELECT COUNT(*)::int AS n FROM "${tabela}"`);
          contagens[tabela] = c.rows[0]?.n ?? 0;
        } catch {
          contagens[tabela] = -1;
        }
      }
      res.json({ ok: true, contagens });
    } catch {
      res.status(500).json({ error: 'Falha ao ler o banco.' });
    }
  }
}
