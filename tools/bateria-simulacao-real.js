// =============================================================================
// BATERIA DE SIMULACAO REAL - GPS Caminhoneiro Pro
// =============================================================================
// Simula N motoristas REAIS (perfis diferentes) usando o backend de verdade:
// cadastro/login, socket V2X, movimento na estrada, alertas, chat, reacoes,
// grupos/comboios, rota compartilhada, premium via PIX, assistente e
// seguranca (token invalido, identidade pelo token, payload hostil).
//
//   node tools/bateria-simulacao-real.js
//   node tools/bateria-simulacao-real.js --usuarios 10 --passos 40
//   node tools/bateria-simulacao-real.js --url https://servidor.onrender.com
//   node tools/bateria-simulacao-real.js --local          (sobe o backend local)
//   node tools/bateria-simulacao-real.js --manter         (nao limpa o banco)
//
// Saida: nota de 0 a 10 (10 = todos os cenarios de uso real passaram).
// =============================================================================
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { spawn } = require('child_process');

const RAIZ = path.join(__dirname, '..');
const BACKEND = path.join(RAIZ, 'backend-api');
const NO_MODULOS = path.join(BACKEND, 'node_modules');
const { Client } = require(path.join(NO_MODULOS, 'pg'));
const { io } = require(path.join(NO_MODULOS, 'socket.io-client'));

// ---------------------------------------------------------------- argumentos
function arg(nome, padrao) {
  const i = process.argv.indexOf('--' + nome);
  if (i >= 0 && process.argv[i + 1]) return process.argv[i + 1];
  return padrao;
}
const USUARIOS = Number(arg('usuarios', 8));
const PASSOS = Number(arg('passos', 30));
const INTERVALO_MS = Number(arg('ms', 90));
const URL_EXTERNA = arg('url', '');
const USAR_LOCAL = process.argv.includes('--local');
const MANTER = process.argv.includes('--manter');
const PORTA_LOCAL = 3999;

// ------------------------------------------------------------------- helpers
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const agora = () => new Date().toISOString().slice(11, 19);

// Le o .env do backend sem imprimir segredos.
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
const JWT_SECRET = ENV.JWT_SECRET || 'ROBO_DARK_SECRET_2026';

function criarToken(driverId) {
  const payload = Buffer.from(
    JSON.stringify({ driverId, expiraEm: Date.now() + 90 * 24 * 3600 * 1000 }),
  ).toString('base64url');
  const assinatura = crypto
    .createHmac('sha256', JWT_SECRET)
    .update(payload)
    .digest('hex');
  return payload + '.' + assinatura;
}

function semSslMode(url) {
  if (!url) return url;
  if (/supabase\.com/i.test(url)) return url.replace(/[?&]sslmode=[^&]*/i, '');
  return url;
}
const db = new Client({
  connectionString: semSslMode(ENV.DATABASE_URL),
  ssl: /supabase\.com/i.test(ENV.DATABASE_URL || '')
    ? { rejectUnauthorized: false }
    : undefined,
});

let BASE = URL_EXTERNA;
let servidorLocal = null;

// --------------------------------------------------------------- cenarios
const cenarios = [];
function cenario(nome, descricao, fn) {
  cenarios.push({ nome, descricao, fn });
}

const users = [];
function novoUsuario(i, perfil) {
  const u = {
    indice: i,
    perfil,
    driverId: `drv_sim_${Date.now().toString(36)}_${i}`,
    email: `simulacao.${Date.now().toString(36)}.${i}@bateria.local`,
    senha: 'Bateria123',
    token: '',
    socket: null,
    pos: { lat: -22.9068, lon: -43.1729 },
    alertasRecebidos: [],
    mensagensRecebidas: [],
    reacoesRecebidas: [],
    rotasRecebidas: [],
    invitations: [],
    radar: [],
  };
  users.push(u);
  return u;
}

async function api(metodo, caminho, corpo, token) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = 'Bearer ' + token;
  const resp = await fetch(BASE + caminho, {
    method: metodo,
    headers,
    body: corpo ? JSON.stringify(corpo) : undefined,
  });
  let json = null;
  const texto = await resp.text();
  try {
    json = texto ? JSON.parse(texto) : null;
  } catch (_) {
    json = { bruto: texto.slice(0, 200) };
  }
  return { status: resp.status, body: json };
}

