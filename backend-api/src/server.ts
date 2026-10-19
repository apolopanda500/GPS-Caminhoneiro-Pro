import express from 'express';
import { createServer } from 'http';
import { Server, Socket } from 'socket.io';
import cors from 'cors';
import { connectDatabase, db } from './config/database';
import { env } from './config/env';
import authRoutes from './routes/auth';
import alertRoutes from './routes/alerts';
import paymentRoutes from './routes/payment';

const app = express();
let dbConnected = false;
app.use(cors({ origin: env.frontendUrl }));
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/alerts', alertRoutes);
app.use('/api/payment', paymentRoutes);

app.get('/', (_req, res) => {
  res.json({
    name: 'GPS Caminhoneiro Pro API',
    version: '1.0.0',
    endpoints: [
      'POST /api/auth/register',
      'POST /api/auth/login',
      'POST /api/auth/profile',
      'GET  /api/alerts/nearby?lon=&lat=&radius=',
      'POST /api/alerts',
      'GET  /api/alerts/messages?lon=&lat=&radius=',
      'POST /api/alerts/messages',
      'POST /api/payment/pix',
      'POST /api/payment/confirm',
    ],
  });
});

app.get('/status', (_req, res) => {
  res.json({
    status: 'online',
    database: dbConnected ? 'connected' : 'disconnected',
    active_trucks: activeTrucksNetwork.size,
    timestamp: new Date().toISOString(),
  });
});

const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: { origin: env.frontendUrl, methods: ['GET', 'POST'] },
  pingTimeout: 60000,
  pingInterval: 25000,
});

interface ActiveTruck {
  socketId: string;
  driverId: string;
  name: string;
  lat: number;
  lon: number;
  speedKmh?: number;
  role?: string;
  avatarUrl?: string;
  truckPhotoUrl?: string;
  truckModel?: string;
  cargoType?: string;
  truckIcon?: string;
}

const activeTrucksNetwork = new Map<string, ActiveTruck>();

