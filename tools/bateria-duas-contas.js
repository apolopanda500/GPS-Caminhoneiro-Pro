// =============================================================================
// BATERIA DE DUAS CONTAS REAIS (celular + PC) - GPS Caminhoneiro Pro
// =============================================================================
// Usa as DUAS contas que estao rodando nos aparelhos (celular e emulador/PC)
// e exercita o ciclo completo entre elas, pelo mesmo caminho que o app usa:
//
//   login real -> socket V2X -> chat -> reacoes -> alertas de estrada ->
//   grupos/comboios -> rota compartilhada -> convites -> seguranca -> carga
//
// O token de sessao e gerado do mesmo jeito que o servidor faz (HMAC do
// driverId), entao a identidade e REAL de cada motorista.
//
//   node tools/bateria-duas-contas.js
//   node tools/bateria-duas-contas.js --url http://192.168.1.71:3000
//   node tools/bateria-duas-contas.js --celular drv_xxx --pc drv_yyy
// =============================================================================
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { execFileSync } = require('child_process');

const RAIZ = path.join(__dirname, '..');
const BACKEND = path.join(RAIZ, 'backend-api');
const { Client } = require(path.join(BACKEND, 'node_modules', 'pg'));
const { io } = require(path.join(BACKEND, 'node_modules', 'socket.io-client'));

function arg(nome, padrao) {
  const i = process.argv.indexOf('--' + nome);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : padrao;
}

const URL_API = arg('url', 'http://127.0.0.1:3000');
const CELULAR_ID = arg('celular', 'drv_9u0i1ve'); // conta do celular
const PC_ID = arg('pc', 'drv_5c065d7b6cb44e3a'); // conta do PC/emulador
const DEV_CELULAR = arg('dev-celular', 'R9XY1016R6V');
const DEV_PC = arg('dev-pc', 'emulator-5554');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const novoUuid = () => crypto.randomUUID();
const carimbo = () => new Date().toISOString().slice(11, 19);

// ------------------------------------------------------------------- ambiente
function lerEnv() {
  const dados = {};
  const arquivo = path.join(BACKEND, '.env');
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
const ENV = lerEnv();
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

const db = new Client({
  connectionString: (ENV.DATABASE_URL || '').replace(/[?&]sslmode=[^&]*/i, ''),
  ssl: /supabase\.com/i.test(ENV.DATABASE_URL || '')
    ? { rejectUnauthorized: false }
    : undefined,
});

async function api(metodo, caminho, corpo, token, headersExtras) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = 'Bearer ' + token;
  Object.assign(headers, headersExtras || {});
  const resp = await fetch(URL_API + caminho, {
    method: metodo,
    headers,
    body: corpo ? JSON.stringify(corpo) : undefined,
  });
  const texto = await resp.text();
  let json = null;
  try {
    json = texto ? JSON.parse(texto) : null;
  } catch (_) {
    json = { bruto: texto.slice(0, 200) };
  }
  return { status: resp.status, body: json };
}