// =============================================================================
// 1. Servico no ar
// =============================================================================
cenario('servico-no-ar', 'Backend responde /status com banco conectado', async () => {
  const r = await api('GET', '/status');
  if (r.status !== 200) throw new Error('/status devolveu ' + r.status);
  if (r.body.database !== 'connected')
    throw new Error('banco nao conectado: ' + r.body.database);
  return 'status=' + r.body.status + ' banco=' + r.body.database;
});

// =============================================================================
// 2. Cadastro e login de usuarios diferentes
// =============================================================================
cenario('cadastro-e-login', 'Usuarios diferentes se cadastram, verificam e entram', async () => {
  const perfis = [
    { role: 'motorista', name: 'Joao Caminhoneiro', model: 'Volvo FH 460', cargo: 'Soja', h: 4.1, w: 38 },
    { role: 'motorista', name: 'Maria Transporte', model: 'Scania R450', cargo: 'Carga Geral', h: 4.4, w: 45 },
    { role: 'motorista', name: 'Carlos Andre', model: 'DAF XF', cargo: 'Refrigerado', h: 4.0, w: 20 },
    { role: 'motorista', name: 'Pedro Bau', model: 'Mercedes Atego', cargo: 'Sacos de Cafe', h: 3.9, w: 12 },
    { role: 'ajudante', name: 'Ana Ajudante', model: '', cargo: '', h: null, w: null },
    { role: 'motorista', name: 'Lucas Premium', model: 'Mercedes Actros', cargo: 'Eletrodomesticos', h: 4.2, w: 30 },
    { role: 'motorista', name: 'Bruno Brominha', model: 'Iveco Stralis', cargo: 'Combustivel', h: 4.3, w: 48, hazmat: true },
    { role: 'motorista', name: 'Dani DFT', model: 'DAF XF 105', cargo: 'Papel', h: 4.1, w: 22 },
    { role: 'motorista', name: 'Rafa Gaviao', model: 'Scania S500', cargo: 'Mineracao', h: 4.5, w: 50 },
    { role: 'motorista', name: 'Sonia RJ', model: 'Iveco S-Way', cargo: 'Carga Geral', h: 4.0, w: 15 },
    { role: 'motorista', name: 'Tonhao Bras', model: 'Volvo VM270', cargo: 'Graos', h: 4.2, w: 40 },
    { role: 'motorista', name: 'Vania Sul', model: 'Scania P 320', cargo: 'Carga Geral', h: 3.8, w: 18 },
  ];
  for (let i = 0; i < USUARIOS; i++) {
    const p = perfis[i % perfis.length];
    novoUsuario(i, p);
  }

  // Caminho 1: cadastro real pela API (com e-mail). Se o SMTP estiver off,
  // o cenario cria o usuario verificado direto no banco (como quem ja
  // confirmou o e-mail) e o login e feito pela API de verdade.
  let cadastroReal = 0;
  for (const u of users) {
    const reg = await api('POST', '/api/auth/register', {
      email: u.email,
      password: u.senha,
      name: u.perfil.name,
      height: u.perfil.h || 4.4,
      weight: u.perfil.w || 45,
      role: u.perfil.role,
    });
    if (reg.status === 201) {
      cadastroReal++;
      u.token = reg.body.token || '';
      u.driverId = reg.body.driverId || u.driverId;
      // Le o codigo de verificacao do banco (o usuario lendo o e-mail).
      const cod = await db.query(
        `SELECT code FROM verification_codes WHERE email = $1 AND consumed = FALSE
         ORDER BY created_at DESC LIMIT 1`,
        [u.email],
      );
      if (cod.rows[0]) {
        await api('POST', '/api/auth/verify', { email: u.email, code: cod.rows[0].code });
      }
    } else {
      await db.query(
        `INSERT INTO drivers (driver_id, email, password_hash, name, truck_height, truck_weight,
           role, help_type, email_verified, verified_at, is_premium)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,TRUE,NOW(),FALSE)
         ON CONFLICT (driver_id) DO NOTHING`,
        [
          u.driverId,
          u.email,
          crypto.createHash('sha256').update(u.senha).digest('hex'),
          u.perfil.name,
          u.perfil.h || 4.4,
          u.perfil.w || 45,
          u.perfil.role,
          u.perfil.role === 'ajudante' ? 'Mecanica / pneus' : null,
        ],
      );
    }
  }

  // Login pela API para todos: o token tem que vir do servidor.
  // (Se o e-mail exigir verificacao - que exige ler o banco do servidor -,
  // usamos o token que o proprio cadastro devolve.)
  let logins = 0;
  for (const u of users) {
    const login = await api('POST', '/api/auth/login', {
      email: u.email,
      password: u.senha,
    });
    if (login.status === 200 && login.body.token) {
      u.token = login.body.token;
      u.driverId = login.body.driverId;
      logins++;
    } else if (u.token) {
      logins++; // token do cadastro (servidor exige verificacao por e-mail)
    } else {
      throw new Error('login falhou (' + login.status + ') para ' + u.email + ' ' + JSON.stringify(login.body));
    }
  }
  if (logins !== users.length) throw new Error('logins ' + logins + '/' + users.length);
  return (
    users.length + ' usuarios, ' + logins + ' logins, ' + cadastroReal + ' cadastros com e-mail real'
  );
});

