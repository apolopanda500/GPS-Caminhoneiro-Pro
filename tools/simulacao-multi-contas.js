// Simulação multi-contas: frota de N motoristas reais na rede V2X (produção)
// Uso: node tools/simulacao-multi-contas.js --contas 10 --motoristas-rota 6
const path = require('path');
const fs = require('fs');
const NO = path.join(__dirname, '..', 'backend-api', 'node_modules');
const { Client } = require(path.join(NO, 'pg'));
const { io } = require(path.join(NO, 'socket.io-client'));

const BASE = process.argv.includes('--url')
  ? process.argv[process.argv.indexOf('--url') + 1]
  : 'https://gps-truck-backend.onrender.com';

const argN = (nome, padrao) => {
  const i = process.argv.indexOf('--' + nome);
  return i >= 0 && process.argv[i + 1] ? parseInt(process.argv[i + 1], 10) : padrao;
};
const N = argN('contas', 10);
const NA_ROTA = argN('motoristas-rota', 6);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const semSsl = (u) => (/supabase\.com/i.test(u) ? u.replace(/[?&]sslmode=[^&]*/i, '') : u);
const env = fs.readFileSync(path.join(__dirname, '..', 'backend-api', '.env'), 'utf8');
const db = new Client({
  connectionString: semSsl(env.match(/^DATABASE_URL=([^ \r\n]+)/m)[1]),
  ssl: { rejectUnauthorized: false },
});

async function api(m, c, b, t) {
  const h = { 'Content-Type': 'application/json' };
  if (t) h.Authorization = 'Bearer ' + t;
  const r = await fetch(BASE + c, { method: m, headers: h, body: b ? JSON.stringify(b) : undefined });
  let d = {};
  try { d = await r.json(); } catch {}
  return { status: r.status, body: d };
}

const ROTAS = [
  { nome: 'BR-040 RJ->Juiz de Fora', pontos: [[-43.1729, -22.9068], [-43.32, -22.85], [-43.45, -22.8], [-43.6, -22.7], [-43.75, -22.6]] },
  { nome: 'Rodovia Niteroi-Itaipu', pontos: [[-43.104, -22.907], [-43.09, -22.9], [-43.07, -22.89], [-43.05, -22.885]] },
  { nome: 'Dutra proximo RJ', pontos: [[-43.35, -22.88], [-43.3, -22.87], [-43.25, -22.89], [-43.2, -22.91]] },
];

