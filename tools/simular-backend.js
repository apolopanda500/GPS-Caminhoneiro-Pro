// Simulacao de carga do backend: milhares de requisicoes para achar falha
// escondida (corrida, payload invalido, injecao, timeout, vazamento).
//
//   node tools/simular-backend.js [rodadas] [concorrencia]
//
// Sobe o servidor local (mesmo banco do Render) e martela a API.
const { spawn } = require('child_process');
const http = require('http');
const path = require('path');
const fs = require('fs');

const RAIZ = path.join(__dirname, '..');
const BACKEND = path.join(RAIZ, 'backend-api');
const PORTA = 3999;
const RODADAS = Number(process.argv[2] || 200);
const CONCORRENCIA = Number(process.argv[3] || 12);

const erros = [];
let ok = 0;
let total = 0;
const tempos = [];

function pedir(metodo, caminho, corpo, headers = {}) {
  const dados = corpo ? JSON.stringify(corpo) : null;
  const inicio = Date.now();
  return new Promise((resolve) => {
    const req = http.request(
      {
        host: '127.0.0.1',
        port: PORTA,
        path: caminho,
        method: metodo,
        headers: {
          'Content-Type': 'application/json',
          ...(dados ? { 'Content-Length': Buffer.byteLength(dados) } : {}),
          ...headers,
        },
        timeout: 20000,
      },
      (res) => {
        let b = '';
        res.on('data', (c) => (b += c));
        res.on('end', () => {
          tempos.push(Date.now() - inicio);
          resolve({ status: res.statusCode, body: b });
        });
      },
    );
    req.on('error', (e) => resolve({ status: 0, body: e.message }));
    req.on('timeout', () => {
      req.destroy();
      resolve({ status: 0, body: 'timeout' });
    });
    if (dados) req.write(dados);
    req.end();
  });
}

function registrar(erro, contexto) {
  erros.push({ contexto, ...erro });
}