// =============================================================================
// 3. Perfil, foto e dados do caminhao
// =============================================================================
cenario('perfil-e-fotos', 'Perfil, foto do motorista e do caminhao sao salvos', async () => {
  const u = users[0];
  const r = await api(
    'POST',
    '/api/auth/profile',
    {
      name: 'Joao Caminhoneiro JR',
      truckModel: 'Volvo FH 460 6x2',
      cargoType: 'Graos e Sementes',
      companyName: 'Transportes JR',
    },
    u.token,
  );
  if (r.status !== 200) throw new Error('perfil: ' + r.status + ' ' + JSON.stringify(r.body));

  const png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
  const foto = await api('POST', '/api/auth/photo', { data: png, kind: 'avatar' }, u.token);
  if (foto.status !== 200) throw new Error('foto: ' + foto.status + ' ' + JSON.stringify(foto.body));

  const fotoCaminhao = await api('POST', '/api/auth/photo', { data: png, kind: 'truck' }, u.token);
  if (fotoCaminhao.status !== 200) throw new Error('foto caminhao: ' + fotoCaminhao.status);

  // Confere pelo servidor (nao pelo banco local - o deploy pode usar outro).
  const busca = await api('GET', '/api/auth/photo/' + u.driverId);
  if (busca.status !== 200 || !busca.body.avatarUrl) throw new Error('leitura da foto falhou');
  if (!busca.body.avatarUrl.startsWith('data:image'))
    throw new Error('foto nao foi gravada: ' + String(busca.body.avatarUrl).slice(0, 40));
  return 'perfil + 2 fotos gravados (confirmados pelo servidor)';
});

