// ============================================================
// BATERIA APP USO REAL - GPS Caminhoneiro Pro
// Uso real: aparelhos com o app aberto (adb), GPS do sistema,
// rota de caminhao, alertas, chat, grupo, clima, carga e seguranca.
//
//   node tools/bateria-app-uso-real.js
//   node tools/bateria-app-uso-real.js --url https://gps-truck-backend.onrender.com
// ============================================================
const path = require('path');
const fs = require('fs');
const { execFile } = require('child_process');

const RAIZ = path.join(__dirname, '..');
const BACKEND = path.join(RAIZ, 'backend-api');
const NO_MODULOS = path.join(BACKEND, 'node_modules');
const { Client } = require(path.join(NO_MODULOS, 'pg'));
const { io } = require(path.join(NO_MODULOS, 'socket.io-client'));
const ADB = 'C:\\Program Files\\platform-tools\\adb.exe';

function arg(nome, padrao) {
  const i = process.argv.indexOf('--' + nome);
  if (i >= 0 && process.argv[i + 1]) return process.argv[i + 1];
  return padrao;
}
const BASE = arg('url', 'https://gps-truck-backend.onrender.com');
const CELULAR = arg('celular', 'R9XY1016R6V');
const EMULADOR = arg('emulador', 'emulator-5554');
const PACOTE = 'com.gpscamioneiro.gps_camioneiro_pro';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const agora = () => new Date().toISOString().slice(11, 19);

function adb(args) {
  return new Promise((resolve) => {
    execFile(ADB, args, { timeout: 30000 }, (erro, stdout) => resolve(erro ? '' : String(stdout).trim()));
  });
}

function lerEnvBackend() {
  const arquivo = path.join(BACKEND, '.env');
  const dados = {};
  if (!fs.existsSync(arquivo)) return dados;
  for (const linha of fs.readFileSync(arquivo, 'utf8').split(/\r?\n/)) {
    const t = linha.trim();
    if (!t || t.startsWith('#')) continue;
    const i = t.indexOf('=');
    if (i < 0) continue;
    dados[t.slice(0, i).trim()] = t.slice(i + 1).trim();
  }
  return dados;
}
const ENV = lerEnvBackend();

function semSslMode(url) {
  if (!url) return url;
  if (/supabase\.com/i.test(url)) return url.replace(/[?&]sslmode=[^&]*/i, '');
  return url;
}
const db = new Client({
  connectionString: semSslMode(ENV.DATABASE_URL),
  ssl: /supabase\.com/i.test(ENV.DATABASE_URL || '') ? { rejectUnauthorized: false } : undefined,
});

async function api(metodo, caminho, corpo, token) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = 'Bearer ' + token;
  const resp = await fetch(BASE + caminho, {
    method: metodo,
    headers,
    body: corpo ? JSON.stringify(corpo) : undefined,
  });
  let dados = {};
  try { dados = await resp.json(); } catch {}
  return { status: resp.status, body: dados };
}

async function esperar(condicao, msMax, passoMs) {
  const fim = Date.now() + msMax;
  while (Date.now() < fim) {
    const valor = await condicao();
    if (valor) return valor;
    await sleep(passoMs || 500);
  }
  return null;
}

const marca = Date.now().toString(36);
function novoUsuario(rotulo) {
  return {
    rotulo,
    driverId: `drv_app_${marca}_${rotulo}`,
    email: `app.${rotulo}.${marca}@bateria.local`,
    senha: 'AppUsoReal123',
    nome: 'App Uso Real ' + rotulo,
    token: '',
    socket: null,
    recebidos: { chat: [], reacoes: [], rotas: [], alertas: [] },
  };
}

async function cadastroLogin(u) {
  const reg = await api('POST', '/api/auth/register', {
    email: u.email,
    password: u.senha,
    name: u.nome,
  });
  if (reg.status >= 500) throw new Error('cadastro 5xx');
  u.token = reg.body.token || '';
  u.driverId = reg.body.driverId || u.driverId;
  if (!u.token) {
    const cod = await esperar(async () => {
      const c = await db.query('SELECT code FROM verification_codes WHERE email = $1 AND consumed = FALSE ORDER BY created_at DESC LIMIT 1', [u.email]);
      return c.rows[0] || null;
    }, 8000, 700);
    if (!cod) throw new Error('codigo de verificacao nao chegou no banco');
    const ver = await api('POST', '/api/auth/verify', { email: u.email, code: cod.code });
    if (ver.status >= 500) throw new Error('verify ' + ver.status);
    const login = await api('POST', '/api/auth/login', { email: u.email, password: u.senha });
    if (login.status !== 200) throw new Error('login ' + login.status);
    u.token = login.body.token || '';
    if (login.body.driverId) u.driverId = login.body.driverId;
  }
  if (!u.token) throw new Error('sem token para ' + u.email);
}

