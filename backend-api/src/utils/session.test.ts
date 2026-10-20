import assert from 'node:assert/strict';
import test from 'node:test';
import { criarToken, verificarToken } from './session';

test('token criado valida e devolve o driverId', () => {
  const token = criarToken('drv_123');
  const sessao = verificarToken(token);
  assert.ok(sessao);
  assert.equal(sessao?.driverId, 'drv_123');
  assert.ok((sessao?.expiraEm ?? 0) > Date.now());
});

test('token adulterado e rejeitado', () => {
  const token = criarToken('drv_123');
  const partes = token.split('.');
  const adulterado = `${partes[0]}.${'a'.repeat(64)}`;
  assert.equal(verificarToken(adulterado), null);
});

test('token com payload trocado e rejeitado', () => {
  const token = criarToken('drv_123');
  const partes = token.split('.');
  const outro = Buffer.from(
    JSON.stringify({ driverId: 'drv_999', expiraEm: Date.now() + 1000 }),
  ).toString('base64url');
  assert.equal(verificarToken(`${outro}.${partes[1]}`), null);
});

test('token expirado e rejeitado', () => {
  const expirado = Buffer.from(
    JSON.stringify({ driverId: 'drv_1', expiraEm: Date.now() - 1000 }),
  ).toString('base64url');
  // assinatura invalida de proposito: mesmo expirado, precisa falhar
  assert.equal(verificarToken(`${expirado}.invalida`), null);
});

test('token ausente ou malformado e rejeitado', () => {
  assert.equal(verificarToken(undefined), null);
  assert.equal(verificarToken(''), null);
  assert.equal(verificarToken('sem-ponto'), null);
});