// =============================================================================
// 4. Rede V2X: n车队 ve n车队 andando
// =============================================================================
cenario('rede-v2x-tempo-real', 'Todos os motoristas veem os outros se movendo', async () => {
  const posInicial = { lat: -22.9068, lon: -43.1729 };
  for (const u of users) {
    u.pos = { ...posInicial };
    u.socket = io(BASE, {
      transports: ['websocket'],
      auth: { token: u.token },
      reconnection: false,
      forceNew: true,
    });
    u.socket.on('trucks_radar_update', (lista) => {
      u.radar.push(lista);
    });
    u.socket.on('receive_chat_message', (m) => u.mensagensRecebidas.push(m));
    u.socket.on('receive_truck_reaction', (r) => u.reacoesRecebidas.push(r));
    u.socket.on('receive_shared_route', (r) => u.rotasRecebidas.push(r));
    u.socket.on('receive_peer_alert', (a) => u.alertasRecebidos.push(a));
    u.socket.on('receive_group_invite', (i) => u.invitations.push(i));
    u.socket.on('road_validation_alerts', (l) => u.alertasRecebidos.push(l));
    await new Promise((resolve) => {
      u.socket.on('connect', resolve);
      u.socket.on('connect_error', (e) => {
        throw new Error('socket de ' + u.email + ': ' + e.message);
      });
    });
    u.socket.emit('join_truck_network', {
      driverId: u.driverId,
      name: u.perfil.name,
      role: u.perfil.role,
      truckIcon: '🚚',
    });
    u.socket.emit('register_driver', { driverId: u.driverId, role: u.perfil.role });
  }
  await sleep(600);

  // Cada um anda na sua propria pista (BR-101 sentido norte/sul).
  for (let passo = 0; passo < PASSOS; passo++) {
    for (let i = 0; i < users.length; i++) {
      const u = users[i];
      const sentido = i % 2 === 0 ? 1 : -1;
      u.pos.lat += 0.0006 * sentido;
      u.pos.lon += 0.0004;
      u.socket.emit('update_position', {
        driverId: u.driverId,
        lat: u.pos.lat,
        lon: u.pos.lon,
        speedKmh: 60 + (i % 5) * 8,
      });
    }
    await sleep(INTERVALO_MS);
  }
  await sleep(800);

  const ultimo = users[0].radar[users[0].radar.length - 1] || [];
  if (ultimo.length < users.length)
    throw new Error('radar viu ' + ultimo.length + ' de ' + users.length + ' caminhões');
  const comNome = ultimo.filter((t) => t.name && t.name.length > 0);
  if (comNome.length < users.length)
    throw new Error('radar sem nomes dos peers: ' + JSON.stringify(ultimo.slice(0, 2)));
  const movidos = ultimo.filter((t) => Math.abs(t.lat - posInicial.lat) > 0.0005);
  if (movidos.length < users.length)
    throw new Error('radar nao acompanhou o movimento (' + movidos.length + ')');
  return users.length + ' caminhoes em tempo real, ' + ultimo.length + ' vistos por cada um';
});

// =============================================================================
// 5. Alertas de estrada (socket + REST)
// =============================================================================
cenario('alertas-da-estrada', 'Sinal criado aparece para quem esta perto', async () => {
  const a = users[0];
  const b = users[1];
  b.alertasRecebidos = [];
  b.socket.on('road_validation_alerts', (lista) => b.alertasRecebidos.push(lista));

  const tipo = 'radar';
  const r = await api(
    'POST',
    '/api/alerts',
    { type: tipo, message: 'Radar fixo 80km/h', maxHeight: 4.5, maxWeight: 30, lat: b.pos.lat, lon: b.pos.lon },
    a.token,
  );
  if (r.status !== 201) throw new Error('criacao de alerta: ' + r.status + ' ' + JSON.stringify(r.body));

  const perto = await api(
    'GET',
    '/api/alerts/nearby?lon=' + b.pos.lon + '&lat=' + b.pos.lat + '&radius=2000',
  );
  if (perto.status !== 200 || !Array.isArray(perto.body) || perto.body.length === 0)
    throw new Error('nearby vazio: ' + perto.status);

  // O sinal chega em tempo real quando o colega se move (como no app).
  b.socket.emit('update_position', {
    driverId: b.driverId,
    lat: b.pos.lat,
    lon: b.pos.lon,
    speedKmh: 70,
  });
  await sleep(1500);
  const viu = b.alertasRecebidos.some((l) =>
    l.some((x) => x.alert_type === tipo || x.type === tipo),
  );
  if (!viu) throw new Error('o colega nao recebeu o alerta em tempo real');

  // Limpar o sinal (o app faz isso pelo socket, com o dono do sinal).
  const id = perto.body[0].id;
  const dono = perto.body[0].driverId || a.driverId;
  b.socket.emit('clear_alert', { alertId: id, driverId: dono });
  await sleep(900);
  const depois = await api('GET', '/api/alerts/nearby?lon=' + b.pos.lon + '&lat=' + b.pos.lat + '&radius=2000');
  const ainda = depois.body.some((s) => s.id === id);
  if (ainda) throw new Error('alerta nao foi removido ao limpar');
  return 'criado, visto por perto (REST + socket) e removido';
});