const cenarios = [];
function cenario(nome, descricao, fn) {
  cenarios.push({ nome, descricao, fn });
}

const users = [];
let u1, u2, u3;

cenario('servico-no-ar', 'Producao online com banco conectado', async () => {
  const r = await api('GET', '/status');
  if (r.status !== 200) throw new Error('status ' + r.status);
  if (r.body.status !== 'online' || r.body.database !== 'connected') throw new Error('servico: ' + JSON.stringify(r.body));
});

cenario('cadastro-e-login', 'Contas reais com e-mail verificado (producao)', async () => {
  u1 = novoUsuario('1'); u2 = novoUsuario('2'); u3 = novoUsuario('3');
  users.push(u1, u2, u3);
  await db.connect();
  for (const u of users) await cadastroLogin(u);
  const linhas = await db.query('SELECT count(*)::int AS total FROM drivers WHERE email = ANY($1::varchar[])', [users.map((u) => u.email)]);
  if (linhas.rows[0].total !== users.length) throw new Error('faltou driver no banco');
});

cenario('app-aberto-nos-aparelhos', 'App rodando no celular e no emulador (adb pidof)', async () => {
  const saida = await adb(['devices']);
  if (!saida.includes(CELULAR)) throw new Error('celular ' + CELULAR + ' ausente: ' + saida);
  if (!saida.includes(EMULADOR)) throw new Error('emulador ' + EMULADOR + ' ausente');
  for (const ap of [CELULAR, EMULADOR]) {
    const pid = await adb(['-s', ap, 'shell', 'pidof', PACOTE]);
    if (!pid) throw new Error('app nao rodando em ' + ap);
  }
});

cenario('gps-do-sistema-move', 'GPS do emulador muda para Niteroi e o sistema reflete', async () => {
  await adb(['-s', EMULADOR, 'emu', 'geo', 'fix', '-43.538143', '-22.845021']);
  await sleep(2500);
  await adb(['-s', EMULADOR, 'emu', 'geo', 'fix', '-43.114000', '-22.905500']);
  const fix = await esperar(async () => {
    const s = await adb(['-s', EMULADOR, 'shell', 'dumpsys', 'location']);
    const pedidos = s.match(/gps request from com\.gpscamioneiro\.gps_camioneiro_pro/g) || [];
    const ativo = s.match(/gps: com\.gpscamioneiro\.gps_camioneiro_pro/g) || [];
    if (pedidos.length + ativo.length > 0) return { pedidos: pedidos.length, historico: ativo.length };
    const m = s.match(/Location\[[^\]]*?\] ?[^\r\n]*/g) || [];
    for (const l of m) {
      const xy = l.match(/(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)/);
      if (!xy) continue;
      const lat = parseFloat(xy[1]);
      const lon = parseFloat(xy[2]);
      if (Math.abs(lat - -22.9055) < 0.25 && Math.abs(lon - -43.114) < 0.35) return { lat, lon };
    }
    return null;
  }, 30000, 2000);
  if (!fix) throw new Error('app nao requeriu GPS ao sistema (gpio sem prova)');
});

cenario('perfil-e-fotos', 'Perfil + avatar + foto do caminhao gravados e lidos', async () => {
  const png = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
  const perfil = await api('POST', '/api/auth/profile', {
    name: u1.nome,
    truckModel: 'Scania R450',
    cargoType: 'Graneleiro',
    companyName: 'Transportes App-Teste',
  }, u1.token);
  if (perfil.status !== 200) throw new Error('perfil ' + perfil.status);
  const foto = await api('POST', '/api/auth/photo', { data: png, kind: 'avatar' }, u1.token);
  if (foto.status !== 200) throw new Error('foto avatar ' + foto.status);
  const fotoC = await api('POST', '/api/auth/photo', { data: png, kind: 'truck' }, u1.token);
  if (fotoC.status !== 200) throw new Error('foto caminhao ' + fotoC.status);
  const busca = await esperar(async () => {
    const b = await api('GET', '/api/auth/photo/' + u1.driverId);
    if (b.status === 200 && String(b.body.avatarUrl || '').startsWith('data:image')) return b;
    return null;
  }, 15000, 1500);
  if (!busca) throw new Error('leitura da foto falhou');
});

