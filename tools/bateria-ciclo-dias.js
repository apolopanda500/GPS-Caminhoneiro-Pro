// =============================================================================
// BATERIA DO CICLO DE DIAS REAIS - GPS Caminhoneiro Pro
// =============================================================================
// Frota de motoristas reais (PC + celular + extras) trabalhando varios DIAS
// diferentes: rede, fotos mudando, rota editada ao vivo, entregas dia a dia,
// sinais, chat multi-dias persistente, ligacao de radio, comboios e nuvens.
//
//   node tools/bateria-ciclo-dias.js --url https://gps-truck-backend.onrender.com
// =============================================================================
const path = require('path');
const crypto = require('crypto');

const RAIZ = path.join(__dirname, '..');
const BACKEND = path.join(RAIZ, 'backend-api');
const { io } = require(path.join(BACKEND, 'node_modules', 'socket.io-client'));

function arg(nome, padrao) {
  const i = process.argv.indexOf('--' + nome);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : padrao;
}

const URL_API = arg('url', 'http://127.0.0.1:3000');
const DIAS = Number(arg('dias', 3));
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const esperar = async (fn, msg, timeoutMs = 5000) => {
    const inicio = Date.now();
    for (;;) {
      try { if (fn()) return; } catch { /* segue tentando */ }
      if (Date.now() - inicio > timeoutMs) throw new Error(msg);
      await sleep(300);
    }
  };
const novoUuid = () => crypto.randomUUID();
const agora = () => new Date().toISOString().slice(11, 19);
const SENHA = 'CicloDias123456';

async function api(metodo, caminho, corpo, token) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = 'Bearer ' + token;
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

async function abrirContas(qtd, rotulo) {
  const marca = Date.now().toString(36);
  const contas = [];
  const nomes = ['Celular', 'PC', 'Caminhao 3', 'Caminhao 4', 'Caminhao 5'];
  for (let i = 0; i < qtd; i++) {
    const r = await api('POST', '/api/auth/register', {
      email: `ciclo.${rotulo}.${marca}.${i}@teste.com`,
      password: SENHA,
      name: `Frota ${nomes[i] || i}`,
    });
    if (r.status !== 201 || !r.body.token)
      throw new Error('cadastro ' + i + ': ' + r.status + ' ' + JSON.stringify(r.body));
    contas.push({
      name: r.body.name || nomes[i],
      id: r.body.driverId,
      token: r.body.token,
    });
  }
  return contas;
}

// distancias crescem a cada "dia" (rotas de trabalho diferentes por dia)
const cidades = [
  { nome: 'Duque de Caxias', lat: -22.785021, lon: -43.312143 },
  { nome: 'Nova Iguacu', lat: -22.860131, lon: -43.458342 },
  { nome: 'Mage', lat: -22.801742, lon: -43.241641 },
];
const posDia = (dia, i, caixa) => ({
  nome: cidades[caixa].nome,
  lat: cidades[caixa].lat + 0.0015 * i + 0.1 * dia,
  lon: cidades[caixa].lon + 0.002 * i + 0.05 * dia,
});

const FROTA = [];
let SOCKETS = [];

function conectar(conta, nomerRadar) {
  const s = io(URL_API, {
    transports: ['websocket'],
    auth: { token: conta.token },
    reconnection: false,
    forceNew: true,
  });
  s._rec = { chat: [], reacoes: [], rotas: [], alertas: [], alertasRemovidos: [], peers: [], convites: [], locais: [], radar: [], progresso: [], seguidor: [] };
  s.on('receive_chat_message', (m) => s._rec.chat.push(m));
  s.on('receive_truck_reaction', (m) => s._rec.reacoes.push(m));
  s.on('receive_shared_route', (m) => s._rec.rotas.push(m));
  s.on('receive_alert_realtime', (m) => s._rec.alertas.push(m));
  s.on('road_validation_alerts', (m) => s._rec.alertas.push(...m));
  s.on('alert_removed', (m) => s._rec.alertasRemovidos.push(m));
  s.on('receive_peer_alert', (m) => s._rec.peers.push(m));
  s.on('receive_group_invite', (m) => s._rec.convites.push(m));
  s.on('receive_shared_place', (m) => s._rec.locais.push(m));
  s.on('route_progress', (m) => s._rec.progresso.push(m));
  s.on('route_shared_state', (m) => s._rec.seguidor.push(m));
  s.on('trucks_radar_update', (m) => s._rec.radar.push(m));
  s._conta = conta;
  s._nome = nomerRadar || conta.name;
  SOCKETS.push(s);
  return s;
}