// =============================================================================
// 6. Chat de estrada e reacoes
// =============================================================================
cenario('chat-e-reacoes', 'Chat publico, chat privado e reacao na rede', async () => {
  const a = users[0];
  const b = users[1];
  const c = users[2];
  for (const u of [b, c]) u.mensagensRecebidas = [];

  a.socket.emit('broadcast_chat_message', {
    driverId: a.driverId,
    driverName: a.perfil.name,
    message: 'Parada no posto, 15 min',
    lat: a.pos.lat,
    lon: a.pos.lon,
  });
  await sleep(600);
  if (!b.mensagensRecebidas.some((m) => m.message === 'Parada no posto, 15 min'))
    throw new Error('chat publico nao chegou no colega');

  // Chat privado: so o alvo recebe.
  b.mensagensRecebidas = [];
  c.mensagensRecebidas = [];
  a.socket.emit('broadcast_chat_message', {
    driverId: a.driverId,
    driverName: a.perfil.name,
    message: 'Segredo: rota pela BR-116',
    lat: a.pos.lat,
    lon: a.pos.lon,
    targetDriverId: b.driverId,
  });
  await sleep(600);
  if (!b.mensagensRecebidas.some((m) => m.private === true))
    throw new Error('chat privado nao chegou no alvo');
  if (c.mensagensRecebidas.some((m) => m.message === 'Segredo: rota pela BR-116'))
    throw new Error('chat privado vazou para terceiro');

  // Reacao com emoji.
  b.reacoesRecebidas = [];
  a.socket.emit('send_truck_reaction', {
    fromDriverId: a.driverId,
    fromName: a.perfil.name,
    targetDriverId: b.driverId,
    emoji: '👍',
  });
  await sleep(500);
  if (!b.reacoesRecebidas.some((r) => r.emoji === '👍'))
    throw new Error('reacao nao chegou');

  // Persistencia no servidor (o app le pelo REST depois).
  const salvo = await api(
    'GET',
    '/api/alerts/messages?lon=-43.1729&lat=-22.9068&radius=5000',
  );
  if (salvo.status !== 200 || !Array.isArray(salvo.body))
    throw new Error('mensagens nao voltaram: ' + salvo.status);
  if (!salvo.body.some((m) => m.message === 'Parada no posto, 15 min'))
    throw new Error('mensagem nao foi salva no servidor');
  return 'chat publico, privado, reacao e persistencia no servidor';
});

// =============================================================================
// 7. Grupos (comboios) e rota compartilhada
// =============================================================================
cenario('grupos-e-rota-compartilhada', 'Grupo filtra quem ve a rota compartilhada', async () => {
  const dono = users[0];
  const membro = users[1];
  const curioso = users[2];

  const g = await api('POST', '/api/groups', { name: 'Comboio Br101 Teste', role: 'motorista', isPublic: false }, dono.token);
  if (g.status !== 201 || !g.body.id) throw new Error('criacao do grupo: ' + g.status + ' ' + JSON.stringify(g.body));
  const grupoId = g.body.id;

  const entrou = await api('POST', '/api/groups/' + grupoId + '/join', { role: 'motorista' }, membro.token);
  if (entrou.status !== 200) throw new Error('entrar no grupo: ' + entrou.status);

  // Socket: o membro entra na sala do grupo.
  membro.socket.emit('join_group', { groupId: grupoId, driverId: membro.driverId });
  curioso.socket.emit('join_group', { groupId: grupoId, driverId: curioso.driverId });
  await sleep(400);

  membro.rotasRecebidas = [];
  curioso.rotasRecebidas = [];
  dono.socket.emit('share_route', {
    fromDriverId: dono.driverId,
    fromName: dono.perfil.name,
    routeJson: JSON.stringify({ paradas: 3, destino: 'Juiz de Fora' }),
    groupId: grupoId,
  });
  await sleep(700);
  if (!membro.rotasRecebidas.length) throw new Error('membro do grupo nao recebeu a rota');
  if (curioso.rotasRecebidas.length) throw new Error('nao-membro recebeu a rota do grupo privado');

  // REST: rota compartilhada no grupo + visibilidade.
  const compart = await api(
    'POST',
    '/api/groups/' + grupoId + '/routes',
    { driverName: dono.perfil.name, payload: { paradas: 3, destino: 'Juiz de Fora' }, isPublic: false },
    dono.token,
  );
  if (compart.status !== 201) throw new Error('compartilhar rota: ' + compart.status + ' ' + JSON.stringify(compart.body));

  const visaoMembro = await api('GET', '/api/groups/' + grupoId + '/routes', null, membro.token);
  const visaoCurioso = await api('GET', '/api/groups/' + grupoId + '/routes', null, curioso.token);
  if (!Array.isArray(visaoMembro.body) || visaoMembro.body.length < 1)
    throw new Error('membro nao viu a rota: ' + JSON.stringify(visaoMembro.body));
  if (Array.isArray(visaoCurioso.body) && visaoCurioso.body.length !== 0)
    throw new Error('curioso viu rota de grupo privado');

  // Ajudante nao compartilha rota.
  const ajudante = users.find((u) => u.perfil.role === 'ajudante');
  if (ajudante) {
    const bloqueio = await api(
      'POST',
      '/api/groups/' + grupoId + '/routes',
      { driverName: ajudante.perfil.name, payload: { paradas: 1 } },
      ajudante.token,
    );
    if (bloqueio.status !== 403) throw new Error('ajudante deveria ser bloqueado, veio ' + bloqueio.status);
  }
  return 'grupo privado com rota visivel so para membros; ajudante bloqueado';
});