async function main() {
  console.log('Subindo o backend local...');
  const proc = spawn('node', ['dist/server.js'], {
    cwd: BACKEND,
    env: { ...process.env, PORT: String(PORTA) },
    stdio: 'pipe',
  });
  let log = '';
  proc.stdout.on('data', (d) => (log += d.toString()));
  proc.stderr.on('data', (d) => (log += d.toString()));

  await new Promise((r) => setTimeout(r, 12000));
  if (!log.includes('rodando na porta')) {
    console.log('Backend nao subiu:\n' + log.slice(-800));
    proc.kill();
    process.exit(1);
  }
  console.log('Backend no ar. Simulando...\n');

  const email = `sim_${Date.now()}@teste.com`;
  const senha = 'Simulacao123';

  // 1) Cadastro
  const reg = await pedir('POST', '/api/auth/register', {
    email,
    password: senha,
    name: 'Motorista Simulado',
  });
  total++;
  if (reg.status === 201 || reg.status === 200) ok++;
  else registrar({ status: reg.status, body: reg.body.slice(0, 160) }, 'register');

  let token = '';
  try {
    token = JSON.parse(reg.body).token || '';
  } catch (_) {}

  // 2) Login (a senha pode estar em branco se o cadastro exigir verificacao)
  const login = await pedir('POST', '/api/auth/login', { email, password: senha });
  total++;
  if (login.status === 200) {
    ok++;
    try {
      token = JSON.parse(login.body).token || token;
    } catch (_) {}
  } else if (login.status !== 401 && login.status !== 403) {
    registrar({ status: login.status, body: login.body.slice(0, 160) }, 'login');
  }

  const auth = token ? { Authorization: `Bearer ${token}` } : {};
  const driverId = (() => {
    try {
      return JSON.parse(reg.body).driverId || 'simulado';
    } catch (_) {
      return 'simulado';
    }
  })();

  // 3) Carga paralela: alertas, PIX, consultas e payloads hostis
  for (let rodada = 0; rodada < RODADAS; rodada++) {
    const lote = [];

    lote.push(
      pedir('POST', '/api/alerts', {
        type: 'sinal',
        message: `Sinal de teste ${rodada}`,
        lat: -22.9068 + (rodada % 10) * 0.001,
        lon: -43.1729 + (rodada % 7) * 0.001,
      }, auth).then((r) => {
        total++;
        if (r.status === 200 || r.status === 201) ok++;
        else registrar({ status: r.status, body: r.body.slice(0, 140) }, 'alerta');
      }),
    );

    lote.push(
      pedir('GET', '/api/alerts/nearby?lon=-43.1729&lat=-22.9068&radius=50000').then((r) => {
        total++;
        if (r.status === 200) ok++;
        else registrar({ status: r.status, body: r.body.slice(0, 140) }, 'nearby');
      }),
    );

    lote.push(
      pedir('GET', '/api/alerts/messages?lon=-43.1729&lat=-22.9068').then((r) => {
        total++;
        if (r.status === 200) ok++;
        else registrar({ status: r.status, body: r.body.slice(0, 140) }, 'messages');
      }),
    );

    lote.push(
      pedir('POST', '/api/payment/pix', { driverId: driverId, plan: 'mensal' }, auth).then((r) => {
        total++;
        if (r.status === 200 || r.status === 201) ok++;
        else registrar({ status: r.status, body: r.body.slice(0, 140) }, 'pix');
      }),
    );

    // Payloads hostis: nao podem derrubar o servidor nem o banco.
    lote.push(
      pedir('POST', '/api/alerts', {
        type: "'; DROP TABLE drivers; --",
        message: 'x'.repeat(5000),
        lat: 'abc',
        lon: null,
      }, auth).then((r) => {
        total++;
        if (r.status >= 400 && r.status < 500) ok++;
        else if (r.status >= 500) registrar({ status: r.status, body: r.body.slice(0, 140) }, 'payload hostil');
        else ok++;
      }),
    );

    lote.push(
      pedir('POST', '/api/auth/profile', {}, {
        Authorization: 'Bearer token.invalido.aqui',
      }).then((r) => {
        total++;
        if (r.status === 401 || r.status === 403) ok++;
        else registrar({ status: r.status, body: r.body.slice(0, 140) }, 'token invalido');
      }),
    );

    lote.push(
      pedir('POST', '/api/auth/login', { email: 'nao-e-email', password: '' }).then((r) => {
        total++;
        if (r.status >= 400 && r.status < 500) ok++;
        else registrar({ status: r.status, body: r.body.slice(0, 140) }, 'login invalido');
      }),
    );

    await Promise.all(lote);
    if ((rodada + 1) % 25 === 0) {
      process.stdout.write(
        `  rodada ${rodada + 1}/${RODADAS} - ${ok}/${total} ok, ${erros.length} problemas\n`,
      );
    }
  }

  // 4) O servidor continua de pe?
  const status = await pedir('GET', '/status');
  total++;
  if (status.status === 200) ok++;
  else registrar({ status: status.status, body: status.body.slice(0, 140) }, 'status final');

  proc.kill();

  const ordenados = [...tempos].sort((a, b) => a - b);
  const p = (q) => ordenados[Math.floor(ordenados.length * q)] || 0;

  console.log('\n================ RESULTADO ================');
  console.log(`requisicoes: ${total}`);
  console.log(`ok: ${ok}  (${((ok / total) * 100).toFixed(1)}%)`);
  console.log(`problemas: ${erros.length}`);
  console.log(
    `tempo: p50=${p(0.5)}ms p95=${p(0.95)}ms max=${p(1)}ms`,
  );
  if (erros.length) {
    console.log('\nprimeiros problemas:');
    for (const e of erros.slice(0, 12)) {
      console.log(`  [${e.contexto}] ${e.status} ${e.body}`);
    }
    const porContexto = {};
    for (const e of erros) {
      porContexto[e.contexto] = (porContexto[e.contexto] || 0) + 1;
    }
    console.log('\npor operacao:');
    for (const [k, v] of Object.entries(porContexto)) {
      console.log(`  ${k}: ${v}`);
    }
  }
  process.exit(erros.length ? 1 : 0);
}

main();