(async () => {
  console.log(`SIMULACAO MULTI-CONTAS | ${BASE} | ${N} contas (${NA_ROTA} na estrada)`);
  await db.connect();

  const st = await api('GET', '/status');
  console.log('status:', st.status, st.body.status, '| banco:', st.body.database || st.body.db);

  const frota = [];
  const base = Date.now().toString(36);
  for (let i = 0; i < N; i++) {
    const nome = `Motorista Frota ${i + 1} (${base})`;
    const email = `frota.${base}.${i}@bateria.local`;
    const reg = await api('POST', '/api/auth/register', { email, password: 'Frota2026!', name: nome });
    if (reg.status >= 500) { console.log(`registro ${i} falhou ${reg.status}`); continue; }
    let token = reg.body.token || '';
    let driverId = reg.body.driverId || '';
    if (!token) {
      let cod = null;
      for (let t = 0; t < 10 && !cod; t++) {
        await sleep(600);
        const c = await db.query('SELECT code FROM verification_codes WHERE email=$1 AND consumed=FALSE ORDER BY created_at DESC LIMIT 1', [email]);
        cod = c.rows[0] || null;
      }
      if (cod) {
        await api('POST', '/api/auth/verify', { email, code: cod.code });
        const lg = await api('POST', '/api/auth/login', { email, password: 'Frota2026!' });
        token = lg.body.token || ''; driverId = lg.body.driverId || driverId;
      }
    }
    if (token) frota.push({ idx: i, nome, email, driverId, token, socket: null, vistos: new Set(), chat: [], alertas: 0 });
  }
  console.log(`contas criadas/login ok: ${frota.length}/${N}`);

  const conectar = (u) => new Promise((resolve) => {
    u.socket = io(BASE, { transports: ['websocket'], auth: { token: u.token }, timeout: 20000 });
    u.socket.on('connect', resolve);
    u.socket.on('connect_error', () => resolve());
  });
  await Promise.all(frota.map(conectar));
  console.log('sockets conectados:', frota.filter((u) => u.socket.connected).length);

  for (const u of frota) {
    u.socket.emit('register_driver', { driverId: u.driverId, role: 'motorista' });
    u.socket.emit('join_truck_network', { driverId: u.driverId, name: u.nome, role: 'motorista', truckIcon: '🚚' });
    u.socket.on('trucks_radar_update', (lista) => {
      const arr = Array.isArray(lista) ? lista : (lista?.drivers || lista?.trucks || []);
      for (const d of arr) u.vistos.add(d.driverId || d.driver_id);
    });
    u.socket.on('receive_chat_message', (m) => u.chat.push(m));
    u.socket.on('chat_message', (m) => u.chat.push(m));
    u.socket.on('road_alerts', () => u.alertas++);
    u.socket.on('road_validation_alerts', () => u.alertas++);
  }
  await sleep(1500);

  const comboio = frota.slice(0, NA_ROTA);
  const rota = ROTAS[0];
  console.log(`comboio: ${comboio.length} caminhoes percorrendo ${rota.nome}`);

  for (let p = 0; p < rota.pontos.length; p++) {
    const [lon, lat] = rota.pontos[p];
    for (const u of comboio) {
      u.socket.emit('update_position', {
        driverId: u.driverId, lat: lat + u.idx * 0.001, lon: lon + u.idx * 0.001,
        speedKmh: 60 + u.idx, heading: 270,
      });
    }
    await sleep(700);
  }

  const emissor = frota[0];
  for (const u of frota.slice(1, 5)) {
    emissor.socket.emit('broadcast_chat_message', {
      driverId: emissor.driverId, driverName: emissor.nome,
      message: `Ola ${u.nome}, transito livre na ${rota.nome}`,
      lat: rota.pontos[2][1], lon: rota.pontos[2][0], targetDriverId: u.driverId,
    });
    await sleep(250);
  }
  emissor.socket.emit('broadcast_chat_message', {
    driverId: emissor.driverId, driverName: emissor.nome,
    message: 'Atencao comboio: radar movel no km 40 da BR-040',
    lat: rota.pontos[3][1], lon: rota.pontos[3][0],
  });
  await sleep(2500);

  const vistosGeral = Math.max(...frota.map((u) => u.vistos.size));
  const privados = frota.slice(1, 5).filter((u) => u.chat.length > 0).length;
  const geral = frota.filter((u) => u.chat.some((m) => /radar movel/.test(m.message || ''))).length;
  const alertasOk = frota.filter((u) => u.alertas > 0).length;

  for (const u of frota) { try { u.socket.close(); } catch {} }

  const dbiz = await db.query(
    `SELECT count(*)::int AS total, max(created_at) AS ultimovisto
       FROM drivers WHERE email LIKE 'frota.${base}.%@bateria.local'`);
  await db.end().catch(() => {});

  const notas = {
    contas: frota.length >= Math.ceil(N * 0.8),
    rede: vistosGeral >= Math.ceil(NA_ROTA * 0.8),
    privados: privados >= 3,
    chatGeral: geral >= 1,
    sinal: alertasOk >= 1,
    banco: dbiz.rows[0].total >= Math.ceil(N * 0.8),
  };
  console.log('='.repeat(50));
  console.log(`camioes vistos na rede (max por janela): ${vistosGeral}`);
  console.log(`chats privados recebidos: ${privados}/4 | chat geral: ${geral} | sinais recebidos: ${frota.filter((u) => u.alertas > 0).length}`);
  console.log(`no banco: ${dbiz.rows[0].total} contas (ultimo visto: ${dbiz.rows[0].ultimovisto})`);
  const ok = Object.values(notas).filter(Boolean).length;
  console.log(`NOTA SIMULACAO MULTI-CONTAS: ${ok}/6 ${ok === 6 ? 'PERFEITO' : JSON.stringify(notas)}`);
})();