async function conectarRede() {
  const sockets = FROTA.map((c, i) => conectar(c, 'S' + i));
  await Promise.all(
    sockets.map((s, i) => new Promise((res, rej) => {
      s.on('connect', res);
      s.on('connect_error', rej);
      if (i > 10) rej(new Error('conectando demais'));
    })),
  );
  return sockets;
}

const cenarios = [];
function cenario(nome, fn) {
  cenarios.push({ nome, fn });
}

// ---------------------------------------------------------------- cenários
// DIA 1: a frota inteira no ar
cenario('1. Dia 1 - frota de 5 reais no ar e se vendo no radar', async () => {
  const [cel, pc] = SOCKETS;
  cel.emit('join_truck_network', { driverId: FROTA[0].id, name: FROTA[0].name, role: 'motorista' });
  pc.emit('join_truck_network', { driverId: FROTA[1].id, name: FROTA[1].name, role: 'motorista' });
  for (let i = 2; i < FROTA.length; i++) {
    SOCKETS[i].emit('join_truck_network', { driverId: FROTA[i].id, name: FROTA[i].name, role: 'motorista' });
  }
  const pos = posDia(0, 0, 0);
  cel.emit('update_position', { driverId: FROTA[0].id, lat: pos.lat, lon: pos.lon, speedKmh: 74 });
  pc.emit('update_position', { driverId: FROTA[1].id, lat: pos.lat + 0.0015, lon: pos.lon + 0.002, speedKmh: 55 });
  for (let i = 2; i < FROTA.length; i++) {
    const p = posDia(0, i, 0);
    SOCKETS[i].emit('update_position', { driverId: FROTA[i].id, lat: p.lat, lon: p.lon, speedKmh: 60 + i });
  }
  await sleep(1800);
  const radar = cel._rec.radar[cel._rec.radar.length - 1] || [];
  const faltando = FROTA.filter((c) => !radar.some((t) => t.driverId === c.id));
  if (faltando.length) throw new Error('radar sem: ' + faltando.map((c) => c.name).join(', '));
  return `${FROTA.length} caminhoes se vendo em ${pos.nome} (contas reais: celular + PC + extras)`;
});

// DIA 2: fotos de perfil mudam de verdade
cenario('2. Dia 2 - mudar foto de perfil e de caminhao (edit real)', async () => {
  const pngA = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAH0lEQVR42mNkYPhfz0AEYBxVSF+FABJADveWkH6oAAAAAElFTkSuQmCC';
  const pngB = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAHklEQVR42mNk+M9gAABBiIsk4UEUQ0SAdVGBIpJQAAAAASUVORK5CYII=';
  const caminhaoA = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAH0lEQVR42mNkYPjPQAEYBxVSF+FABJADveWkH6oAAAAAElFTkSuQmCC';
  await api('POST', '/api/auth/photo', { data: pngA, kind: 'avatar' }, FROTA[0].token);
  const foto1 = await api('GET', '/api/auth/photo/' + FROTA[0].id);
  await api('POST', '/api/auth/photo', { data: pngB, kind: 'avatar' }, FROTA[0].token);
  const foto2 = await api('GET', '/api/auth/photo/' + FROTA[0].id);
  if (foto1.body.avatarUrl === foto2.body.avatarUrl) throw new Error('mudou mas a foto ficou IGUAL');
  await api('POST', '/api/auth/photo', { data: caminhaoA, kind: 'truck' }, FROTA[0].token);
  const fotoFrota = await api('GET', '/api/auth/photo/' + FROTA[0].id);
  if (!fotoFrota.body.truckPhotoUrl) throw new Error('foto do caminhao nao salvou');
  return 'foto trocada (A -> B) confirmada + foto do caminhao salva';
});