io.on('connection', (socket: Socket) => {
  console.log(`🚚 Caminhão conectado via Socket.io: ${socket.id}`);

  socket.on('join_truck_network', (data: { driverId: string; name: string; truckIcon?: string; role?: string }) => {
    activeTrucksNetwork.set(socket.id, {
      socketId: socket.id,
      driverId: data.driverId,
      name: data.name,
      lat: 0,
      lon: 0,
      role: data.role || 'motorista',
      truckIcon: data.truckIcon || '🚚',
    });
    console.log(`📡 ${data.name} entrou na rede V2X.`);
  });

  socket.on('register_driver', (data: { driverId: string; isPremium?: boolean; role?: string }) => {
    const truck = activeTrucksNetwork.get(socket.id);
    if (truck) {
      truck.driverId = data.driverId;
      if (data.role) truck.role = data.role;
    }
  });

  socket.on('update_position', async (coords: { lat: number; lon: number; driverId: string; speedKmh?: number }) => {
    const truck = activeTrucksNetwork.get(socket.id);
    if (truck) {
      truck.lat = coords.lat;
      truck.lon = coords.lon;
      if (typeof coords.speedKmh === 'number') truck.speedKmh = coords.speedKmh;
    }

    try {
      const scan = await db.query('SELECT * FROM verify_road_safety($1, $2, 2000)', [coords.lon, coords.lat]);
      if (scan.rows.length > 0) {
        socket.emit('road_validation_alerts', scan.rows);
      }
    } catch { console.error('Erro varredura.'); }

    try {
      const profile = await db.query(
        'SELECT name, avatar_url, truck_photo_url, truck_model, cargo_type, role FROM drivers WHERE driver_id = $1',
        [coords.driverId]
      );
      const p = profile.rows[0] || {};
      if (truck) {
        truck.name = p.name || truck.name;
        truck.avatarUrl = p.avatar_url;
        truck.truckPhotoUrl = p.truck_photo_url;
        truck.truckModel = p.truck_model;
        truck.cargoType = p.cargo_type;
        if (p.role) truck.role = p.role;
      }

      const allTrucks = Array.from(activeTrucksNetwork.values()).map(t => ({
        driverId: t.driverId,
        name: t.name,
        lat: t.lat,
        lon: t.lon,
        speedKmh: t.speedKmh ?? 0,
        role: t.role || 'motorista',
        avatarUrl: t.avatarUrl || p.avatar_url || null,
        truckPhotoUrl: t.truckPhotoUrl || p.truck_photo_url || null,
        truckModel: t.truckModel || p.truck_model || null,
        cargoType: t.cargoType || p.cargo_type || null,
        truckIcon: t.truckIcon || '🚚',
      }));
      io.emit('trucks_radar_update', allTrucks);
    } catch { console.error('Erro ao carregar perfil.'); }
  });

  socket.on('send_road_alert', async (alert: any) => {
    try {
      await db.query(
        `INSERT INTO road_alerts (driver_id, alert_type, message, max_height_allowed, max_weight_allowed, geom)
         VALUES ($1, $2, $3, $4, $5, ST_SetSRID(ST_MakePoint($6, $7), 4326))`,
        [alert.driverId, alert.type, alert.message || '', alert.maxHeight || null, alert.maxWeight || null, alert.lon, alert.lat]
      );
      io.emit('receive_alert_realtime', { ...alert, id: Math.random().toString(36).substring(2, 9), timestamp: Date.now() });
    } catch { console.error('Erro salvar alerta.'); }
  });

  socket.on('send_peer_alert', (data: {
    fromDriverId: string;
    fromName: string;
    targetDriverId: string;
    kind: 'signal' | 'vibration' | 'call' | string;
    message?: string;
    timestamp?: number;
  }) => {
    if (!data?.targetDriverId) return;
    io.emit('receive_peer_alert', {
      ...data,
      timestamp: data.timestamp || Date.now(),
    });
  });

  socket.on('share_route', (data: {
    fromDriverId: string;
    fromName: string;
    routeJson: string;
    targetDriverId?: string;
    speedKmh?: number;
    role?: string;
  }) => {
    if (!data?.routeJson) return;
    io.emit('receive_shared_route', {
      ...data,
      timestamp: Date.now(),
    });
  });

  socket.on('share_place', (data: {
    fromDriverId: string;
    fromName: string;
    label: string;
    type?: string;
    lat: number;
    lon: number;
    targetDriverId?: string;
  }) => {
    if (!data?.label || data.lat == null || data.lon == null) return;
    io.emit('receive_shared_place', {
      ...data,
      timestamp: Date.now(),
    });
  });

  socket.on('broadcast_chat_message', async (msgData: { driverName: string; message: string; lat: number; lon: number; driverId?: string; targetDriverId?: string }) => {
    try {
      if (msgData.driverId) {
        await db.query(
          `INSERT INTO truck_messages (driver_id, driver_name, message, geom)
           VALUES ($1, $2, $3, ST_SetSRID(ST_MakePoint($4, $5), 4326))`,
          [msgData.driverId, msgData.driverName, msgData.message, msgData.lon, msgData.lat]
        );
      }
    } catch { console.error('Erro salvar mensagem no banco.'); }
    const payload = {
      driverName: msgData.driverName,
      message: msgData.message,
      targetDriverId: msgData.targetDriverId || null,
      private: Boolean(msgData.targetDriverId),
      timestamp: Date.now(),
    };
    if (msgData.targetDriverId) {
      const targets = Array.from(activeTrucksNetwork.values())
        .filter(t => t.driverId === msgData.targetDriverId || t.driverId === msgData.driverId);
      targets.forEach(t => io.to(t.socketId).emit('receive_chat_message', payload));
      if (targets.length === 0) socket.emit('receive_chat_message', payload);
      return;
    }
    io.emit('receive_chat_message', payload);
  });

  socket.on('send_truck_reaction', (reactionData: { fromName: string; targetDriverId: string; emoji: string }) => {
    io.emit('receive_truck_reaction', reactionData);
  });

  socket.on('disconnect', () => {
    activeTrucksNetwork.delete(socket.id);
    const allTrucks = Array.from(activeTrucksNetwork.values());
    io.emit('trucks_radar_update', allTrucks);
    console.log(`❌ Caminhão desconectado: ${socket.id}`);
  });
});

connectDatabase().then(() => {
  dbConnected = true;
  httpServer.listen(env.port, () => {
    console.log(`🚀 Servidor GPS Caminhoneiro Pro rodando na porta ${env.port}`);
  });
});

process.on('SIGTERM', () => {
  console.log('👋 Encerrando (SIGTERM)...');
  httpServer.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 5000).unref();
});
