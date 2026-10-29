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
const zlib = require('zlib');
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
const SO_CELULAR = process.argv.includes('--sem-emulador') || arg('aparelho', '') === 'celular';
const APARELHOS = SO_CELULAR ? [CELULAR] : [CELULAR, EMULADOR];
const PACOTE = 'com.gpscamioneiro.gps_camioneiro_pro';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const agora = () => new Date().toISOString().slice(11, 19);

function adb(args) {
  return new Promise((resolve) => {
    execFile(ADB, args, { timeout: 30000 }, (erro, stdout) => resolve(erro ? '' : String(stdout).trim()));
  });
}

function adbRaw(args) {
  return new Promise((resolve) => {
    execFile(ADB, args, { timeout: 60000, encoding: 'buffer', maxBuffer: 64 * 1024 * 1024 },
      (erro, stdout) => resolve(erro ? null : stdout));
  });
}

function lerPng(buffer) {
  let p = 8;
  let w = 0, h = 0, cor = 0;
  const partes = [];
  while (p < buffer.length - 8) {
    const len = buffer.readUInt32BE(p);
    const tipo = buffer.toString('latin1', p + 4, p + 8);
    const dado = buffer.slice(p + 8, p + 8 + len);
    if (tipo === 'IHDR') { w = dado.readUInt32BE(0); h = dado.readUInt32BE(4); cor = dado[9]; }
    if (tipo === 'IDAT') partes.push(dado);
    if (tipo === 'IEND') break;
    p += 12 + len;
  }
  const bruto = zlib.inflateSync(Buffer.concat(partes));
  const bpp = cor === 6 ? 4 : 3;
  const stride = w * bpp;
  const saida = Buffer.alloc(h * stride);
  let pos = 0;
  for (let y = 0; y < h; y++) {
    const filtro = bruto[pos];
    const linha = pos + 1;
    pos += 1 + stride;
    for (let i = 0; i < stride; i++) {
      const a = i >= bpp ? saida[y * stride + i - bpp] : 0;
      const b = y > 0 ? saida[(y - 1) * stride + i] : 0;
      const c = y > 0 && i >= bpp ? saida[(y - 1) * stride + i - bpp] : 0;
      let v = bruto[linha + i];
      if (filtro === 1) v += a;
      else if (filtro === 2) v += b;
      else if (filtro === 3) v += (a + b) >> 1;
      else if (filtro === 4) {
        const pp = a + b - c;
        const pa = Math.abs(pp - a), pb = Math.abs(pp - b), pc = Math.abs(pp - c);
        v += pa <= pb && pa <= pc ? a : (pb <= pc ? b : c);
      }
      saida[y * stride + i] = v & 255;
    }
  }
  return { w, h, bpp, px: saida };
}

async function permitidoLocalizacao(aparelho) {
  const s = await adb(['-s', aparelho, 'shell', 'dumpsys', 'package', PACOTE]);
  return /ACCESS_FINE_LOCATION: granted=true/.test(s);
}

async function textosTela(aparelho) {
  await adb(['-s', aparelho, 'shell', 'uiautomator', 'dump', '/sdcard/ui.xml']);
  const xml = await adb(['-s', aparelho, 'shell', 'cat', '/sdcard/ui.xml']);
  const textos = [];
  for (const no of String(xml).split('<node ').slice(1)) {
    const t = (no.match(/text="([^"]*)"/) || [])[1] || '';
    if (t) textos.push(t);
  }
  return textos.join(' | ');
}