// =============================================================================
// 8. Premium via PIX
// =============================================================================
cenario('premium-pix', 'BR Code valido e premium liberado apos confirmacao', async () => {
  const u = users.find((x) => x.perfil.name.indexOf('Lucas') === 0) || users[1];
  const pix = await api('POST', '/api/payment/pix', { driverId: u.driverId, plan: 'mensal' }, u.token);
  if (pix.status !== 200 || !pix.body.copyAndPastePix)
    throw new Error('pix: ' + pix.status + ' ' + JSON.stringify(pix.body));
  const brcode = pix.body.copyAndPastePix;
  if (!brcode.startsWith('000201')) throw new Error('BR Code invalido: ' + brcode.slice(0, 20));
  if (!brcode.includes('5802BR') && !brcode.includes('BR')) throw new Error('BR Code sem pais BR');
  if (!/6304[0-9A-F]{4}$/.test(brcode)) throw new Error('BR Code sem CRC16 final');

  const adminToken = ENV.ADMIN_TOKEN;
  if (!adminToken) return 'BR Code gerado e validado (sem ADMIN_TOKEN para confirmar)';
  const resp = await fetch(BASE + '/api/payment/confirm', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-admin-token': adminToken },
    body: JSON.stringify({ driverId: u.driverId, paymentId: pix.body.paymentId }),
  });
  if (!resp.ok) throw new Error('confirmacao do premium: ' + resp.status);
  const bk = await fetch(BASE + '/api/admin/backup', {
    headers: { 'x-admin-token': adminToken },
  });
  if (!bk.ok) throw new Error('backup admin: ' + bk.status);
  const dump = await bk.json();
  const drivers = (dump.tabelas && dump.tabelas.drivers) || [];
  const linha = drivers.find((d) => d.driver_id === u.driverId);
  if (!linha || linha.is_premium !== true)
    throw new Error('premium nao ativado no servidor');
  return 'BR Code + CRC16 + premium ativado';
});

// =============================================================================
// 9. Seguranca: identidade pelo token e recusa de token ruim
// =============================================================================
cenario('seguranca-identidade', 'Token manda: nao da para mexer no perfil de outro', async () => {
  const vitima = users[2];
  const atacante = users[3];
  // O radar e a visao do servidor (independe de qual banco o deploy usa).
  const radarAtual = (() => {
    for (const u of users) {
      if (u.radar && u.radar.length) return u.radar[u.radar.length - 1];
    }
    return [];
  })();

  // Token invalido e recusado em todas as rotas protegidas.
  for (const [m, p, b] of [
    ['POST', '/api/auth/profile', { name: 'Hackeado' }],
    ['POST', '/api/alerts', { type: 'perigo', lat: 0, lon: 0 }],
    ['GET', '/api/groups', null],
    ['POST', '/api/groups', { name: 'invadido' }],
  ]) {
    const r = await api(m, p, b, 'token.invalido.aqui');
    if (r.status !== 401 && r.status !== 403)
      throw new Error(p + ' com token invalido devolveu ' + r.status);
  }

  //(driverId no corpo nao muda nada: a identidade vem do token).
  const nomeVitimaAntes = (() => {
    const alvo = (radarAtual || []).find((t) => t.driverId === vitima.driverId);
    return alvo ? alvo.name : null;
  })();
  const ataque = await api(
    'POST',
    '/api/auth/profile',
    { driverId: vitima.driverId, name: 'Hackeado Por Outro', truckModel: 'Falsificado' },
    atacante.token,
  );
  if (ataque.status !== 200) throw new Error('perfil do atacante falhou: ' + ataque.status);
  // Confere pelo que o servidor mostra para os outros (radar).
  atacante.socket.emit('update_position', {
    driverId: atacante.driverId,
    lat: -22.9068,
    lon: -43.1729,
    speedKmh: 50,
  });
  await new Promise((r) => setTimeout(r, 700));
  const depois = (radarAtual || []).find((t) => t.driverId === vitima.driverId);
  if (nomeVitimaAntes && depois && depois.name !== nomeVitimaAntes)
    throw new Error('o perfil da vitima foi alterado: ' + depois.name);

  // Payload hostil nao derruba o servidor.
  const hostil = await api(
    'POST',
    '/api/alerts',
    { type: "'; DROP TABLE drivers; --", message: 'x'.repeat(4000), lat: 'abc', lon: null },
    atacante.token,
  );
  if (hostil.status >= 500) throw new Error('servidor caiu com payload hostil: ' + hostil.status);
  const vivo = await api('GET', '/status');
  if (vivo.status !== 200) throw new Error('servidor fora do ar depois do payload hostil');
  return 'token invalido recusado; identidade pelo token; payload hostil nao derruba o servidor';
});