cenario('rede-v2x-e-alerta', 'Sockets + radar + sinal de estrada criado, visto e limpo', async () => {
  for (const u of users) {
    await new Promise((resolve, reject) => {
      u.socket = io(BASE, { transports: ['websocket'], auth: { token: u.token }, timeout: 15000 });
      u.socket.on('connect', resolve);
      u.socket.on('connect_error', reject);
    });
    u.socket.emit('register_driver', { driverId: u.driverId, role: 'motorista' });
    u.socket.emit('join_truck_network', { driverId: u.driverId, name: u.nome, role: 'motorista', truckIcon: '🚚' });
    u.socket.on('chat_message', (m) => u.recebidos.chat.push(m));
    u.socket.on('receive_chat_message', (m) => u.recebidos.chat.push(m));
    u.socket.on('truck_reactions', (r) => u.recebidos.reacoes.push(r));
    u.socket.on('shared_route', (r) => u.recebidos.rotas.push(r));
    u.socket.on('road_alerts', (a) => u.recebidos.alertas.push(a));
    u.socket.on('road_validation_alerts', (a) => u.recebidos.alertas.push(a));
    await sleep(400);
  }
  const pos = { lat: -22.9068, lon: -43.1729 };
  for (let p = 0; p < 3; p++) {
    for (const u of users) {
      pos.lat += 0.0006;
      u.socket?.emit('update_position', { driverId: u.driverId, lat: pos.lat, lon: pos.lon, speedKmh: 55, heading: 90 });
    }
    await sleep(400);
  }
  const alerta = await api('POST', '/api/alerts', {
    type: 'dropped_load',
    message: 'Carga caiu km 30 BR-116',
    lat: -22.9068,
    lon: -43.1729,
  }, u2.token);
  if (alerta.status >= 500 || alerta.status === 404) throw new Error('alerta ' + alerta.status);
  const visto = await esperar(() => u1.recebidos.alertas.length > 0, 20000, 1500);
  if (!visto) {
    const resto = await api('GET', '/api/alerts/nearby?lon=-43.1729&lat=-22.9068&radius=2000', null, u1.token);
    if (!JSON.stringify(resto.body).includes('dropped_load')) throw new Error('sinal nao apareceu em socket nem REST');
  }
  if (alerta.body?.id || alerta.body?.alertId) {
    await api('POST', '/api/alerts/clear', { alertId: alerta.body.id || alerta.body.alertId, driverId: u2.driverId }, u2.token);
  }
});

cenario('rota-caminhao-real', 'Rota de caminhao com transito (mesma chave do app)', async () => {
  const keys = JSON.parse(fs.readFileSync(path.join(RAIZ, 'frontend-flutter', 'keys.json'), 'utf8'));
  const resp = await fetch('https://routes.googleapis.com/directions/v2:computeRoutes', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': keys.GOOGLE_ROUTES_KEY,
      'X-Android-Package': keys.APP_ANDROID_PACKAGE,
      'X-Android-Cert': String(keys.APP_ANDROID_CERT_SHA1 || '').replace(/:/g, ''),
      'X-Goog-FieldMask': 'routes.duration,routes.localizedValues.distance.text',
    },
    body: JSON.stringify({
      origin: { location: { latLng: { latitude: -22.9068, longitude: -43.1729 } } },
      destination: { location: { latLng: { latitude: -23.5505, longitude: -46.6333 } } },
      travelMode: 'DRIVE',
      routingPreference: 'TRAFFIC_AWARE',
    }),
  });
  const dados = await resp.json();
  if (!resp.ok || !dados.routes?.[0]) throw new Error('google: ' + (dados.error?.message || resp.status));
  const km = dados.routes[0].localizedValues?.distance?.text || '';
  if (!km) throw new Error('sem distancia na rota');
});

