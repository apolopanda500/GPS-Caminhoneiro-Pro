// =============================================================================
// OBSERVADOR V2X - escuta a rede de caminhoes em tempo real
// =============================================================================
// Conecta como um terceiro caminhao e registra TODO evento que passa na rede:
// posicoes (radar), chat, reacoes, rotas compartilhadas, alertas e convites.
// Serve de prova independente do que os aparelhos estao fazendo.
//
//   node tools/observador-v2x.js [--url http://127.0.0.1:3999] [--segundos 300]
// =============================================================================
const path = require('path');
const RAIZ = path.join(__dirname, '..');
const { io } = require(path.join(RAIZ, 'backend-api', 'node_modules', 'socket.io-client'));

const arg = (n, p) => {
  const i = process.argv.indexOf('--' + n);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : p;
};
const URL_SOCKET = arg('url', 'https://gps-truck-backend.onrender.com');
const SEGUNDOS = Number(arg('segundos', 300));

const fs = require('fs');
const ARQUIVO = arg('arquivo', 'C:/Users/Micro/AppData/Local/Temp/gpsval/observador.log');
const inicio = Date.now();
const stamp = () => new Date().toISOString().slice(11, 19);

function linha(tag, texto) {
  const msg = `[${stamp()}] ${tag} ${texto}`;
  console.log(msg);
  try {
    fs.appendFileSync(ARQUIVO, msg + '\n');
  } catch (_) {}
}

const socket = io(URL_SOCKET, {
  transports: ['websocket'],
  auth: { token: undefined },
  reconnection: true,
  forceNew: true,
});

let ultimo = { id: null, nome: null };

socket.on('connect', () => {
  linha('CONECTADO', `observador no ar em ${URL_SOCKET}`);
  socket.emit('join_truck_network', {
    driverId: 'drv_observador_' + Date.now().toString(36),
    name: 'Observador',
    role: 'motorista',
  });
});

socket.on('connect_error', (e) => linha('ERRO', 'conexao: ' + e.message));

socket.on('trucks_radar_update', (lista) => {
  const novos = lista.filter((t) => t.driverId !== ultimo.id);
  for (const t of novos) {
    linha(
      'CAMINHAO',
      `${t.name} (${t.driverId}) lat=${Number(t.lat).toFixed(5)} lon=${Number(t.lon).toFixed(5)} ` +
        `vel=${Math.round(t.speedKmh || 0)}km/h caminhao=${t.truckModel || '-'} cargo=${t.cargoType || '-'}` +
        (t.avatarUrl ? ' [com foto]' : ''),
    );
  }
  if (novos.length) {
    const t = novos[0];
    ultimo = { id: t.driverId, nome: t.name };
  }
});

socket.on('receive_chat_message', (m) => {
  linha('CHAT', `${m.driverName}: ${m.message}${m.private ? ' [PRIVADO -> ' + m.targetDriverId + ']' : ' [PUBLICO]'}`);
});

socket.on('receive_truck_reaction', (r) => {
  linha('REACAO', `${r.fromName} -> ${r.targetDriverId || 'todos'}: ${r.emoji}`);
});

socket.on('receive_shared_route', (r) => {
  linha(
    'ROTA',
    `${r.fromName} compartilhou rota${r.groupId ? ' no grupo ' + r.groupId : ''}` +
      `${r.targetDriverId ? ' para ' + r.targetDriverId : ' (geral)'}: ` +
      String(r.routeJson || '').slice(0, 120),
  );
});

socket.on('receive_shared_place', (p) => {
  linha('LOCAL', `${p.fromName} compartilhou "${p.label}" (${p.lat}, ${p.lon})`);
});

socket.on('receive_alert_realtime', (a) => {
  linha('SINAL', `${a.type} - ${a.message || ''} em (${a.lat}, ${a.lon})`);
});

socket.on('road_validation_alerts', (lista) => {
  for (const a of lista) {
    linha('ALERTA_PROXIMO', `${a.alert_type || a.type} - ${a.message || ''}`);
  }
});

socket.on('receive_peer_alert', (a) => {
  linha('ALERTO_PEER', `${a.fromName} -> ${a.targetDriverId}: ${a.kind} ${a.message || ''}`);
});

socket.on('receive_group_invite', (i) => {
  linha('CONVITE', `${i.fromName} convidou para o grupo ${i.groupName}`);
});

socket.on('disconnect', (r) => linha('DESCONECTADO', r));

setTimeout(() => {
  linha('FIM', `observacao de ${SEGUNDOS}s encerrada`);
  socket.close();
  process.exit(0);
}, SEGUNDOS * 1000);