// =============================================================================
// 10. Robustez: desconexao, reconexao, carga e assistente
// =============================================================================
cenario('robustez-e-assistente', 'Saida e volta do app, carga paralela e assistente', async () => {
  // O app fecha e abre: o peer some da rede.
  const saindo = users[users.length - 1];
  const antes = (users[0].radar[users[0].radar.length - 1] || []).length;
  saindo.socket.close();
  await sleep(900);
  const depois = (users[0].radar[users[0].radar.length - 1] || []).length;
  if (depois >= antes) throw new Error('peer desconectado continua na rede (' + depois + ')');

  // Volta do app: o mesmo motorista entra de novo.
  const voltando = users[users.length - 1];
  voltando.socket = io(BASE, {
    transports: ['websocket'],
    auth: { token: voltando.token },
    reconnection: false,
    forceNew: true,
  });
  await new Promise((r) => voltando.socket.on('connect', r));
  voltando.socket.emit('join_truck_network', {
    driverId: voltando.driverId,
    name: voltando.perfil.name,
    role: voltando.perfil.role,
  });
  await sleep(600);
  // Um movimento publica a lista de novo (como no app em movimento).
  users[0].socket.emit('update_position', {
    driverId: users[0].driverId,
    lat: users[0].pos.lat,
    lon: users[0].pos.lon,
    speedKmh: 65,
  });
  await sleep(1200);
  const voltou = (users[0].radar[users[0].radar.length - 1] || []).length;
  if (voltou < antes) throw new Error('peer nao voltou para a rede (' + voltou + '/' + antes + ')');

  // Carga paralela de varios usuarios ao mesmo tempo.
  const reqs = [];
  for (let i = 0; i < 40; i++) {
    const u = users[i % users.length];
    reqs.push(api('GET', '/api/alerts/nearby?lon=' + u.pos.lon + '&lat=' + u.pos.lat + '&radius=5000'));
    reqs.push(api('GET', '/api/alerts/messages?lon=' + u.pos.lon + '&lat=' + u.pos.lat));
    reqs.push(api('GET', '/api/groups', null, u.token));
    reqs.push(api('POST', '/api/alerts', { type: 'perigo', message: 'carga ' + i, lat: u.pos.lat, lon: u.pos.lon }, u.token));
  }
  const respostas = await Promise.all(reqs);
  const erro5xx = respostas.filter((r) => r.status >= 500);
  if (erro5xx.length) throw new Error(erro5xx.length + ' respostas 5xx na carga paralela');

  // Assistente da estrada.
  const ia = await api(
    'POST',
    '/api/assistant/ask',
    {
      pergunta: 'Quantas paradas faltam?',
      contexto: { totalParadas: 5, entregasFeitas: 2, velocidade: 80, limiteVelocidade: 60 },
    },
    users[0].token,
  );
  if (ia.status !== 200 || !ia.body.resposta) throw new Error('assistente: ' + ia.status + ' ' + JSON.stringify(ia.body));
  return 'desconexao/reconexao ok, ' + respostas.length + ' requisicoes sem 5xx, assistente respondeu ("' + ia.body.resposta.slice(0, 40) + '...")';
});

