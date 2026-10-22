import express from 'express';
import { createServer } from 'http';
import crypto from 'crypto';
import { Server, Socket } from 'socket.io';
import cors from 'cors';
import { connectDatabase, db } from './config/database';
import { env } from './config/env';
import { verificarToken } from './utils/session';
import authRoutes from './routes/auth';
import alertRoutes from './routes/alerts';
import paymentRoutes from './routes/payment';
import groupRoutes from './routes/groups';
import assistantRoutes from './routes/assistant';
import adminRoutes from './routes/admin';

const app = express();
let dbConnected = false;
app.use(cors({ origin: env.frontendUrl }));
app.use(express.json({ limit: '8mb' }));

app.use('/api/auth', authRoutes);
app.use('/api/alerts', alertRoutes);
app.use('/api/payment', paymentRoutes);
app.use('/api/groups', groupRoutes);
app.use('/api/assistant', assistantRoutes);
app.use('/api/admin', adminRoutes);

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

/**
 * Rotas compartilhadas em tempo real.
 *
 * Cada rota compartilhada tem um `shareId` (o proprio id da linha em
 * `group_shared_routes`). Quem acompanha ("seguir") recebe o estado da rota e
 * as atualizacoes de cada parada (chegou / entregou) em tempo real.
 */
interface SharedRouteState {
  shareId: string;
  groupId?: string;
  ownerDriverId: string;
  ownerSocketId: string;
  ownerName: string;
  routeJson: string;
  stops: any[];
  seguidores: Set<string>;
  atualizadoEm: number;
}
const sharedRoutes = new Map<string, SharedRouteState>();

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

    // Envia os sinais ja existentes nas proximidades para o motorista que
    // acabou de entrar (antes disso ele so via sinais novos em tempo real).
    try {
      const truck = activeTrucksNetwork.get(socket.id);
      if (truck && truck.lat !== 0 && truck.lon !== 0) {
        const scan = await db.query(
          'SELECT * FROM verify_road_safety($1, $2, 5000)',
          [truck.lon, truck.lat]
        );
        if (scan.rows.length > 0) socket.emit('road_validation_alerts', scan.rows);
      }
    } catch { console.error('Erro ao buscar sinais na entrada.'); }
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
      const resultado = await db.query(
        `INSERT INTO road_alerts (driver_id, alert_type, message, max_height_allowed, max_weight_allowed, geom)
         VALUES ($1, $2, $3, $4, $5, ST_SetSRID(ST_MakePoint($6, $7), 4326))
         RETURNING id, created_at`,
        [driverId, alert.type, alert.message || '', alert.maxHeight || null, alert.maxWeight || null, alert.lon, alert.lat]
      );
      const registro = resultado.rows[0];
      io.emit('receive_alert_realtime', {
        ...alert,
        driverId,
        id: registro.id,
        timestamp: new Date(registro.created_at).getTime(),
      });
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
    shareId?: string;
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

    // As paradas vao junto para o mapa do outro motorista (linha + status).
    let stops: any[] = [];
    try {
      const parsed = JSON.parse(data.routeJson);
      if (parsed && Array.isArray(parsed.stops)) stops = parsed.stops;
    } catch {
      stops = [];
    }
    // O id da rota compartilhada e um UUID (a coluna do banco e uuid).
    const shareId =
      data.shareId && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(data.shareId)
        ? data.shareId
        : crypto.randomUUID();

    const estado: SharedRouteState = {
      shareId,
      groupId: data.groupId,
      ownerDriverId: fromDriverId,
      ownerSocketId: socket.id,
      ownerName: data.fromName || '',
      routeJson: data.routeJson,
      stops,
      seguidores: new Set<string>(),
      atualizadoEm: Date.now(),
    };
    sharedRoutes.set(shareId, estado);

    const payload = {
      ...data,
      shareId,
      fromDriverId,
      stops,
      timestamp: Date.now(),
    };

    if (data.groupId) {
      console.log(`📡 Rota compartilhada no grupo ${data.groupId} (${shareId})`);
      // Guarda a rota no historico do grupo (a lista do comboio).
      try {
        await db.query(
          `INSERT INTO group_shared_routes (id, group_id, driver_id, driver_name, payload, is_public)
           VALUES ($1::uuid, $2, $3, $4, $5::jsonb, FALSE)
           ON CONFLICT (id) DO UPDATE SET payload = EXCLUDED.payload`,
          [
            shareId,
            data.groupId,
            fromDriverId,
            data.fromName || '',
            JSON.stringify({ routeJson: data.routeJson, stops, progress: {} }),
          ],
        );
      } catch (e) {
        console.error('Erro ao salvar a rota no grupo.');
      }
      io.to(`group:${data.groupId}`).emit('receive_shared_route', payload);
      return;
    }
    io.emit('receive_shared_route', payload);
  });

  /** Acompanha a rota de outro motorista (linha + paradas ao vivo). */
  socket.on('follow_route', (data: { shareId: string; driverId?: string; name?: string }) => {
    const shareId = data?.shareId;
    if (!shareId) return;
    const rota = sharedRoutes.get(shareId);
    if (!rota) {
      socket.emit('route_follow_error', { shareId, error: 'Rota compartilhada nao esta mais no ar.' });
      return;
    }
    rota.seguidores.add(socket.id);
    // O seguidor recebe a rota completa para desenhar no mapa.
    socket.emit('route_shared_state', {
      shareId,
      groupId: rota.groupId,
      ownerDriverId: rota.ownerDriverId,
      ownerName: rota.ownerName,
      routeJson: rota.routeJson,
      stops: rota.stops,
      timestamp: Date.now(),
    });
    // E o dono da rota sabe que alguem esta acompanhando.
    io.to(rota.ownerSocketId).emit('route_follower_joined', {
      shareId,
      followerDriverId: (socket.data.driverId as string) || data.driverId,
      followerName: data.name || '',
      timestamp: Date.now(),
    });
  });

  socket.on('unfollow_route', (data: { shareId: string }) => {
    const rota = sharedRoutes.get(data?.shareId || '');
    rota?.seguidores.delete(socket.id);
  });

  /**
   * Progresso de uma parada da rota compartilhada (chegou/entregou).
   * O dono da rota avisa; o servidor repassa para quem acompanha e para o grupo.
   */
  socket.on('route_progress', async (data: {
    shareId: string;
    stopIndex: number;
    status: string;
    lat?: number;
    lon?: number;
    driverId?: string;
    driverName?: string;
  }) => {
    const shareId = data?.shareId;
    if (!shareId) return;
    const rota = sharedRoutes.get(shareId);
    const driverId = (socket.data.driverId as string) || data.driverId;
    const payload = {
      shareId,
      stopIndex: Number(data.stopIndex ?? -1),
      status: data.status || 'pendente',
      lat: data.lat,
      lon: data.lon,
      driverId,
      driverName: data.driverName || rota?.ownerName || '',
      timestamp: Date.now(),
    };
    if (rota) {
      rota.atualizadoEm = Date.now();
      rota.seguidores.forEach((sid) => io.to(sid).emit('route_progress', payload));
      if (rota.groupId) io.to(`group:${rota.groupId}`).emit('route_progress', payload);
      // Guarda o estado da parada para quem abrir o grupo depois.
      try {
        const atual = await db.query(
          'SELECT payload FROM group_shared_routes WHERE id = $1::uuid',
          [shareId],
        );
        if (atual.rows[0]?.payload) {
          const p = atual.rows[0].payload || {};
          const progresso = { ...(p.progress || {}) };
          progresso[String(payload.stopIndex)] = payload.status;
          await db.query(
            'UPDATE group_shared_routes SET payload = jsonb_set(payload, $2, $3::jsonb) WHERE id = $1::uuid',
            [shareId, '{progress}', JSON.stringify(progresso)],
          );
        }
      } catch {
        console.error('Erro ao salvar o progresso da rota.');
      }
    } else {
      socket.emit('route_progress', payload);
    }
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

  // Remove sinais expirados (raio de 12h) de tempos em tempos para a tabela
  // nao crescer e a varredura de proximidade continuar rapida.
  const limparExpirados = async () => {
    try {
      const res = await db.query(
        'DELETE FROM road_alerts WHERE expires_at IS NOT NULL AND expires_at < NOW()'
      );
      if ((res.rowCount ?? 0) > 0) {
        console.log(`🧹 ${res.rowCount} sinais expirados removidos.`);
      }
    } catch { console.error('Erro ao limpar sinais expirados.'); }
  };
  setInterval(limparExpirados, 10 * 60 * 1000).unref();
});

process.on('SIGTERM', () => {
  console.log('👋 Encerrando (SIGTERM)...');
  httpServer.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 5000).unref();
});
