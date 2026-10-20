import { Request, Response } from 'express';
import { Client } from 'pg';

export class AlertController {
  constructor(private db: Client) {}

  async getNearby(req: Request, res: Response): Promise<void> {
    const { lon, lat, radius = 2000 } = req.query;
    if (!lon || !lat) {
      res.status(400).json({ error: 'Coordenadas lon e lat são obrigatórias.' });
      return;
    }

    try {
      const result = await this.db.query(
        `SELECT id::text, driver_id, alert_type, message, max_height_allowed, max_weight_allowed, ST_X(geom) as lon, ST_Y(geom) as lat, created_at, ST_Distance(geom::geography, ST_SetSRID(ST_MakePoint($1::numeric, $2::numeric), 4326)::geography) as distancia_m FROM road_alerts WHERE ST_DWithin(geom, ST_SetSRID(ST_MakePoint($1::numeric, $2::numeric), 4326)::geography, $3::int) AND (expires_at IS NULL OR expires_at > NOW()) ORDER BY created_at DESC`,
        [lon, lat, radius]
      );
      const sinais = result.rows.map((r) => ({ id: r.id, driverId: r.driver_id, type: r.alert_type, message: r.message, maxHeight: r.max_height_allowed, maxWeight: r.max_weight_allowed, lat: parseFloat(r.lat), lon: parseFloat(r.lon), distanciaM: Math.round(parseFloat(r.distancia_m)), timestamp: new Date(r.created_at).getTime(), })); res.json(sinais);
    } catch {
      res.status(500).json({ error: 'Erro ao buscar alertas próximos.' });
    }
  }

  async createAlert(req: Request, res: Response): Promise<void> {
    const { type, message, maxHeight, maxWeight, lon, lat } = req.body;
    const driverId = req.driverId;

    if (!driverId || !type || lon == null || lat == null) {
      res.status(400).json({ error: 'Campos obrigatórios faltando.' });
      return;
    }

    try {
      await this.db.query(
        `INSERT INTO road_alerts (driver_id, alert_type, message, max_height_allowed, max_weight_allowed, geom)
         VALUES ($1, $2, $3, $4, $5, ST_SetSRID(ST_MakePoint($6, $7), 4326))`,
        [driverId, type, message || '', maxHeight || null, maxWeight || null, lon, lat]
      );
      res.status(201).json({ success: true });
    } catch {
      res.status(500).json({ error: 'Erro ao salvar alerta.' });
    }
  }

  async getMessages(req: Request, res: Response): Promise<void> {
    const { lon, lat, radius = 5000 } = req.query;
    try {
      const result = await this.db.query(
        `SELECT id, driver_id, driver_name, message, ST_X(geom) as lon, ST_Y(geom) as lat, created_at
         FROM truck_messages
         WHERE ST_DWithin(geom, ST_SetSRID(ST_MakePoint($1::numeric, $2::numeric), 4326)::geography, $3::int)
         ORDER BY created_at DESC LIMIT 100`,
        [lon, lat, radius]
      );
      const sinais = result.rows.map((r) => ({ id: r.id, driverId: r.driver_id, type: r.alert_type, message: r.message, maxHeight: r.max_height_allowed, maxWeight: r.max_weight_allowed, lat: parseFloat(r.lat), lon: parseFloat(r.lon), distanciaM: Math.round(parseFloat(r.distancia_m)), timestamp: new Date(r.created_at).getTime(), })); res.json(sinais);
    } catch {
      res.status(500).json({ error: 'Erro ao buscar mensagens do chat.' });
    }
  }

  async createMessage(req: Request, res: Response): Promise<void> {
    const { driverName, message, lon, lat } = req.body;
    const driverId = req.driverId;
    if (!driverId || !driverName || !message || lon == null || lat == null) {
      res.status(400).json({ error: 'Campos obrigatórios faltando.' });
      return;
    }
    try {
      await this.db.query(
        `INSERT INTO truck_messages (driver_id, driver_name, message, geom)
         VALUES ($1, $2, $3, ST_SetSRID(ST_MakePoint($4, $5), 4326))`,
        [driverId, driverName, message, lon, lat]
      );
      res.status(201).json({ success: true });
    } catch {
      res.status(500).json({ error: 'Erro ao salvar mensagem.' });
    }
  }
}