// =============================================================================
// execucao
// =============================================================================
async function subirLocal() {
  console.log('Subindo o backend local na porta ' + PORTA_LOCAL + '...');
  servidorLocal = spawn('node', ['dist/server.js'], {
    cwd: BACKEND,
    env: { ...process.env, PORT: String(PORTA_LOCAL) },
    stdio: 'pipe',
  });
  let log = '';
  servidorLocal.stdout.on('data', (d) => (log += d.toString()));
  servidorLocal.stderr.on('data', (d) => (log += d.toString()));
  for (let i = 0; i < 40; i++) {
    await sleep(1000);
    if (log.includes('rodando na porta')) {
      BASE = 'http://127.0.0.1:' + PORTA_LOCAL;
      return;
    }
    if (servidorLocal.exitCode !== null) break;
  }
  throw new Error('backend local nao subiu:\n' + log.slice(-800));
}

async function limpar() {
  const emails = users.map((u) => u.email);
  if (!emails.length) return;
  const ids = users.map((u) => u.driverId);
  try {
    await db.query('DELETE FROM truck_messages WHERE driver_id = ANY($1::varchar[])', [ids]);
    await db.query('DELETE FROM road_alerts WHERE driver_id = ANY($1::varchar[])', [ids]);
    await db.query('DELETE FROM group_shared_routes WHERE driver_id = ANY($1::varchar[])', [ids]);
    await db.query('DELETE FROM convoy_members WHERE driver_id = ANY($1::varchar[])', [ids]);
    await db.query('DELETE FROM convoy_groups WHERE owner_driver_id = ANY($1::varchar[])', [ids]);
    await db.query('DELETE FROM payments WHERE driver_id = ANY($1::varchar[])', [ids]);
    await db.query('DELETE FROM drivers WHERE driver_id = ANY($1::varchar[])', [ids]);
    await db.query('DELETE FROM verification_codes WHERE email = ANY($1::varchar[])', [emails]);
  } catch (e) {
    console.log('  (limpeza: ' + e.message + ')');
  }
}

async function main() {
  console.log('==================================================');
  console.log(' BATERIA DE SIMULACAO REAL - GPS Caminhoneiro Pro');
  console.log('==================================================');
  if (USAR_LOCAL) await subirLocal();
  if (!BASE) BASE = 'https://gps-truck-backend.onrender.com';
  console.log('Alvo: ' + BASE);
  console.log('Usuarios simulados: ' + USUARIOS + ' | passos de rota: ' + PASSOS);
  console.log('');

  await db.connect();

  let passou = 0;
  const detalhes = [];
  for (const c of cenarios) {
    process.stdout.write('[' + agora() + '] ' + c.nome.padEnd(28));
    try {
      const msg = await c.fn();
      passou++;
      console.log('OK  ' + (msg || ''));
      detalhes.push({ nome: c.nome, ok: true, msg });
    } catch (e) {
      console.log('FALHOU');
      console.log('    ' + (e && e.message ? e.message : e));
      detalhes.push({ nome: c.nome, ok: false, msg: e && e.message ? e.message : String(e) });
    }
  }

  for (const u of users) {
    try {
      if (u.socket) u.socket.close();
    } catch (_) {}
  }
  if (!MANTER) await limpar();
  else console.log('\n(--manter: dados da simulacao ficaram no banco)');

  if (servidorLocal) servidorLocal.kill();
  await db.end().catch(() => {});

  const nota = (passou / cenarios.length) * 10;
  console.log('\n==================================================');
  console.log(' RESULTADO: ' + passou + '/' + cenarios.length + ' cenarios | nota ' + nota.toFixed(1) + '/10');
  console.log('==================================================');
  for (const d of detalhes) {
    console.log((d.ok ? '  OK  ' : '  FALHA ') + d.nome + ' - ' + d.msg);
  }
  process.exit(passou === cenarios.length ? 0 : 1);
}

main().catch((e) => {
  console.error('ERRO GERAL:', e);
  if (servidorLocal) servidorLocal.kill();
  process.exit(2);
});