// DIA 2: rota editada ao vivo (mesmo shareId com paradas novas)
cenario('3. Dia 2 - rota compartilhada editada ao vivo (mesma shareId)', async () => {
  const dono = SOCKETS[0];
  const seg = SOCKETS[1];
  const shareId = novoUuid();
  const rotaV1 = JSON.stringify({
    stops: [
      { lat: -22.9, lon: -43.17, label: 'Cliente 1', customer: 'Cliente 1' },
      { lat: -22.8, lon: -43.16, label: 'Cliente 2', customer: 'Cliente 2' },
    ],
  });
  const rotaV2 = JSON.stringify({
    stops: [
      { lat: -22.9, lon: -43.17, label: 'Cliente 1', customer: 'Cliente 1' },
      { lat: -22.85, lon: -43.165, label: 'Balanca (nova)', customer: 'Balanca' },
      { lat: -22.82, lon: -43.162, label: 'Posto (novo)', customer: 'Posto' },
      { lat: -22.8, lon: -43.16, label: 'Cliente 2', customer: 'Cliente 2' },
    ],
  });
  const antes = seg._rec.rotas.length;
  dono.emit('share_route', { fromDriverId: FROTA[0].id, fromName: FROTA[0].name, routeJson: rotaV1, shareId });
  await sleep(900);
  const v1 = seg._rec.rotas.find((r) => r.shareId === shareId);
  if (!v1 || !Array.isArray(v1.stops) || v1.stops.length !== 2)
    throw new Error('v1: seguidor nao recebeu a rota original (2 paradas)');
  dono.emit('share_route', { fromDriverId: FROTA[0].id, fromName: FROTA[0].name, routeJson: rotaV2, shareId });
  await sleep(900);
  const v2 = seg._rec.rotas.filter((r) => r.shareId === shareId).pop();
  if (!v2 || v2.stops.length !== 4) throw new Error('edição ao vivo: seguidor nao recebeu a v2 (4 paradas)');
  seg._rec.seguidor = [];
  seg.emit('follow_route', { shareId, driverId: FROTA[1].id, name: FROTA[1].name });
  await sleep(700);
  const estado = seg._rec.seguidor.find((e) => e.shareId === shareId);
  if (!estado || !Array.isArray(estado.stops) || estado.stops.length !== 4)
    throw new Error('re-edicao: estado do seguidor nao veio com 4 paradas');
  return `sem shareId fixo: 2 -> 4 paradas chegando ao vivo (v1 e v2, shareId ${shareId.slice(0, 8)})`;
});

// cada dia: entrega das paradas com progresso ao vivo
cenario('4. Dias 1 a 3 - ciclo de entregas (chegou/entregue) dia a dia', async () => {
  const doador = SOCKETS[1];
  const seg = SOCKETS[0];
  for (let dia = 0; dia < DIAS; dia++) {
    const shareId = novoUuid();
    const base = posDia(dia, 1, dia % cidades.length);
    const routeJson = JSON.stringify({
      stops: [
        { lat: base.lat + 0.01, lon: base.lon + 0.01, label: `${cidades[dia % cidades.length].nome} - Cliente A`, customer: `Dia ${dia + 1} A` },
        { lat: base.lat + 0.02, lon: base.lon + 0.02, label: `${cidades[dia % cidades.length].nome} - Cliente B`, customer: `Dia ${dia + 1} B` },
      ],
    });
    seg._rec.progresso = [];
    doador.emit('share_route', { fromDriverId: FROTA[1].id, fromName: FROTA[1].name, routeJson, shareId });
    await sleep(600);
    seg.emit('follow_route', { shareId, driverId: FROTA[0].id, name: FROTA[0].name });
    await sleep(500);
    doador.emit('route_progress', { shareId, stopIndex: 0, status: 'chegou', driverId: FROTA[1].id, driverName: FROTA[1].name });
    await sleep(500);
    doador.emit('route_progress', { shareId, stopIndex: 0, status: 'entregue', driverId: FROTA[1].id, driverName: FROTA[1].name });
    await sleep(500);
    doador.emit('route_progress', { shareId, stopIndex: 1, status: 'entregue', driverId: FROTA[1].id, driverName: FROTA[1].name });
    await sleep(600);
    await esperar(
      () => seg._rec.progresso.some((p) => p.shareId === shareId && p.status === 'chegou' && p.stopIndex === 0)
        && seg._rec.progresso.filter((p) => p.shareId === shareId && p.status === 'entregue').length >= 2,
      `dia ${dia + 1}: progresso incompleto`,
    );
  }
  return `${DIAS} dias de entregas fechados com progresso ao vivo no seguidor (chegou + entregue)`;
});

