import assert from 'node:assert/strict';
import test from 'node:test';
import { responderLocal, ContextoAssistente } from './assistant';

const base: ContextoAssistente = {
  totalParadas: 0,
  entregasFeitas: 0,
  velocidade: null,
  limiteVelocidade: null,
  rua: null,
  alertas: [],
  clima: null,
};

test('pergunta sobre a rota sem rota responde como montar', () => {
  const r = responderLocal('como esta minha rota?', base);
  assert.match(r, /ainda nao montou rota/);
});

test('pergunta sobre a rota com paradas lista os dados', () => {
  const r = responderLocal('minha rota', {
    ...base,
    totalParadas: 3,
    entregasFeitas: 1,
  });
  assert.match(r, /3 parada/);
  assert.match(r, /1 ja entregue/);
});

test('pergunta sobre sinais lista os sinais', () => {
  const r = responderLocal('tem sinal perto?', {
    ...base,
    alertas: ['[SINAL] curva'],
  });
  assert.match(r, /curva/);
});

test('pergunta de velocidade compara com o limite', () => {
  const r = responderLocal('qual o limite?', {
    ...base,
    velocidade: 95,
    limiteVelocidade: 80,
    rua: 'BR-101',
  });
  assert.match(r, /95 km\/h/);
  assert.match(r, /ACIMA DO LIMITE/);
});

test('pergunta de clima informa o alerta', () => {
  const r = responderLocal('esta chovendo?', {
    ...base,
    clima: 'Chuva forte a 10 km.',
  });
  assert.match(r, /Chuva forte/);
});

test('pergunta vazia lista o que o assistente sabe', () => {
  const r = responderLocal('', base);
  assert.match(r, /rota/);
});
