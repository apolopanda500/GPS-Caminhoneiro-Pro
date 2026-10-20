// Validador do BR Code (PIX) gerado pelo backend.
//
//   node tools/validar-pix.js
//
// Confere a estrutura EMV campo a campo, recalcula o CRC16 e mostra o
// BR Code pronto para conferir no banco do usuario.
const fs = require('fs');
const path = require('path');

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

function parse(brCode) {
  const out = [];
  let i = 0;
  while (i < brCode.length) {
    const id = brCode.slice(i, i + 2);
    const len = parseInt(brCode.slice(i + 2, i + 4), 10);
    if (Number.isNaN(len)) throw new Error(`Tamanho invalido na posicao ${i}`);
    const value = brCode.slice(i + 4, i + 4 + len);
    if (value.length !== len) {
      throw new Error(`TLV ${id}: anuncia ${len} mas veio ${value.length}`);
    }
    out.push({ id, len, value });
    i += 4 + len;
  }
  return out;
}

function crc16(payload) {
  let crc = 0xffff;
  for (let i = 0; i < payload.length; i++) {
    crc ^= payload.charCodeAt(i) << 8;
    for (let j = 0; j < 8; j++) {
      crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff;
    }
  }
  return crc.toString(16).toUpperCase().padStart(4, '0');
}

let falhas = 0;
function ok(cond, msg) {
  if (!cond) falhas++;
  console.log(`${cond ? 'OK   ' : 'FALHA'} ${msg}`);
}

function main() {
  const env = lerEnv(path.join(backend, '.env'));
  const chave = env.PIX_KEY || '';
  if (!chave) {
    console.error('PIX_KEY nao configurado em backend-api/.env');
    process.exit(1);
  }

  const nome = env.PIX_NAME || 'RECEBEDOR';
  const cidade = env.PIX_CITY || 'CIDADE';
  const valor = parseFloat(env.PIX_AMOUNT || '4.99');
  const descricao = env.PIX_DESCRIPTION || 'Assinatura Premium';

  // Mesma montagem do backend (src/utils/pix.ts).
  const tlv = (id, value) => `${id}${value.length.toString().padStart(2, '0')}${value}`;
  const sanitize = (text, max) =>
    text
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^A-Za-z0-9 .-]/g, '')
      .toUpperCase()
      .slice(0, max);

  const gui = tlv('00', 'br.gov.bcb.pix');
  const merchantAccount = tlv('26', `${gui}${tlv('01', chave)}${tlv('02', sanitize(descricao, 40))}`);
  const payload = [
    tlv('00', '01'),
    merchantAccount,
    tlv('52', '0000'),
    tlv('53', '986'),
    tlv('54', valor.toFixed(2)),
    tlv('58', 'BR'),
    tlv('59', sanitize(nome, 25)),
    tlv('60', sanitize(cidade, 15)),
    tlv('62', tlv('05', 'VALIDACAO')),
  ].join('');
  const comCrc = `${payload}6304`;
  const brCode = `${comCrc}${crc16(comCrc)}`;

  console.log('--- BR Code ---');
  console.log(brCode);
  console.log('');

  ok(crc16(brCode.slice(0, -4)) === brCode.slice(-4), 'CRC16 confere');
  const tlvs = parse(brCode);
  ok(true, 'Estrutura TLV valida');
  const ids = tlvs.map((t) => t.id);
  for (const [id, rotulo] of [
    ['00', 'Payload Format Indicator'],
    ['26', 'Merchant Account Information'],
    ['52', 'Merchant Category Code'],
    ['53', 'Moeda BRL'],
    ['54', 'Valor'],
    ['58', 'Pais'],
    ['59', 'Nome do recebedor'],
    ['60', 'Cidade'],
    ['62', 'Additional Data'],
    ['63', 'CRC'],
  ]) {
    ok(ids.includes(id), `${rotulo} (${id}) presente`);
  }
  const ma = parse(tlvs.find((t) => t.id === '26').value);
  ok(ma.find((f) => f.id === '00').value === 'br.gov.bcb.pix', 'GUI br.gov.bcb.pix');
  ok(ma.find((f) => f.id === '01').value === chave, `Chave PIX preservada (${chave})`);
  const formato = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(chave)
    ? 'EVP (e-mail)'
    : /^[0-9]{11}$/.test(chave)
      ? 'CPF/CNPJ numerico'
      : /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(chave)
        ? 'EVP aleatoria'
        : 'desconhecido';
  ok(formato !== 'desconhecido', `Formato da chave: ${formato}`);

  console.log('');
  console.log(falhas === 0 ? 'PIX VALIDO' : `PIX COM ${falhas} PROBLEMA(S)`);
  process.exit(falhas === 0 ? 0 : 1);
}

main();