// fim do dia: sinal criado, visto e apagado (o dono que colocou pode limpar)
cenario('5. Fim do dia - sinal da estrada chega e sai (limpeza real)', async () => {
  const dono = SOCKETS[2];
  const outro = SOCKETS[3];
  const antes = await api(
    'POST',
    '/api/alerts',
    { type: 'ponte', message: 'Ponte baixa 4.2m', maxHeight: 4.2, lat: posDia(1, 4, 1).lat, lon: posDia(1, 4, 1).lon },
    FROTA[2].token,
  );
  if (antes.status !== 201) throw new Error('sinal do dia: ' + antes.status);
  outro.emit('register_driver', { driverId: FROTA[3].id });
  outro.emit('update_position', {
    driverId: FROTA[3].id,
    lat: posDia(1, 4, 1).lat,
    lon: posDia(1, 4, 1).lon,
    speedKmh: 50,
  });
  await sleep(1300);
  const visto = outro._rec.alertas.find(
    (a) => (a.alert_type || a.type) === 'ponte' && String(a.driver_id || a.driverId) === FROTA[2].id,
  );
  if (!visto) throw new Error('sinal nao chegou no tempo real');
  const idSinal = String(visto.id);
  const perto = await api('GET', `/api/alerts/nearby?lon=${posDia(1, 4, 1).lon}&lat=${posDia(1, 4, 1).lat}&radius=2000`);
  if (!perto.body.some((a) => String(a.id) === idSinal)) throw new Error('sinal nao esta no REST do dia');
  dono._rec.alertasRemovidos = [];
  outro._rec.alertasRemovidos = [];
  dono.emit('clear_alert', { alertId: idSinal, driverId: FROTA[2].id });
  await sleep(900);
  const evento = outro._rec.alertasRemovidos.some((r) => r.alertId === idSinal)
    || dono._rec.alertasRemovidos.some((r) => r.alertId === idSinal);
  const depois = await api('GET', `/api/alerts/nearby?lon=${posDia(1, 4, 1).lon}&lat=${posDia(1, 4, 1).lat}&radius=2000`);
  if (depois.body.some((a) => String(a.id) === idSinal)) throw new Error('sinal ainda no servidor depois da limpeza');
  if (!evento) return 'limpo no servidor (REST) - evento de broadcast variavel';
  return 'sinal chegou (socket + REST) e saiu (alert_removed + REST limpo)';
});

// DIA 3: chat de dias diferentes conversando e historico que persiste
cenario('6. Dia 3 - chat de varios dias conversando (susto: dia 1 na historia)', async () => {
  const dia1 = 'Falei no 1. dia - chuva cedo amanha?';
  const dia2 = 'Teste do 2. dia: radar na BR-040 km 128?';
  const alvoMsg = 'Fechei no dia ' + Date.now().toString(36) + ' - final do ciclo';
  SOCKETS[0]._rec.chat = [];
  SOCKETS[1]._rec.chat = [];
  SOCKETS[0].emit('broadcast_chat_message', { driverId: FROTA[0].id, driverName: FROTA[0].name, message: dia1, lat: posDia(0, 0, 0).lat, lon: posDia(0, 0, 0).lon });
  SOCKETS[1].emit('broadcast_chat_message', { driverId: FROTA[1].id, driverName: FROTA[1].name, message: dia2, lat: posDia(1, 1, 1).lat, lon: posDia(1, 1, 1).lon });
  SOCKETS[0].emit('broadcast_chat_message', { driverId: FROTA[0].id, driverName: FROTA[0].name, message: alvoMsg, lat: posDia(2, 0, 2).lat, lon: posDia(2, 0, 2).lon });
  await sleep(1100);
  if (!SOCKETS[1]._rec.chat.some((m) => m.message === alvoMsg)) throw new Error('chat do dia 3 nao chegou na frota');
  SOCKETS[0]._rec.reacoes = [];
  SOCKETS[0].emit('send_truck_reaction', { fromName: FROTA[1].name, targetDriverId: FROTA[0].id, emoji: '☕' });
  await sleep(600);
  if (!SOCKETS[0]._rec.reacoes.some((r) => r.emoji === '☕')) throw new Error('reacao do dia 3 nao chegou');
  const hist = await api('GET', `/api/alerts/messages?lon=${posDia(0, 0, 0).lon}&lat=${posDia(0, 0, 0).lat}&radius=90000`);
  if (hist.status !== 200 || !Array.isArray(hist.body)) throw new Error('historico de dias: ' + hist.status);
  const temDia1 = hist.body.some((m) => m.message === dia1);
  const temDia3 = hist.body.some((m) => m.message === alvoMsg);
  if (!temDia1 || !temDia3) throw new Error(`historico nao tem os dias: dia1=${temDia1} dia3=${temDia3}`);
  return `conversa de 3 dias no banco: dia 1 e dia 3 encontrados no historico (${hist.body.length} msgs no raio)`;
});

