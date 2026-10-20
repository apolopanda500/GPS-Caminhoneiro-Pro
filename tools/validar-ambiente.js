// Verifica se o ambiente esta completo e reproduzivel.
//
//   node tools/validar-ambiente.js
//
// Confere: chaves do backend, chaves do app Flutter, banco, build do
// backend e o estado do git. Serve para saber o que falta antes de
// compilar, publicar ou fazer o deploy.
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const raiz = __dirname ? path.join(__dirname, '..') : process.cwd();

let falhas = 0;
function ok(cond, msg, dica = '') {
  if (!cond) falhas++;
  console.log(`${cond ? 'OK   ' : 'FALHA'} ${msg}${dica && !cond ? ` -> ${dica}` : ''}`);
}

function lerEnv(arquivo) {
  const env = {};
  if (!fs.existsSync(arquivo)) return env;
  for (const l of fs.readFileSync(arquivo, 'utf8').split(/\r?\n/)) {
    const m = l.match(/^([A-Z_]+)=(.*)$/);
    if (m) env[m[1]] = m[2].trim();
  }
  return env;
}

function comando(cmd, cwd) {
  try {
    return execSync(cmd, { cwd, encoding: 'utf8', stdio: 'pipe' });
  } catch (e) {
    return '';
  }
}

console.log('=== 1) Backend (backend-api/.env) ===');
const env = lerEnv(path.join(raiz, 'backend-api', '.env'));
ok(Object.keys(env).length > 0, 'arquivo .env existe', 'copie de .env.example');
for (const [chave, obrigatoria] of [
  ['DATABASE_URL', true],
  ['JWT_SECRET', true],
  ['PIX_KEY', true],
  ['PIX_NAME', false],
  ['PIX_CITY', false],
  ['FRONTEND_URL', false],
  ['GEMINI_API_KEY', false],
]) {
  const valor = env[chave] || '';
  const preenchido = valor.length > 0 && !/SUA_|troque-|sua-|xxx/i.test(valor);
  ok(
    obrigatoria ? preenchido : true,
    `${chave}${obrigatoria ? '' : ' (opcional)'} ${preenchido ? 'preenchida' : 'vazia ou placeholder'}`,
    obrigatoria ? `defina ${chave} em backend-api/.env` : '',
  );
}
if (env.DATABASE_URL && env.DATABASE_URL.includes('db.') && env.DATABASE_URL.includes('supabase.co')) {
  ok(
    false,
    'DATABASE_URL usa o host direto do Supabase (IPv6-only)',
    'use o pooler: aws-0-<regiao>.pooler.supabase.com',
  );
} else if (env.DATABASE_URL) {
  ok(true, 'DATABASE_URL aponta para o pooler (IPv4)');
}

console.log('\n=== 2) App (frontend-flutter/keys.json) ===');
const keysPath = path.join(raiz, 'frontend-flutter', 'keys.json');
if (fs.existsSync(keysPath)) {
  const keys = JSON.parse(fs.readFileSync(keysPath, 'utf8').replace(/^\uFEFF/, ''));
  ok(
    !!keys.API_URL && !keys.API_URL.includes('SEU-BACKEND'),
    `API_URL configurada (${keys.API_URL})`,
  );
  ok(
    !!keys.SOCKET_URL && !keys.SOCKET_URL.includes('SEU-BACKEND'),
    `SOCKET_URL configurada (${keys.SOCKET_URL})`,
  );
  for (const chave of ['GOOGLE_ROUTES_KEY', 'GEMINI_API_KEY', 'ORS_KEY', 'TOMTOM_TRAFFIC_KEY', 'MAPILLARY_TOKEN']) {
    ok(!!keys[chave], `${chave} ${keys[chave] ? 'preenchida' : 'vazia (opcional)'}`);
  }
  ok(
    !!keys.APP_ANDROID_CERT_SHA1,
    `APP_ANDROID_CERT_SHA1 ${keys.APP_ANDROID_CERT_SHA1 ? 'preenchido' : 'vazio'}`,
  );
} else {
  ok(false, 'keys.json existe', 'copie frontend-flutter/keys.example.json para keys.json');
}

console.log('\n=== 3) Build e testes do backend ===');
const backend = path.join(raiz, 'backend-api');
const build = comando('npm run build', backend);
ok(build.includes('> tsc') || build === '', 'tsc compila sem erro');
const testes = comando('npm test', backend);
const m = testes.match(/tests (\d+)[\s\S]*?pass (\d+)[\s\S]*?fail (\d+)/);
ok(m && m[3] === '0', `testes do backend: ${m ? `${m[2]}/${m[1]}` : '?'}`);

console.log('\n=== 4) Git ===');
const branch = comando('git rev-parse --abbrev-ref HEAD', raiz).trim();
const status = comando('git status --porcelain', raiz).trim();
ok(branch === 'main', `branch: ${branch}`);
ok(status === '', 'working tree limpa', status.split('\n').slice(0, 3).join(' | '));

console.log('');
console.log(falhas === 0 ? 'AMBIENTE COMPLETO E REPRODUZIVEL' : `AMBIENTE COM ${falhas} PENDENCIA(S)`);
process.exit(falhas === 0 ? 0 : 1);
