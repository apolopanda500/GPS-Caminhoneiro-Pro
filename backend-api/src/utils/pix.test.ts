import test from 'node:test';
import assert from 'node:assert/strict';
import { buildPixPayload, crc16 } from './pix';

const base = {
  key: 'rickjax123@gmail.com',
  name: 'HENRIQUE DE CARVALHO',
  city: 'RIO DE JANEIRO',
  amount: 4.99,
  txid: 'pay_abc123',
  description: 'Assinatura Premium GPS Caminhoneiro Pro',
};

test('payload EMV inicia com a versao 000201', () => {
  assert.ok(buildPixPayload(base).startsWith('000201'));
});

test('payload contem a chave PIX e o valor formatado', () => {
  const payload = buildPixPayload(base);
  assert.ok(payload.includes('rickjax123@gmail.com'));
  assert.ok(payload.includes('54044.99'));
  const anual = buildPixPayload({ ...base, amount: 29.99 });
  assert.ok(anual.includes('540529.99'));
});

test('payload contem pais BR e moeda 986', () => {
  const payload = buildPixPayload(base);
  assert.ok(payload.includes('5802BR'));
  assert.ok(payload.includes('5303986'));
});

test('CRC final tem 4 caracteres hexadecimais', () => {
  const payload = buildPixPayload(base);
  const crc = payload.slice(-4);
  assert.match(crc, /^[0-9A-F]{4}$/);
  assert.equal(crc, crc16(payload.slice(0, -4)));
});

test('nome e cidade sao normalizados (sem acentos e em caixa alta)', () => {
  const payload = buildPixPayload({
    ...base,
    name: 'Henrique de Carvalho',
    city: 'São Paulo',
  });
  assert.ok(payload.includes('HENRIQUE DE CARVALHO'));
  assert.ok(payload.includes('SAO PAULO'));
});

test('txid invalido nao quebra o payload', () => {
  const payload = buildPixPayload({ ...base, txid: '***' });
  assert.ok(payload.endsWith(crc16(payload.slice(0, -4))));
});