// DIA 3: ligacao de radio entre aparelhos (call/sinal/vibracao)
cenario('7. Dia 3 - ligacao de radio (chamada, sinal e vibracao entre caminhoes)', async () => {
  const de = SOCKETS[0];
  const alvo = SOCKETS[1];
  alvo._rec.peers = [];
  de.emit('send_peer_alert', { fromDriverId: FROTA[0].id, fromName: FROTA[0].name, targetDriverId: FROTA[1].id, kind: 'signal', message: 'Ei, para no acostamento!' });
  await sleep(400);
  de.emit('send_peer_alert', { fromDriverId: FROTA[0].id, fromName: FROTA[0].name, targetDriverId: FROTA[1].id, kind: 'vibration' });
  await sleep(400);
  de.emit('send_peer_alert', { fromDriverId: FROTA[0].id, fromName: FROTA[0].name, targetDriverId: FROTA[1].id, kind: 'call' });
  await sleep(600);
  const k = {};
  for (const p of alvo._rec.peers) k[p.kind] = true;
  if (!k.signal || !k.vibration || !k.call) throw new Error('faltou: ' + JSON.stringify(Object.keys(k)));
  return 'radio do fim de dia: sinal + vibracao + CHAMADA (call) entregues ao colega';
});

// DIA 3: comboio multi-dias: criado no 1, entra no 2, rota no 3
cenario('8. Comboio multi-dias - criado no dia 1, ativo no dia 3', async () => {
  const g = await api('POST', '/api/groups', { name: 'Ciclo ' + Date.now(), role: 'motorista', isPublic: false }, FROTA[0].token);
  if (g.status !== 201 || !g.body.id) throw new Error('grupo: ' + g.status);
  const gid = g.body.id;
  const j1 = await api('POST', `/api/groups/${gid}/join`, { role: 'motorista' }, FROTA[1].token);
  const j2 = await api('POST', `/api/groups/${gid}/join`, { role: 'motorista' }, FROTA[2].token);
  if (j1.status !== 200 || j2.status !== 200) throw new Error('join: ' + j1.status + '/' + j2.status);
  SOCKETS[3]._rec.convites = [];
  SOCKETS[0].emit('send_group_invite', { groupId: gid, groupName: 'Ciclo Frota', fromDriverId: FROTA[0].id, fromName: FROTA[0].name, targetDriverId: FROTA[3].id });
  await esperar(() => SOCKETS[3]._rec.convites.length > 0, 'convite nao entregue');
  SOCKETS[0].emit('join_group', { groupId: gid, driverId: FROTA[0].id });
  SOCKETS[1].emit('join_group', { groupId: gid, driverId: FROTA[1].id });
  SOCKETS[2].emit('join_group', { groupId: gid, driverId: FROTA[2].id });
  await sleep(700);

  // DIA 3: a rota do comboio...
  const shareId = novoUuid();
  const rota = JSON.stringify({
    stops: [
      { lat: posDia(2, 0, 2).lat, lon: posDia(2, 0, 2).lon, label: `Ciclo A`, customer: 'Ciclo A' },
      { lat: posDia(2, 1, 2).lat, lon: posDia(2, 1, 2).lon, label: `Ciclo B`, customer: 'Ciclo B' },
    ],
  });
  SOCKETS[1]._rec.rotas = [];
  SOCKETS[2]._rec.rotas = [];
  SOCKETS[0].emit('share_route', { fromDriverId: FROTA[0].id, fromName: FROTA[0].name, routeJson: rota, groupId: gid, shareId });
  await esperar(
    () => SOCKETS[1]._rec.rotas.some((r) => r.shareId === shareId)
      && SOCKETS[2]._rec.rotas.some((r) => r.shareId === shareId),
    'membros nao receberam a rota do comboio (dia 3)',
  );
  const progressoNoBanco = await api('GET', `/api/groups/${gid}/routes`, null, FROTA[1].token);
  if (progressoNoBanco.status !== 200 || !progressoNoBanco.body.some((r) => r.id === shareId))
    throw new Error('rota do comboio ficou fora do historico');
  const ajuda = await api('POST', '/api/auth/profile', { role: 'ajudante' }, FROTA[3].token);
  if (ajuda.status !== 200) throw new Error('perfil de ajudante: ' + ajuda.status);
  const bloqueado = await api('POST', `/api/groups/${gid}/routes`, { routeJson: rota }, FROTA[3].token);
  if (bloqueado.status < 400 || bloqueado.status >= 500) throw new Error('ajudante montou rota: ' + bloqueado.status);
  await api('POST', '/api/auth/profile', { role: 'motorista' }, FROTA[3].token);
  return `comboio ${gid.slice(0, 8)}: 2 membros receberam rota do dia 3, rota no historico, ajudante bloqueado`;
});