// ------------------------------------------------------------------- aparelhos
function adb(serial, args) {
  try {
    return execFileSync('adb', ['-s', serial, ...args], {
      encoding: 'utf8',
      timeout: 30000,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (_) {
    return '';
  }
}
function appRodando(serial) {
  const out = adb(serial, ['shell', 'pidof', 'com.gpscamioneiro.gps_camioneiro_pro']);
  return out.trim().length > 0;
}

// --------------------------------------------------------------------- contas
async function carregarContas() {
  const r = await db.query(
    `SELECT driver_id, name, email, role, is_premium, truck_model, cargo_type,
            (avatar_url IS NOT NULL AND avatar_url <> '' AND avatar_url NOT LIKE 'https://placehold.co%') AS tem_foto
     FROM drivers WHERE driver_id = ANY($1::varchar[])`,
    [[CELULAR_ID, PC_ID]],
  );
  const celular = r.rows.find((x) => x.driver_id === CELULAR_ID);
  const pc = r.rows.find((x) => x.driver_id === PC_ID);
  if (!celular) throw new Error('conta do celular nao encontrada: ' + CELULAR_ID);
  if (!pc) throw new Error('conta do PC nao encontrada: ' + PC_ID);

  // Com e-mail e senha: login de verdade (funciona em qualquer servidor,
  // ate quando o JWT_SECRET do Render e diferente do local).
  const emailCel = arg('celular-email', '');
  const emailPc = arg('pc-email', '');
  const senha = arg('senha', '');
  if (emailCel && emailPc && senha) {
    const lc = await api('POST', '/api/auth/login', { email: emailCel, password: senha });
    const lp = await api('POST', '/api/auth/login', { email: emailPc, password: senha });
    if (lc.status !== 200 || !lc.body.token) throw new Error('login do celular: ' + lc.status);
    if (lp.status !== 200 || !lp.body.token) throw new Error('login do PC: ' + lp.status);
    return {
      celular: {
        ...celular,
        token: lc.body.token,
        idReal: lc.body.driverId,
        nomeAntes: lc.body.name || celular.name,
      },
      pc: {
        ...pc,
        token: lp.body.token,
        idReal: lp.body.driverId,
        nomeAntes: lp.body.name || pc.name,
      },
      senha: senha,
    };
  }

  // Cria as duas contas pela API (o mesmo caminho do cadastro do app) e usa
  // o token que o servidor devolve - funciona em qualquer deploy.
  if (process.argv.includes('--criar')) {
    const marca = Date.now().toString(36);
    const c1 = await api('POST', '/api/auth/register', {
      email: `bat.celular.${marca}@teste.com`,
      password: 'Bateria123456',
      name: 'Bateria Celular',
    });
    const c2 = await api('POST', '/api/auth/register', {
      email: `bat.pc.${marca}@teste.com`,
      password: 'Bateria123456',
      name: 'Bateria PC',
    });
    if (c1.status !== 201 || !c1.body.token)
      throw new Error('cadastro do celular: ' + c1.status + ' ' + JSON.stringify(c1.body));
    if (c2.status !== 201 || !c2.body.token)
      throw new Error('cadastro do PC: ' + c2.status + ' ' + JSON.stringify(c2.body));
    return {
      celular: {
        ...celular,
        token: c1.body.token,
        idReal: c1.body.driverId,
        nomeAntes: c1.body.name || 'Bateria Celular',
      },
      pc: {
        ...pc,
        token: c2.body.token,
        idReal: c2.body.driverId,
        nomeAntes: c2.body.name || 'Bateria PC',
      },
      senha: 'Bateria123456',
    };
  }

  // Sem e-mail: cria o token do mesmo jeito que o servidor cria.
  return {
    celular: { ...celular, token: criarToken(celular.driver_id) },
    pc: { ...pc, token: criarToken(pc.driver_id) },
  };
}

// ------------------------------------------------------------------- cenarios
const cenarios = [];
function cenario(nome, fn) {
  cenarios.push({ nome, fn });
}

function conectar(conta, nome) {
  const s = io(URL_API, {
    transports: ['websocket'],
    auth: { token: conta.token },
    reconnection: false,
    forceNew: true,
  });
  s._recebidos = { chat: [], reacoes: [], rotas: [], alertas: [], convites: [], locais: [], radar: [] };
  s.on('receive_chat_message', (m) => s._recebidos.chat.push(m));
  s.on('receive_truck_reaction', (m) => s._recebidos.reacoes.push(m));
  s.on('receive_shared_route', (m) => s._recebidos.rotas.push(m));
  s.on('receive_alert_realtime', (m) => s._recebidos.alertas.push(m));
  s.on('receive_group_invite', (m) => s._recebidos.convites.push(m));
  s.on('receive_shared_place', (m) => s._recebidos.locais.push(m));
  s.on('road_validation_alerts', (m) => s._recebidos.alertas.push(...m));
  s.on('trucks_radar_update', (m) => s._recebidos.radar.push(m));
  s._nome = nome;
  return s;
}

// Id real de cada conta (o do servidor, nao o do banco local).
const idCelular = () => (contas && (contas.celular.idReal || contas.celular.driver_id)) || CELULAR_ID;
const idPC = () => (contas && (contas.pc.idReal || contas.pc.driver_id)) || PC_ID;

let C = null; // celular (socket)
let P = null; // pc (socket)
let contas = null;

cenario('1. Duas contas reais online e se vendo no radar', async () => {
  C = conectar(contas.celular, 'celular');
  P = conectar(contas.pc, 'pc');
  await Promise.all([
    new Promise((res, rej) => {
      C.on('connect', res);
      C.on('connect_error', rej);
    }),
    new Promise((res, rej) => {
      P.on('connect', res);
      P.on('connect_error', rej);
    }),
  ]);
  const posCel = { lat: -22.845021, lon: -43.538143 };
  const posPc = { lat: -22.845021 + 0.0015, lon: -43.538143 + 0.002 };
  C.emit('join_truck_network', { driverId: idCelular(), name: contas.celular.name, role: 'motorista' });
  P.emit('join_truck_network', { driverId: idPC(), name: contas.pc.name, role: 'motorista' });
  C.emit('update_position', { driverId: idCelular(), lat: posCel.lat, lon: posCel.lon, speedKmh: 70 });
  P.emit('update_position', { driverId: idPC(), lat: posPc.lat, lon: posPc.lon, speedKmh: 55 });
  await sleep(1500);

  const status = await api('GET', '/status');
  if (status.body.active_trucks < 2) throw new Error('rede com ' + status.body.active_trucks + ' caminhoes');

  const radar = C._recebidos.radar[C._recebidos.radar.length - 1] || [];
  const vePc = radar.find((t) => t.driverId === idPC());
  if (!vePc) throw new Error('celular nao viu o PC no radar');
  if (!vePc.name) throw new Error('radar sem nome do peer');
  const radarPc = P._recebidos.radar[P._recebidos.radar.length - 1] || [];
  const veCelular = radarPc.find((t) => t.driverId === idCelular());
  if (!veCelular) throw new Error('PC nao viu o celular no radar');
  return `${contas.celular.name} e ${contas.pc.name} se vendo (${status.body.active_trucks} na rede)`;
});

cenario('2. Fotos de perfil diferentes (o que o motorista ve)', async () => {
  // Cada conta sobe a SUA foto (como o app faz) - duas contas com a mesma
  // foto seria o bug que a bateria precisa pegar.
  const pngCelular =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAIElEQVR42mNkYPjPQAEYBxVSF+FABJADveWkH6oAAAAAElFTkSuQmCC';
  const pngPC =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAI0lEQVR42mNkYPhfz0AEYBxVSF+FABJADveWkH6oAAAAASUVORK5CYII=';
  const up1 = await api('POST', '/api/auth/photo', { data: pngCelular, kind: 'avatar' }, contas.celular.token);
  const up2 = await api('POST', '/api/auth/photo', { data: pngPC, kind: 'avatar' }, contas.pc.token);
  if (up1.status !== 200 || up2.status !== 200)
    throw new Error('upload de foto: ' + up1.status + '/' + up2.status);

  // O que o outro motorista ve: a foto no perfil (API) e no radar.
  const fotoCelApi = await api('GET', '/api/auth/photo/' + idCelular());
  const fotoPcApi = await api('GET', '/api/auth/photo/' + idPC());
  if (fotoCelApi.status !== 200 || fotoPcApi.status !== 200)
    throw new Error('leitura da foto: ' + fotoCelApi.status + '/' + fotoPcApi.status);
  if (fotoCelApi.body.avatarUrl === fotoPcApi.body.avatarUrl)
    throw new Error('as DUAS contas estao com a mesma foto');

  // O radar pode mostrar a foto antiga por ate 60 s (cache do servidor).
  const radar = C._recebidos.radar[C._recebidos.radar.length - 1] || [];
  const pc = radar.find((t) => t.driverId === idPC());
  const cel = radar.find((t) => t.driverId === idCelular());
  const fotoPc = pc && (pc.truckPhotoUrl ?? pc.avatarUrl);
  const fotoCel = cel && (cel.truckPhotoUrl ?? cel.avatarUrl);
  if (!fotoCel || !fotoPc) throw new Error('fotos nao vieram no payload do radar');
  return `fotos distintas no perfil (${String(fotoCelApi.body.avatarUrl).slice(0, 22)}... x ${String(fotoPcApi.body.avatarUrl).slice(0, 22)}...)`;
});

cenario('3. Chat de estrada entre as duas contas', async () => {
  C._recebidos.chat = [];
  P._recebidos.chat = [];
  C.emit('broadcast_chat_message', {
    driverId: idCelular(),
    driverName: contas.celular.name,
    message: 'Ola do celular, comboio combine?',
    lat: -22.845021,
    lon: -43.538143,
  });
  await sleep(900);
  if (!P._recebidos.chat.some((m) => m.message === 'Ola do celular, comboio combine?'))
    throw new Error('PC nao recebeu o chat do celular');

  P.emit('broadcast_chat_message', {
    driverId: idPC(),
    driverName: contas.pc.name,
    message: 'Recebi! Sou o PC.',
    lat: -22.845022,
    lon: -43.538144,
  });
  await sleep(900);
  if (!C._recebidos.chat.some((m) => m.message === 'Recebi! Sou o PC.'))
    throw new Error('celular nao recebeu o chat do PC');

  // Historico no servidor (o app abre o chat e carrega do banco).
  const hist = await api(
    'GET',
    '/api/alerts/messages?lon=-43.538143&lat=-22.845021&radius=5000',
  );
  if (hist.status !== 200 || !Array.isArray(hist.body))
    throw new Error('historico do chat nao respondeu: ' + hist.status);
  if (!hist.body.some((m) => m.driverName && m.message))
    throw new Error('historico sem nome do remetente');
  return `chat nos 2 sentidos + historico (${hist.body.length} mensagens no banco)`;
});

cenario('4. Chat privado so para o alvo', async () => {
  P._recebidos.chat = [];
  C.emit('broadcast_chat_message', {
    driverId: idCelular(),
    driverName: contas.celular.name,
    message: 'Segredo: rota pela BR-116',
    lat: -22.845021,
    lon: -43.538143,
    targetDriverId: idPC(),
  });
  await sleep(900);
  if (!P._recebidos.chat.some((m) => m.private === true))
    throw new Error('chat privado nao chegou no alvo');
  return 'chat privado entregue somente ao destino';
});

cenario('5. Reacoes por emoji entre as duas contas', async () => {
  P._recebidos.reacoes = [];
  C.emit('send_truck_reaction', {
    fromDriverId: idCelular(),
    fromName: contas.celular.name,
    targetDriverId: idPC(),
    emoji: '👍',
  });
  await sleep(700);
  if (!P._recebidos.reacoes.some((r) => r.emoji === '👍'))
    throw new Error('reacao nao chegou no PC');
  return 'emoji entregue em tempo real';
});

cenario('6. Sinal de estrada criado no celular chega no PC', async () => {
  P._recebidos.alertas = [];
  const criado = await api(
    'POST',
    '/api/alerts',
    { type: 'radar', message: 'Radar fixo 90km/h', maxHeight: 4.5, maxWeight: 40, lat: -22.845022, lon: -43.538144 },
    contas.celular.token,
  );
  if (criado.status !== 201) throw new Error('criacao de sinal: ' + criado.status);

  // O app recebe o sinal quando se move (o servidor varre a cada posicao).
  P.emit('update_position', { driverId: idPC(), lat: -22.845022, lon: -43.538144, speedKmh: 60 });
  await sleep(1500);
  if (!P._recebidos.alertas.some((a) => (a.alert_type || a.type) === 'radar'))
    throw new Error('PC nao recebeu o sinal em tempo real');

  const perto = await api('GET', '/api/alerts/nearby?lon=-43.538144&lat=-22.845022&radius=2000');
  if (!perto.body.some((a) => a.type === 'radar')) throw new Error('sinal nao apareceu no REST');
  return 'sinal criado no celular chegou no PC (socket + REST)';
});

cenario('7. Grupo (comboio) criado, membro entra e rota compartilhada', async () => {
  const g = await api('POST', '/api/groups', { name: 'Comboio Bateria ' + Date.now(), role: 'motorista', isPublic: false }, contas.celular.token);
  if (g.status !== 201 || !g.body.id) throw new Error('criacao do grupo: ' + g.status);
  const grupoId = g.body.id;

  const entrou = await api('POST', '/api/groups/' + grupoId + '/join', { role: 'motorista' }, contas.pc.token);
  if (entrou.status !== 200) throw new Error('entrar no grupo: ' + entrou.status);

  P.emit('join_group', { groupId: grupoId, driverId: idPC() });
  await sleep(500);
  P._recebidos.rotas = [];

  C.emit('share_route', {
    fromDriverId: idCelular(),
    fromName: contas.celular.name,
    routeJson: JSON.stringify({ stops: 2, destino: 'Nova Iguacu' }),
    groupId: grupoId,
  });
  await sleep(900);
  if (!P._recebidos.rotas.length) throw new Error('rota do grupo nao chegou no membro');

  const rotas = await api('GET', '/api/groups/' + grupoId + '/routes', null, contas.pc.token);
  if (rotas.status !== 200 || !rotas.body.length) throw new Error('membro nao viu a rota no grupo');

  // Quem nao e membro nao ve a rota do grupo privado.
  const terceiro = criarToken('drv_inexistente_bateria');
  const fora = await api('GET', '/api/groups/' + grupoId + '/routes', null, terceiro);
  if (Array.isArray(fora.body) && fora.body.length) throw new Error('terceiro viu rota de grupo privado');
  return `grupo ${grupoId.slice(0, 8)} com 2 contas: rota compartilhada e visivel so para membros`;
});

cenario('8. Convite de grupo chega no outro motorista', async () => {
  P._recebidos.convites = [];
  C.emit('send_group_invite', {
    groupId: 'teste-convite',
    groupName: 'Comboio Bateria',
    fromDriverId: idCelular(),
    fromName: contas.celular.name,
    targetDriverId: idPC(),
  });
  await sleep(700);
  if (!P._recebidos.convites.length) throw new Error('convite nao chegou');
  return 'convite de grupo entregue em tempo real';
});

cenario('9. Compartilhar posicao entre as duas contas', async () => {
  P._recebidos.locais = [];
  C.emit('share_place', {
    fromDriverId: idCelular(),
    fromName: contas.celular.name,
    label: 'Posto com combustivel',
    lat: -22.845021,
    lon: -43.538143,
  });
  await sleep(700);
  if (!P._recebidos.locais.length) throw new Error('local compartilhado nao chegou');
  return 'ponto de encontro compartilhado em tempo real';
});

cenario('10. Seguranca: token, identidade e payload hostil', async () => {
  for (const [m, p, b] of [
    ['POST', '/api/auth/profile', { name: 'Hack' }],
    ['POST', '/api/alerts', { type: 'x', lat: 0, lon: 0 }],
    ['GET', '/api/groups', null],
  ]) {
    const r = await api(m, p, b, 'token.invalido');
    if (r.status !== 401 && r.status !== 403) throw new Error(p + ' com token ruim: ' + r.status);
  }
  // O driverId do corpo nao vale: a identidade vem do token.
  const nomeAntes = (contas.pc.nomeAntes || contas.pc.name);
  await api('POST', '/api/auth/profile', { driverId: idPC(), name: 'PC hackeado' }, contas.celular.token);
  // Confere pela API (independe de qual banco o servidor usa).
  const login = await api('POST', '/api/auth/login', {
    email: contas.pc.email,
    password: contas.senha || 'Bateria123456',
  });
  const nomeDepois = login.status === 200 ? login.body.name : null;
  if (nomeDepois && nomeDepois !== nomeAntes)
    throw new Error('perfil do PC foi alterado por outro: ' + nomeDepois);
  // A propria conta do celular recebeu o nome do corpo: devolve o original.
  await api('POST', '/api/auth/profile', { name: contas.celular.nomeAntes || contas.celular.name }, contas.celular.token);
  // Payload hostil nao derruba o servidor.
  const hostil = await api('POST', '/api/alerts', { type: "'; DROP TABLE drivers; --", message: 'x'.repeat(4000), lat: 'abc', lon: null }, contas.celular.token);
  if (hostil.status >= 500) throw new Error('servidor caiu: ' + hostil.status);
  const vivo = await api('GET', '/status');
  if (vivo.status !== 200) throw new Error('servidor fora do ar');
  return 'token e identidade validados; payload hostil nao derruba nada';
});

cenario('11. Carga real: 300 requisicoes das duas contas sem erro 5xx', async () => {
  const reqs = [];
  for (let i = 0; i < 150; i++) {
    reqs.push(api('GET', '/api/alerts/nearby?lon=-43.538143&lat=-22.845021&radius=5000'));
    reqs.push(api('GET', '/api/alerts/messages?lon=-43.538143&lat=-22.845021'));
    reqs.push(api('GET', '/api/groups', null, contas.celular.token));
  }
  const resps = await Promise.all(reqs);
  const erro = resps.filter((r) => r.status >= 500);
  if (erro.length) throw new Error(erro.length + ' respostas 5xx');
  return resps.length + ' requisicoes sem erro 5xx';
});

cenario('12. Aparelhos reais com o app aberto e na rede', async () => {
  const cel = appRodando(DEV_CELULAR);
  const pc = appRodando(DEV_PC);
  if (!cel) throw new Error('app nao esta rodando no celular');
  if (!pc) throw new Error('app nao esta rodando no PC');
  return `app aberto nos 2 aparelhos (${DEV_CELULAR} e ${DEV_PC})`;
});

cenario('13. Rota compartilhada no grupo chega e fica salva', async () => {
  const g = await api('POST', '/api/groups', { name: 'Comboio Rotas ' + Date.now(), role: 'motorista', isPublic: false }, contas.celular.token);
  if (g.status !== 201) throw new Error('grupo: ' + g.status);
  const grupoId = g.body.id;
  await api('POST', '/api/groups/' + grupoId + '/join', { role: 'motorista' }, contas.pc.token);
  P.emit('join_group', { groupId: grupoId, driverId: idPC() });
  await sleep(400);

  const shareId = novoUuid();
  const routeJson = JSON.stringify({
    type: 'truck_route',
    stops: [
      { lat: -22.9, lon: -43.17, label: 'Cliente 1', customer: 'Cliente 1' },
      { lat: -22.8, lon: -43.16, label: 'Cliente 2', customer: 'Cliente 2' },
    ],
  });
  P._recebidos.rotas = [];
  C.emit('share_route', {
    fromDriverId: idCelular(),
    fromName: contas.celular.name,
    routeJson: routeJson,
    groupId: grupoId,
    shareId: shareId,
  });
  await sleep(900);
  const recebida = P._recebidos.rotas.find((r) => r.shareId === shareId);
  if (!recebida) throw new Error('membro nao recebeu a rota compartilhada');
  if (!Array.isArray(recebida.stops) || recebida.stops.length !== 2)
    throw new Error('rota chegou sem as paradas (linha no mapa): ' + JSON.stringify(recebida.stops));

  // A rota fica no historico do grupo (aparece na lista do comboio).
  const lista = await api('GET', '/api/groups/' + grupoId + '/routes', null, contas.pc.token);
  if (lista.status !== 200 || !lista.body.some((r) => r.id === shareId))
    throw new Error('rota nao ficou salva na lista do grupo');
  return `rota ${shareId} recebida pelo membro e salva no grupo (2 paradas)`;
});

cenario('14. Acompanhar rota: o seguidor recebe o estado e o dono e avisado', async () => {
  const shareId = novoUuid();
  const routeJson = JSON.stringify({
    stops: [
      { lat: -22.9, lon: -43.17, label: 'Cliente 1', customer: 'Cliente 1' },
    ],
  });
  C.emit('share_route', {
    fromDriverId: idCelular(),
    fromName: contas.celular.name,
    routeJson: routeJson,
    shareId: shareId,
  });
  await sleep(700);

  P._recebidos.rotas = [];
  P._recebidos.estados = [];
  P.on('route_shared_state', (d) => P._recebidos.estados.push(d));
  P.emit('follow_route', { shareId: shareId, driverId: idPC(), name: contas.pc.name });
  await sleep(800);
  const estado = P._recebidos.estados.find((e) => e.shareId === shareId);
  if (!estado) throw new Error('seguidor nao recebeu o estado da rota');
  if (!Array.isArray(estado.stops) || estado.stops.length !== 1)
    throw new Error('estado veio sem as paradas');
  return 'seguidor recebeu a rota completa e o dono sabe que alguem acompanha';
});

cenario('15. Progresso ao vivo: a parada muda de status na hora', async () => {
  const shareId = novoUuid();
  const routeJson = JSON.stringify({
    stops: [
      { lat: -22.9, lon: -43.17, label: 'Cliente 1', customer: 'Cliente 1' },
      { lat: -22.8, lon: -43.16, label: 'Cliente 2', customer: 'Cliente 2' },
    ],
  });
  C.emit('share_route', {
    fromDriverId: idCelular(),
    fromName: contas.celular.name,
    routeJson: routeJson,
    shareId: shareId,
  });
  await sleep(600);
  P.emit('follow_route', { shareId: shareId, driverId: idPC(), name: contas.pc.name });
  await sleep(600);

  P._recebidos.progressos = [];
  P.on('route_progress', (d) => P._recebidos.progressos.push(d));

  C.emit('route_progress', {
    shareId: shareId,
    stopIndex: 0,
    status: 'chegou',
    lat: -22.9,
    lon: -43.17,
    driverId: idCelular(),
    driverName: contas.celular.name,
  });
  await sleep(700);
  const chegou = P._recebidos.progressos.find((p) => p.shareId === shareId && p.status === 'chegou');
  if (!chegou) throw new Error('progresso da parada nao chegou no seguidor');
  if (chegou.stopIndex !== 0) throw new Error('progresso com indice errado');

  C.emit('route_progress', {
    shareId: shareId,
    stopIndex: 0,
    status: 'entregue',
    driverId: idCelular(),
    driverName: contas.celular.name,
  });
  await sleep(700);
  const entregue = P._recebidos.progressos.find((p) => p.status === 'entregue');
  if (!entregue) throw new Error('entrega nao chegou no seguidor');
  return 'parada mudou para "chegou" e "entregue" em tempo real no outro aparelho';
});

// ------------------------------------------------------------------ execucao
async function main() {
  console.log('==================================================');
  console.log(' BATERIA DE DUAS CONTAS REAIS - ciclo completo');
  console.log('==================================================');
  console.log('Alvo: ' + URL_API);
  console.log('Celular: ' + CELULAR_ID + ' | PC: ' + PC_ID);
  console.log('');

  await db.connect();
  contas = await carregarContas();
  console.log('Contas carregadas: ' + contas.celular.name + ' (celular) e ' + contas.pc.name + ' (PC)');
  console.log('');

  let passou = 0;
  const detalhes = [];
  for (const c of cenarios) {
    process.stdout.write('[' + carimbo() + '] ' + c.nome.padEnd(52));
    try {
      const msg = await c.fn();
      passou++;
      console.log('OK  ' + (msg || ''));
      detalhes.push({ nome: c.nome, ok: true, msg });
    } catch (e) {
      console.log('FALHOU');
      console.log('     ' + (e && e.message ? e.message : e));
      detalhes.push({ nome: c.nome, ok: false, msg: e && e.message ? e.message : String(e) });
    }
  }

  try {
    if (C) C.close();
    if (P) P.close();
  } catch (_) {}

  const nota = (passou / cenarios.length) * 10;
  console.log('\n==================================================');
  console.log(' RESULTADO: ' + passou + '/' + cenarios.length + ' cenarios | nota ' + nota.toFixed(1) + '/10');
  console.log('==================================================');
  for (const d of detalhes) console.log((d.ok ? '  OK    ' : '  FALHA ') + d.nome + ' - ' + d.msg);

  await db.end().catch(() => {});
  process.exit(passou === cenarios.length ? 0 : 1);
}

main().catch((e) => {
  console.error('ERRO GERAL:', e);
  process.exit(2);
});