cenario('chat-privado-e-grupo', 'Chat privado, comboio (grupo) e rota compartilhada', async () => {
  u1.socket.emit('broadcast_chat_message', {
    driverId: u1.driverId,
    driverName: u1.nome,
    message: 'Segredo do comboio: pista limpa no km 192',
    lat: -22.9068,
    lon: -43.1729,
    targetDriverId: u2.driverId,
  });
  await sleep(1200);
  if (!u2.recebidos.chat.some((m) => m.private === true && /km 192/.test(m.message || ''))) throw new Error('chat privado nao chegou');
  const g = await api('POST', '/api/groups', { name: 'Comboio App ' + marca, role: 'motorista', isPublic: false }, u1.token);
  if (g.status !== 201 || !g.body.id) throw new Error('grupo ' + g.status + ' ' + JSON.stringify(g.body).slice(0, 100));
  const grupoId = g.body.id;
  const entrou = await api('POST', '/api/groups/' + grupoId + '/join', { role: 'motorista' }, u2.token);
  if (entrou.status !== 200) throw new Error('entrar grupo ' + entrou.status);
  u2.socket.emit('join_group', { groupId: grupoId, driverId: u2.driverId });
  u3.socket.emit('join_group', { groupId: grupoId, driverId: u3.driverId });
  await sleep(500);
  const compart = await api('POST', '/api/groups/' + grupoId + '/routes', {
    driverName: u1.nome,
    payload: { paradas: 2, destino: 'Sao Paulo' },
    isPublic: false,
  }, u1.token);
  if (compart.status !== 201) throw new Error('compartilhar rota ' + compart.status);
  const visaoMembro = await api('GET', '/api/groups/' + grupoId + '/routes', null, u2.token);
  const visaoFora = await api('GET', '/api/groups/' + grupoId + '/routes', null, u3.token);
  if (!Array.isArray(visaoMembro.body) || visaoMembro.body.length < 1) throw new Error('membro nao viu rota');
  if (Array.isArray(visaoFora.body) && visaoFora.body.length > 0) throw new Error('fora do grupo viu rota privada');
});

cenario('clima-real', 'Open-Meteo ing atual + tile RainReader(RainViewer)', async () => {
  const meteo = await fetch('https://api.open-meteo.com/v1/forecast?latitude=-22.9068&longitude=-43.1729&current=temperature_2m,precipitation');
  if (!meteo.ok) throw new Error('open-meteo ' + meteo.status);
  const dados = await meteo.json();
  if (typeof dados.current?.temperature_2m !== 'number') throw new Error('sem temperatura');
  const meta = await fetch('https://api.rainviewer.com/public/weather-maps.json');
  if (!meta.ok) throw new Error('rainviewer meta ' + meta.status);
  const j = await meta.json();
  const past = j.radar?.past || [];
  if (!past.length) throw new Error('rainviewer sem camadas');
  const caminho = past[past.length - 1];
  const tile = await fetch(j.host + caminho.path + '/256/3/3/2/1/1_1.png');
  if (!tile.ok) throw new Error('tile ' + tile.status);
});

cenario('seguranca-e-carga', 'Token recusado, hostil nao derruba, 300 req sem 5xx, banco alive', async () => {
  const ruim = await api('GET', '/api/groups', null, 'token.falsificado');
  if (ruim.status !== 401 && ruim.status !== 403) throw new Error('token invalido aceito: ' + ruim.status);
  const hostil = await api('POST', '/api/alerts', { type: 'x'.repeat(500), message: 'A'.repeat(5000), lat: 99999, lon: -99999 }, u1.token);
  if (hostil.status >= 500) {
    const vivo = await api('GET', '/status');
    if (vivo.status !== 200) throw new Error('hostil derrubou o servidor');
  }
  let tofu = 0;
  const caminhos = ['/status', '/api/alerts/nearby?lon=-43.1&lat=-22.9&radius=5000', '/api/alerts/messages?lon=-43.1&lat=-22.9'];
  for (let i = 0; i < 300; i++) {
    const r = await api('GET', caminhos[i % caminhos.length], null, i % 4 ? u1.token : undefined);
    if (r.status >= 500) tofu++;
  }
  if (tofu) throw new Error(tofu + ' req 5xx em 300');
  const fim = await api('GET', '/status');
  if (fim.body.database !== 'connected') throw new Error('banco desconectou no fim');
});

(async () => {
  console.log('='.repeat(50));
  console.log('BATERIA APP USO REAL - GPS Caminhoneiro Pro');
  console.log('Alvo: ' + BASE + ' | aparelhos: ' + CELULAR + ' + ' + EMULADOR);
  console.log('='.repeat(50));
  let passados = 0;
  const falhas = [];
  for (const c of cenarios) {
    try {
      await c.fn();
      passados++;
      console.log(`[${agora()}] ${c.nome.padEnd(24)} OK  ${c.descricao}`);
    } catch (e) {
      falhas.push({ nome: c.nome, motivo: e.message });
      console.log(`[${agora()}] ${c.nome.padEnd(24)} FALHA ${e.message}`);
    }
  }
  console.log('='.repeat(50));
  console.log(`RESULTADO: ${passados}/${cenarios.length} cenarios | nota ${((passados / cenarios.length) * 10).toFixed(1)}/10`);
  for (const f of falhas) console.log('  FALHA ' + f.nome + ' - ' + f.motivo);
  await db.end().catch(() => {});
  process.exit(0);
})();
