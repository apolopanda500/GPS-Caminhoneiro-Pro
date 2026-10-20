import { Request, Response } from 'express';
import { Client } from 'pg';
import { canSeeRoute } from '../utils/group_access';

const VALID_ROLES = new Set(['motorista', 'ajudante']);

export class GroupController {
  constructor(private readonly db: Client) {}

  async listForDriver(req: Request, res: Response): Promise<void> {
    const driverId = req.driverId || '';
    if (!driverId) {
      res.status(400).json({ error: 'driverId obrigatorio.' });
      return;
    }
    const result = await this.db.query(
      `SELECT g.id, g.name, g.owner_driver_id, g.is_public,
              (m.driver_id IS NOT NULL) AS is_member,
              (SELECT COUNT(*) FROM convoy_members c WHERE c.group_id = g.id) AS member_count
         FROM convoy_groups g
         LEFT JOIN convoy_members m
           ON m.group_id = g.id AND m.driver_id = $1
        ORDER BY m.joined_at DESC NULLS LAST, g.created_at DESC
        LIMIT 80`,
      [driverId],
    );
    res.json(result.rows);
  }

  async listMembers(req: Request, res: Response): Promise<void> {
    const groupId = req.params.id;
    const result = await this.db.query(
      `SELECT driver_id, role, joined_at FROM convoy_members WHERE group_id = $1 ORDER BY joined_at ASC LIMIT 200`,
      [groupId],
    );
    res.json(result.rows);
  }

  async create(req: Request, res: Response): Promise<void> {
    const { name, role, isPublic } = req.body;
    const driverId = req.driverId;
    if (!name || !driverId) {
      res.status(400).json({ error: 'name e driverId obrigatorios.' });
      return;
    }
    const clientRole = VALID_ROLES.has(role) ? role : 'motorista';
    try {
      const created = await this.db.query(
        `INSERT INTO convoy_groups (name, owner_driver_id, is_public)
         VALUES ($1, $2, $3) RETURNING id`,
        [String(name).slice(0, 80), driverId, isPublic === false ? false : true],
      );
      const groupId = created.rows[0].id;
      await this.db.query(
        `INSERT INTO convoy_members (group_id, driver_id, role) VALUES ($1, $2, $3)
         ON CONFLICT (group_id, driver_id) DO NOTHING`,
        [groupId, driverId, clientRole],
      );
      res.status(201).json({ success: true, id: groupId });
    } catch {
      res.status(500).json({ error: 'Falha ao criar o grupo.' });
    }
  }

  async join(req: Request, res: Response): Promise<void> {
    const groupId = req.params.id;
    const { role } = req.body;
    const driverId = req.driverId;
    if (!driverId) {
      res.status(400).json({ error: 'driverId obrigatorio.' });
      return;
    }
    const memberRole = VALID_ROLES.has(role) ? role : 'motorista';
    try {
      const exists = await this.db.query('SELECT 1 FROM convoy_groups WHERE id = $1', [groupId]);
      if (exists.rowCount === 0) {
        res.status(404).json({ error: 'Grupo nao encontrado.' });
        return;
      }
      await this.db.query(
        `INSERT INTO convoy_members (group_id, driver_id, role) VALUES ($1, $2, $3)
         ON CONFLICT (group_id, driver_id) DO UPDATE SET role = EXCLUDED.role`,
        [groupId, driverId, memberRole],
      );
      res.json({ success: true });
    } catch {
      res.status(500).json({ error: 'Falha ao entrar no grupo.' });
    }
  }

  async leave(req: Request, res: Response): Promise<void> {
    const groupId = req.params.id;
    const driverId = req.driverId;
    if (!driverId) {
      res.status(400).json({ error: 'driverId obrigatorio.' });
      return;
    }
    try {
      const owner = await this.db.query('SELECT owner_driver_id FROM convoy_groups WHERE id = $1', [groupId]);
      if (owner.rows[0]?.owner_driver_id === driverId) {
        await this.db.query('DELETE FROM convoy_groups WHERE id = $1', [groupId]);
        res.json({ success: true, deleted: true });
        return;
      }
      await this.db.query('DELETE FROM convoy_members WHERE group_id = $1 AND driver_id = $2', [groupId, driverId]);
      res.json({ success: true });
    } catch {
      res.status(500).json({ error: 'Falha ao sair do grupo.' });
    }
  }

  async shareRoute(req: Request, res: Response): Promise<void> {
    const groupId = req.params.id;
    const { driverName, payload, isPublic, role } = req.body;
    const driverId = req.driverId;
    if (!driverId || !payload) {
      res.status(400).json({ error: 'driverId e payload obrigatorios.' });
      return;
    }
    const memberRole = VALID_ROLES.has(role) ? role : 'motorista';
    try {
      const driver = await this.db.query(
        'SELECT role FROM drivers WHERE driver_id = $1',
        [driverId],
      );
      const dbRole = driver.rows[0]?.role ?? memberRole;
      if (dbRole === 'ajudante') {
        res.status(403).json({
          error: 'Ajudantes acompanham as rotas, mas nao montam nem iniciam.',
        });
        return;
      }
      const exists = await this.db.query('SELECT 1 FROM convoy_groups WHERE id = $1', [groupId]);
      if (exists.rowCount === 0) {
        res.status(404).json({ error: 'Grupo nao encontrado.' });
        return;
      }
      await this.db.query(
        `INSERT INTO convoy_members (group_id, driver_id, role) VALUES ($1, $2, $3)
         ON CONFLICT (group_id, driver_id) DO NOTHING`,
        [groupId, driverId, memberRole],
      );
      const inserted = await this.db.query(
        `INSERT INTO group_shared_routes (group_id, driver_id, driver_name, payload, is_public)
         VALUES ($1, $2, $3, $4, $5) RETURNING id`,
        [groupId, driverId, driverName || '', JSON.stringify(payload), isPublic === true],
      );
      res.status(201).json({ success: true, id: inserted.rows[0].id });
    } catch {
      res.status(500).json({ error: 'Falha ao compartilhar a rota.' });
    }
  }

  async listRoutes(req: Request, res: Response): Promise<void> {
    const groupId = req.params.id;
    const driverId = req.driverId || '';
    try {
      const group = await this.db.query('SELECT is_public FROM convoy_groups WHERE id = $1', [groupId]);
      if (group.rowCount === 0) {
        res.status(404).json({ error: 'Grupo nao encontrado.' });
        return;
      }
      let isMember = false;
      if (driverId) {
        const membership = await this.db.query(
          'SELECT 1 FROM convoy_members WHERE group_id = $1 AND driver_id = $2',
          [groupId, driverId],
        );
        isMember = (membership.rowCount ?? 0) > 0;
      }
      const rows = isMember
        ? await this.db.query(
            `SELECT * FROM group_shared_routes WHERE group_id = $1 AND created_at > NOW() - INTERVAL '7 days'
             ORDER BY created_at DESC LIMIT 80`,
            [groupId],
          )
        : await this.db.query(
            `SELECT * FROM group_shared_routes WHERE group_id = $1 AND is_public = TRUE
             AND created_at > NOW() - INTERVAL '7 days' ORDER BY created_at DESC LIMIT 50`,
            [groupId],
          );
      res.json(rows.rows.filter((r) => canSeeRoute(group.rows[0], r, isMember)));
    } catch {
      res.status(500).json({ error: 'Falha ao listar rotas do grupo.' });
    }
  }
}