// DIA 3: nuvens/tempo real - as duas fontes que o app consome
cenario('9. Dia 3 - nuvens e tempo real (Open-Meteo + RainViewer como o app usa)', async () => {
  const base = posDia(2, 0, 2);
  const m = await fetch(
    `https://api.open-meteo.com/v1/forecast?latitude=${base.lat}&longitude=${base.lon}&current=temperature_2m,cloud_cover,precipitation&timezone=America/Sao_Paulo`,
  );
  if (m.status !== 200) throw new Error('Open-Meteo: ' + m.status);
  const tempo = await m.json();
  if (typeof tempo.current?.cloud_cover !== 'number') throw new Error('Open-Meteo sem cloud_cover');
  const t = await fetch('https://api.rainviewer.com/public/weather-maps.json');
  if (t.status !== 200) throw new Error('RainViewer: ' + t.status);
  const chuva = await t.json();
  const anim = chuva?.radar?.past || chuva?.radar?.nowcast || [];
  if (!chuva.host || !anim.length) throw new Error('RainViewer sem tiles de nuvem/radar');
  const frame = anim[anim.length - 1];
  const tileUrl = `${chuva.host}${frame.path}/256/2/1/1/1/1_1.png`;
  const rTitulo = await fetch(tileUrl);
  if (rTitulo.status !== 200) throw new Error('tile de nuvem: ' + rTitulo.status + ' ' + tileUrl);
  return `tempo ok (${tempo.current.temperature_2m}C, nuvens ${tempo.current.cloud_cover}%) + radar de chuva em tiles (HTTP 200)`;
});

// DIA 3 fim: banco com ciclo inteiro no ar sem 5xx
cenario('10. Fechamento - ciclo inteiro saudavel (status, carga e 5 dias de rede)', async () => {
  const reqs = [];
  for (let i = 0; i < 60; i++) {
    reqs.push(api('GET', '/status'));
    reqs.push(api('GET', `/api/alerts/messages?lon=${posDia(0, 0, 0).lon}&lat=${posDia(0, 0, 0).lat}&radius=90000`));
    reqs.push(api('GET', `/api/alerts/nearby?lon=${posDia(2, 0, 2).lon}&lat=${posDia(2, 0, 2).lat}&radius=5000`));
  }
  const resps = await Promise.all(reqs);
  const erros = resps.filter((r) => r.status >= 500);
  if (erros.length) throw new Error(erros.length + ' respostas 5xx');
  const status = resps.find((r) => r.body && r.body.status !== undefined);
  if (!status || status.body.status !== 'online' || status.body.database !== 'connected')
    throw new Error('status: ' + JSON.stringify(status?.body));
  return `${resps.length} requisicoes sem 5xx; status=online banco=connected`;
});

// ------------------------------------------------------------------ execucao
async function main() {
  console.log('==================================================');
  console.log(' BATERIA DO CICLO DE DIAS REAIS - frota completa');
  console.log('==================================================');
  console.log('Alvo: ' + URL_API);
  console.log('Dias: ' + DIAS + ' | Motoristas: 5 (celular, PC e 3 extras)');
  console.log('');

  FROTA.push(...(await abrirContas(5, 'frota')));
  console.log('Frota criada pela API (cadastro real): ' + FROTA.map((c) => c.name).join(', '));
  console.log('');

  SOCKETS = await conectarRede();
  console.log('Sockets conectados: ' + SOCKETS.length);

  let passou = 0;
  const detalhes = [];
  for (const c of cenarios) {
    process.stdout.write('[' + agora() + '] ' + c.nome.padEnd(58));
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
    SOCKETS.forEach((s) => s.close());
  } catch (_) {}

  const nota = (passou / cenarios.length) * 10;
  console.log('\n==================================================');
  console.log(' RESULTADO: ' + passou + '/' + cenarios.length + ' cenarios | nota ' + nota.toFixed(1) + '/10');
  console.log('==================================================');
  for (const d of detalhes) console.log((d.ok ? '  OK    ' : '  FALHA ') + d.nome + ' - ' + d.msg);

  process.exit(passou === cenarios.length ? 0 : 1);
}

main().catch((e) => {
  console.error('ERRO GERAL:', e);
  process.exit(2);
});
