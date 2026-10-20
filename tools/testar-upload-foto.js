// Testa o upload de foto grande de verdade (o limite antigo cortava em
// 100 KB do express e 900 KB do controller).
//
//   node tools/testar-upload-foto.js
//
// Gera uma imagem JPEG grande, loga no backend e envia.
const fs = require('fs');
const path = require('path');
const http = require('http');
const { spawn } = require('child_process');
const zlib = require('zlib');

const raiz = path.join(__dirname, '..');
const backend = path.join(raiz, 'backend-api');

function lerEnv(arquivo) {
  const env = {};
  if (!fs.existsSync(arquivo)) return env;
  for (const l of fs.readFileSync(arquivo, 'utf8').split(/\r?\n/)) {
    const m = l.match(/^([A-Z_]+)=(.*)$/);
    if (m) env[m[1]] = m[2].trim();
  }
  return env;
}

/** JPEG simples gerado no proprio script (grade colorida). */
function geraJpeg(lado) {
  const px = Buffer.alloc(lado * lado * 3);
  for (let y = 0; y < lado; y++) {
    for (let x = 0; x < lado; x++) {
      const i = (y * lado + x) * 3;
      px[i] = (x * 255) / lado;
      px[i + 1] = (y * 255) / lado;
      px[i + 2] = ((x + y) * 255) / (lado * 2);
    }
  }
  // BMP simples -> PNG via zlib nao e trivial; usamos o proprio JPEG do
  // dispositivo seria ideal, entao geramos um JPEG minimo conhecido.
  return pngMinimo(px, lado);
}

/** PNG minimo (sem compressao, so para ter bytes realistas). */
function pngMinimo(px, lado) {
  const chunk = (tipo, dados) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(dados.length);
    const corpo = Buffer.concat([Buffer.from(tipo, 'ascii'), dados]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(corpo) >>> 0);
    return Buffer.concat([len, corpo, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(lado, 0);
  ihdr.writeUInt32BE(lado, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  const raw = Buffer.alloc((lado * 3 + 1) * lado);
  for (let y = 0; y < lado; y++) {
    raw[y * (lado * 3 + 1)] = 0;
    px.copy(raw, y * (lado * 3 + 1) + 1, y * lado * 3, (y + 1) * lado * 3);
  }
  const idat = zlib.deflateSync(raw);
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', idat),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

let tabelaCrc = null;
function crc32(buf) {
  if (!tabelaCrc) {
    tabelaCrc = new Int32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      tabelaCrc[n] = c;
    }
  }
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = tabelaCrc[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return c ^ -1;
}

function pedir(metodo, caminho, corpo, headers = {}) {
  return new Promise((resolve) => {
    const dados = corpo ? JSON.stringify(corpo) : null;
    const req = http.request(
      {
        host: '127.0.0.1',
        port: 3000,
        path: caminho,
        method: metodo,
        headers: {
          'Content-Type': 'application/json',
          ...(dados ? { 'Content-Length': Buffer.byteLength(dados) } : {}),
          ...headers,
        },
        timeout: 30000,
      },
      (res) => {
        let b = '';
        res.on('data', (c) => (b += c));
        res.on('end', () => resolve({ status: res.statusCode, body: b }));
      },
    );
    req.on('error', (e) => resolve({ status: 0, body: e.message }));
    if (dados) req.write(dados);
    req.end();
  });
}

(async () => {
  const proc = spawn('node', ['dist/server.js'], { cwd: backend, env: process.env, stdio: 'pipe' });
  await new Promise((r) => setTimeout(r, 6000));

  const email = `upload_${Date.now()}@teste.com`;
  const senha = 'SenhaTeste123';
  let token = '';

  const reg = await pedir('POST', '/api/auth/register', {
    email,
    password: senha,
    name: 'Teste Upload',
  });
  console.log('cadastro:', reg.status);
  try {
    const j = JSON.parse(reg.body);
    token = j.token || j.accessToken || '';
    console.log('token:', token ? 'obtido' : 'ausente');
  } catch (_) {
    console.log(reg.body.slice(0, 200));
  }

  if (!token) {
    console.log('sem token: nao da para testar o upload');
    proc.kill();
    process.exit(1);
  }

  const img = geraJpeg(Number(process.env.LADO || 1200));
  const dataUrl = `data:image/png;base64,${img.toString('base64')}`;
  console.log(`imagem: ${(img.length / 1024).toFixed(0)} KB -> data URL ${(dataUrl.length / 1024).toFixed(0)} KB`);

  const up = await pedir(
    'POST',
    '/api/auth/photo',
    { data: dataUrl, kind: 'avatar' },
    { Authorization: `Bearer ${token}` },
  );
  console.log(`upload: ${up.status} | ${up.body.slice(0, 160)}`);
  const okUpload = up.status === 200;
  console.log(okUpload ? 'FOTO GRANDE ENVIADA E SALVA' : 'FALHA NO UPLOAD');

  proc.kill();
  process.exit(okUpload ? 0 : 1);
})();
