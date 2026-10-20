import express from 'express';
import { createServer } from 'http';
import { Server, Socket } from 'socket.io';
import cors from 'cors';
import { connectDatabase, db } from './config/database';
import { env } from './config/env';
import { verificarToken } from './utils/session';
import authRoutes from './routes/auth';
import alertRoutes from './routes/alerts';
import paymentRoutes from './routes/payment';
import groupRoutes from './routes/groups';

const app = express();
let dbConnected = false;
app.use(cors({ origin: env.frontendUrl }));
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/alerts', alertRoutes);
app.use('/api/payment', paymentRoutes);
app.use('/api/groups', groupRoutes);

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

// Cache simples do perfil do motorista (evita query a cada posicao).
const perfilCache = new Map<string, { dados: any; expira: number }>();
const PERFIL_TTL_MS = 60_000;

async function carregarPerfil(driverId: string): Promise<any> {
  const cached = perfilCache.get(driverId);
  const agora = Date.now();
  if (cached && cached.expira > agora) return cached.dados;
  const resultado = await db.query(
    'SELECT name, avatar_url, truck_photo_url, truck_model, cargo_type, role FROM drivers WHERE driver_id = $1',
    [driverId]
  );
  const dados = resultado.rows[0] || {};
  perfilCache.set(driverId, { dados, expira: agora + PERFIL_TTL_MS });
  return dados;
}

io.on('connection', (socket: Socket) => {
  console.log(`🚚 Caminhão conectado via Socket.io: ${socket.id}`);

  // Token de sessao (opcional no handshake): quando vem, vira a identidade real.
  const tokenSocket =
    (socket.handshake.auth && (socket.handshake.auth as any).token) ||
    socket.handshake.headers['x-gps-token'];
  const sessao = verificarToken(
    typeof tokenSocket === 'string' ? tokenSocket : undefined,
  );
  if (sessao) {
    socket.data.driverId = sessao.driverId;
  }

  socket.on('join_truck_network', async (data: { driverId: string; name: string; truckIcon?: string; role?: string }) => {
    // Se veio token, a identidade do token manda.
    const driverId = (socket.data.driverId as string) || data.driverId;
    activeTrucksNetwork.set(socket.id, {
      socketId: socket.id,
      driverId,
      name: data.name,
      lat: 0,
      lon: 0,
      role: data.role || 'motorista',
      truckIcon: data.truckIcon || '🚚',
    });
    // Carrega o perfil (foto, avatar, modelo) para os peers ja mostrarem.
    try {
      const p = await carregarPerfil(driverId);
      const truck = activeTrucksNetwork.get(socket.id);
      if (p && truck) {
        truck.name = p.name || truck.name;
        truck.avatarUrl = p.avatar_url;
        truck.truckPhotoUrl = p.truck_photo_url;
        truck.truckModel = p.truck_model;
        truck.cargoType = p.cargo_type;
        if (p.role) truck.role = p.role;
      }
    } catch { console.error('Erro ao carregar perfil na entrada.'); }
    console.log(`📡 ${data.name} entrou na rede V2X.`);
  });

  socket.on('register_driver', (data: { driverId: string; isPremium?: boolean; role?: string }) => {
    const truck = activeTrucksNetwork.get(socket.id);
    if (truck) {
      truck.driverId = (socket.data.driverId as string) || data.driverId;
      if (data.role) truck.role = data.role;
    }
  });

  socket.on('update_position', async (coords: { lat: number; lon: number; driverId: string; speedKmh?: number }) => {
    const driverId = (socket.data.driverId as string) || coords.driverId;
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
      const p = await carregarPerfil(driverId);
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
    const driverId = (socket.data.driverId as string) || alert.driverId;
    try {
      await db.query(
        `INSERT INTO road_alerts (driver_id, alert_type, message, max_height_allowed, max_weight_allowed, geom)
         VALUES ($1, $2, $3, $4, $5, ST_SetSRID(ST_MakePoint($6, $7), 4326))`,
        [driverId, alert.type, alert.message || '', alert.maxHeight || null, alert.maxWeight || null, alert.lon, alert.lat]
      );
      io.emit('receive_alert_realtime', { ...alert, driverId, id: Math.random().toString(36).substring(2, 9), timestamp: Date.now() });
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

  socket.on('share_route', async (data: {
    fromDriverId: string;
    fromName: string;
    routeJson: string;
    targetDriverId?: string;
    groupId?: string;
    speedKmh?: number;
    role?: string;
  }) => {
    if (!data?.routeJson) return;
    const fromDriverId = (socket.data.driverId as string) || data.fromDriverId;
    try {
      const driver = await db.query(
        'SELECT role FROM drivers WHERE driver_id = $1',
        [fromDriverId],
      );
      const role = driver.rows[0]?.role ?? data.role ?? 'motorista';
      if (role === 'ajudante') {
        socket.emit('route_share_error', {
          error: 'Ajudantes acompanham as rotas, mas nao montam nem iniciam.',
        });
        return;
      }
    } catch {
      // sem permissao de leitura, segue com o papel informado pelo cliente
    }
    const payload = {
      ...data,
      timestamp: Date.now(),
    };
    if (data.groupId) {
      console.log(`📡 Rota compartilhada no grupo ${data.groupId}`);
      io.to(`group:${data.groupId}`).emit('receive_shared_route', payload);
      return;
    }
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

  socket.on('join_group', async (data: { groupId: string; driverId: string }) => {
    if (!data?.groupId) return;
    try {
      const member = await db.query(
        'SELECT 1 FROM convoy_members WHERE group_id = $1 AND driver_id = $2',
        [data.groupId, data.driverId || '']
      );
      const isMember = (member.rowCount ?? 0) > 0;
      const group = await db.query('SELECT is_public, owner_driver_id FROM convoy_groups WHERE id = $1', [data.groupId]);
      const g = group.rows[0];
      const allowed = isMember || (g && (g.is_public || g.owner_driver_id === data.driverId));
      if (!allowed) return;
      socket.join(`group:${data.groupId}`);
      socket.emit('group_joined', { groupId: data.groupId, ok: true });
    } catch { console.error('Erro ao entrar no grupo (socket).'); }
  });

  socket.on('leave_group', (data: { groupId: string }) => {
    if (data?.groupId) socket.leave(`group:${data.groupId}`);
  });

  socket.on('send_group_invite', (data: {
    groupId: string;
    groupName: string;
    fromDriverId: string;
    fromName: string;
    targetDriverId: string;
  }) => {
    if (!data?.groupId || !data?.targetDriverId) return;
    const targets = Array.from(activeTrucksNetwork.values()).filter(t => t.driverId === data.targetDriverId);
    targets.forEach(t => io.to(t.socketId).emit('receive_group_invite', {
      groupId: data.groupId,
      groupName: data.groupName,
      fromName: data.fromName,
      timestamp: Date.now(),
    }));
  });

  socket.on('clear_alert', async (data: { alertId: string; driverId: string }) => {
    if (!data?.alertId || !data?.driverId) return;
    try {
      const res = await db.query('DELETE FROM road_alerts WHERE id::text = $1 AND driver_id = $2', [data.alertId, data.driverId]);
      if ((res.rowCount ?? 0) > 0) {
        io.emit('alert_removed', { alertId: data.alertId, driverId: data.driverId });
      }
    } catch { console.error('Erro ao apagar alerta.'); }
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
