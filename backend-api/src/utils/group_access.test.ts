import { test } from 'node:test';
import assert from 'node:assert';
import { canSeeRoute } from './group_access';

const grupoPublico = { id: 'g1', is_public: true };
const grupoPrivado = { id: 'g2', is_public: false };

test('membro ve qualquer rota do grupo', () => {
  assert.equal(canSeeRoute(grupoPublico, { is_public: false, group_id: 'g1' }, true), true);
  assert.equal(canSeeRoute(grupoPrivado, { is_public: false, group_id: 'g2' }, true), true);
});

test('nao membro so ve rota publica em grupo publico', () => {
  assert.equal(canSeeRoute(grupoPublico, { is_public: true, group_id: 'g1' }, false), true);
  assert.equal(canSeeRoute(grupoPublico, { is_public: false, group_id: 'g1' }, false), false);
});

test('grupo privado esconde tudo de nao membros', () => {
  assert.equal(canSeeRoute(grupoPrivado, { is_public: true, group_id: 'g2' }, false), false);
  assert.equal(canSeeRoute(grupoPrivado, { is_public: false, group_id: 'g2' }, false), false);
});

test('grupo inexistente esconde rotas', () => {
  assert.equal(canSeeRoute(null, { is_public: true, group_id: 'x' }, false), false);
});