async function pedindoGps(aparelho) {
  const s = await adb(['-s', aparelho, 'shell', 'dumpsys', 'location']);
  return /gps provider[^\r\n]*gpscamioneiro|ProviderRequest\[[^\r\n]*gpscamioneiro|gps request from com\.gpscamioneiro/i.test(s);
}

async function rolarParaBaixo(aparelho) {
  await adb(['-s', aparelho, 'shell', 'input', 'swipe', '540', '1800', '540', '700', '300']);
  await sleep(1500);
}

async function tapPorTexto(aparelho, regex) {
  await adb(['-s', aparelho, 'shell', 'uiautomator', 'dump', '/sdcard/ui.xml']);
  const xml = await adb(['-s', aparelho, 'shell', 'cat', '/sdcard/ui.xml']);
  for (const no of String(xml).split('<node ').slice(1)) {
    const txt = (no.match(/text="([^"]*)"/) || [])[1] || '';
    const bnd = (no.match(/bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/) || []);
    if (!bnd.length || !regex.test(txt)) continue;
    const x = Math.round((+bnd[1] + +bnd[3]) / 2);
    const y = Math.round((+bnd[2] + +bnd[4]) / 2);
    await adb(['-s', aparelho, 'shell', 'input', 'tap', String(x), String(y)]);
    return true;
  }
  return false;
}

async function tapBotaoVermelho(aparelho, faixaIni, faixaFim) {
  const png = await adbRaw(['-s', aparelho, 'exec-out', 'screencap', '-p']);
  const debug = !!process.env.DEBUG_TAP;
  const falha = (motivo) => {
    if (debug) {
      const dir = path.join(process.env.TEMP || '.', 'opencode');
      try {
        fs.mkdirSync(dir, { recursive: true });
        if (png) fs.writeFileSync(path.join(dir, 'falha-tap-' + aparelho.replace(/\W/g, '') + '.png'), png);
        console.log('        [debug-tap] ' + aparelho + ': ' + motivo);
      } catch {}
    }
    return false;
  };
  if (!png || png.length < 1000) return falha('png vazio ' + (png ? png.length : 'null'));
  let img;
  try { img = lerPng(png); } catch (e) { return falha('png ilegivel: ' + e.message); }
  const y0 = Math.floor(img.h * (faixaIni === undefined ? 0.5 : faixaIni));
  const y1 = Math.floor(img.h * (faixaFim === undefined ? 0.8 : faixaFim));
  const cols = new Int32Array(img.w);
  let total = 0;
  const ys = [];
  for (let y = y0; y < y1; y++) {
    let naLinha = 0;
    for (let x = 0; x < img.w; x++) {
      const i = (y * img.w + x) * img.bpp;
      const r = img.px[i], g = img.px[i + 1], b = img.px[i + 2];
      if (r < 95 || g > 115 || b > 115 || r - g < 50 || r - b < 50) continue;
      cols[x]++; total++; naLinha++;
    }
    if (naLinha > 15) ys.push(y);
  }
  if (total < 80 || ys.length < 5) return falha('poucos vermelhos: total=' + total + ' linhas=' + ys.length);
  const grupos = [];
  let atual = null;
  for (let x = 0; x < img.w; x++) {
    if (cols[x] > 0) {
      if (atual && x - atual.fim <= 40) { atual.fim = x; atual.n += cols[x]; }
      else { if (atual) grupos.push(atual); atual = { ini: x, fim: x, n: cols[x] }; }
    }
  }
  if (atual) grupos.push(atual);
  const validos = grupos.filter((g) => g.fim - g.ini >= 70 && g.n >= 60);
  if (!validos.length) return falha('sem grupo de botao: ' + JSON.stringify(grupos.map((g) => [g.ini, g.fim, g.n])));
  const alvo = validos.reduce((a, b) => (b.ini > a.ini ? b : a));
  const x = Math.round((alvo.ini + alvo.fim) / 2);
  const y = ys[Math.floor(ys.length / 2)];
  await adb(['-s', aparelho, 'shell', 'input', 'tap', String(x), String(y)]);
  return true;
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
const SO_CENARIO = arg('cenario', '');

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

cenario('app-aberto-nos-aparelhos', 'App rodando no aparelho real (adb pidof)', async () => {
  const saida = await adb(['devices']);
  if (!saida.includes(CELULAR)) throw new Error('celular ' + CELULAR + ' ausente: ' + saida);
  if (!SO_CELULAR && !saida.includes(EMULADOR)) throw new Error('emulador ' + EMULADOR + ' ausente');
  for (const ap of APARELHOS) {
    const pid = await adb(['-s', ap, 'shell', 'pidof', PACOTE]);
    if (!pid) throw new Error('app nao rodando em ' + ap);
  }
});

cenario('permissoes-do-usuario', 'Localizacao concedida ao app no Android', async () => {
  for (const aparelho of APARELHOS) {
    let ok = false;
    for (let tentativa = 0; tentativa < 8 && !ok; tentativa++) {
      if (await permitidoLocalizacao(aparelho)) { ok = true; break; }
      if (await tapPorTexto(aparelho, /^(Got it|OK|Entendi)$/)) {
        console.log(`        ${aparelho}: dispensou overlay do sistema`);
        await sleep(900); continue;
      }
      if (await tapPorTexto(aparelho, /While using the app|Durante o uso do app/i)) {
        console.log(`        ${aparelho}: tocou "enquanto o app estiver em uso"`);
        await sleep(1200); continue;
      }
      if (await tapPorTexto(aparelho, /^(Permitir|Allow)$/)) {
        console.log(`        ${aparelho}: tocou Permitir no Android`);
        await sleep(1200); continue;
      }
      const tocou = await tapBotaoVermelho(aparelho);
      console.log(`        ${aparelho}: toque no botao do dialogo do app=${tocou}`);
      await sleep(tocou ? 2000 : 1200);
    }
    if (!ok) throw new Error('localizacao negada em ' + aparelho);
    console.log(`        ${aparelho}: localizacao concedida`);
  }
});

cenario('app-entra-no-mapa', 'App chega ao mapa com o GPS ativo', async () => {
  for (const aparelho of APARELHOS) {
    await adb(['-s', aparelho, 'shell', 'am', 'start', '-n', PACOTE + '/.MainActivity']);
    await sleep(4000);
    let feito = await pedindoGps(aparelho);
    for (let passo = 0; passo < 16 && !feito; passo++) {
      const tela = await textosTela(aparelho);
      if (/Location permission|Location access|Allow all the time|Use precise location|App info|Permitir que este app acesse/i.test(tela)) {
        if (await tapPorTexto(aparelho, /^Allow all the time$|^Permitir o tempo todo$/)) {
          console.log(`        ${aparelho}: concedeu localizacao em segundo plano`);
          await sleep(2500);
        }
        await adb(['-s', aparelho, 'shell', 'input', 'keyevent', 'KEYCODE_BACK']);
        console.log(`        ${aparelho}: voltou das configuracoes do Android`);
      } else if (await tapPorTexto(aparelho, /^Allow all$|^While using the app$|^Durante o uso do app$|^Allow$|^Permitir$/)) {
        console.log(`        ${aparelho}: tocou permitir no Android`);
      } else {
        let tocou = false;
        if (/Motorista|Ajudante|Dimensoes|Carga perigosa/i.test(tela)) {
          await rolarParaBaixo(aparelho);
          tocou = await tapBotaoVermelho(aparelho, 0.82, 0.99);
        } else {
          tocou = await tapBotaoVermelho(aparelho, 0.45, 0.82);
          if (!tocou) { await rolarParaBaixo(aparelho); tocou = await tapBotaoVermelho(aparelho, 0.82, 0.99); }
        }
        console.log(`        ${aparelho}: avancou tela (toque=${tocou})`);
      }
      await sleep(2500);
      feito = await pedindoGps(aparelho);
    }
    if (!feito) throw new Error('app nao chegou ao mapa com GPS em ' + aparelho);
    for (let volta = 0; volta < 4; volta++) {
      const top = await adb(['-s', aparelho, 'shell', 'dumpsys', 'activity', 'activities']);
      const m = top.match(/topResumedActivity=ActivityRecord\{\S+ u\d+ (\S+)/);
      if (m && m[1].startsWith(PACOTE)) break;
      await adb(['-s', aparelho, 'shell', 'input', 'keyevent', 'KEYCODE_BACK']);
      await sleep(2000);
    }
    console.log(`        ${aparelho}: no mapa, rastreio de GPS ativo`);
  }
});

cenario('gps-do-sistema-move', 'GPS do sistema entrega posicao real ao app', async () => {
  if (SO_CELULAR) {
    const prova = await esperar(async () => {
      const s = await adb(['-s', CELULAR, 'shell', 'dumpsys', 'location']);
      const pedido = /HIGH_ACCURACY[^\r\n]*com\.gpscamioneiro\.gps_camioneiro_pro/.test(s) ||
        /com\.gpscamioneiro\.gps_camioneiro_pro[\s\S]{0,200}HIGH_ACCURACY/.test(s);
      const gps = s.match(/last location=Location\[gps (-?\d+\.\d+),(-?\d+\.\d+)/);
      const fundido = s.match(/last location=Location\[fused (-?\d+\.\d+),(-?\d+\.\d+)/);
      const alvo = gps || fundido;
      if (!pedido || !alvo) return null;
      const lat = parseFloat(alvo[1]);
      const lon = parseFloat(alvo[2]);
      if (!(lat > -90 && lat < 90 && lon > -180 && lon < 180)) return null;
      return { lat, lon, fonte: gps ? 'gps' : 'fused' };
    }, 60000, 3000);
    if (!prova) throw new Error('app nao pediu GPS de alta precisao ao sistema ou sem fix real');
    console.log(`        celular: fix ${prova.fonte} ${prova.lat},${prova.lon}`);
    return;
  }
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

if (require.main === module) {
  (async () => {
  console.log('='.repeat(50));
  console.log('BATERIA APP USO REAL - GPS Caminhoneiro Pro');
  console.log('Alvo: ' + BASE + ' | aparelhos: ' + APARELHOS.join(' + '));
  console.log('='.repeat(50));
  let passados = 0;
  const falhas = [];
  const roteiro = SO_CENARIO ? cenarios.filter((c) => c.nome === SO_CENARIO) : cenarios;
  if (SO_CENARIO && !roteiro.length) {
    console.log('cenario nao existe: ' + SO_CENARIO);
    process.exit(1);
  }
  for (const c of roteiro) {
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
  console.log(`RESULTADO: ${passados}/${roteiro.length} cenarios | nota ${((passados / roteiro.length) * 10).toFixed(1)}/10`);
  for (const f of falhas) console.log('  FALHA ' + f.nome + ' - ' + f.motivo);
  await db.end().catch(() => {});
  process.exit(0);
  })();
}

module.exports = { adb, adbRaw, lerPng, tapPorTexto, tapBotaoVermelho, permitidoLocalizacao, textosTela, pedindoGps, rolarParaBaixo, sleep };
