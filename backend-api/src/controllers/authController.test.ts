import assert from 'node:assert/strict';
import test from 'node:test';
import { AddressInfo } from 'node:net';
import express from 'express';
import { Client } from 'pg';
import * as mailer from '../utils/mailer';
import { AuthController } from './authController';
import { requireAuth } from '../middleware/auth';

// Evita e-mail real durante os testes.
const enviados: { to: string; code: string }[] = [];
(mailer as any).sendPasswordResetCode = async (
  to: string,
  code: string,
): Promise<boolean> => {
  enviados.push({ to, code });
  return true;
};
(mailer as any).sendVerificationCode = async (
  to: string,
  code: string,
): Promise<boolean> => {
  enviados.push({ to, code });
  return true;
};
(mailer as any).mailerConfigured = (): boolean => true;

/** Banco falso: responde conforme o SQL e guarda os INSERTs de codigos. */
class FakeDb {
  public drivers: any[] = [];
  public codes: any[] = [];
  private seq = 0;

  async query(sql: string, params: any[] = []): Promise<any> {
    const s = sql.trim().toLowerCase();

    if (s.startsWith('insert into verification_codes')) {
      this.codes.push({
        id: `vc_${++this.seq}`,
        email: params[0],
        code: params[1],
        purpose: params[2],
        consumed: false,
        expiresAt: Date.now() + 600000,
      });
      return { rows: [], rowCount: 1 };
    }

    if (s.startsWith('select id from verification_codes')) {
      const [email, code, purpose] = params;
      // O resetPassword fixa 'reset' no proprio SQL (sem parametro).
      const exigido = purpose ?? (s.includes("'reset'") ? 'reset' : undefined);
      const aceito = (c: any): boolean => {
        if (Array.isArray(exigido)) return exigido.includes(c.purpose);
        return c.purpose === exigido;
      };
      const found = this.codes.find(
        (c) =>
          c.email === email &&
          c.code === code &&
          !c.consumed &&
          c.expiresAt > Date.now() &&
          aceito(c),
      );
      return { rows: found ? [found] : [], rowCount: found ? 1 : 0 };
    }

    if (s.startsWith('update verification_codes set consumed')) {
      const found = this.codes.find((c) => c.id === params[0]);
      if (found) found.consumed = true;
      return { rows: [], rowCount: found ? 1 : 0 };
    }

    if (s.startsWith('update drivers set email_verified')) {
      const found = this.drivers.find((d) => d.email === params[0]);
      if (found) found.email_verified = true;
      return { rows: [], rowCount: found ? 1 : 0 };
    }

    if (s.startsWith('insert into drivers')) {
      const [id, email, hash, name] = params;
      this.drivers.push({
        driver_id: id,
        email,
        passwordHash: hash,
        name,
        email_verified: false,
      });
      return { rows: [], rowCount: 1 };
    }

    if (s.startsWith('select driver_id, email, name')) {
      const [email, hash] = params;
      const found = this.drivers.find(
        (d) => d.email === email && d.passwordHash === hash,
      );
      return { rows: found ? [found] : [], rowCount: found ? 1 : 0 };
    }

    if (s.startsWith('select driver_id from drivers')) {
      const found = this.drivers.find((d) => d.email === params[0]);
      return { rows: found ? [found] : [], rowCount: found ? 1 : 0 };
    }

    if (s.startsWith('update drivers set password_hash')) {
      const [email, hash] = params;
      const found = this.drivers.find((d) => d.email === email);
      if (found) found.passwordHash = hash;
      return { rows: [], rowCount: found ? 1 : 0 };
    }

    return { rows: [], rowCount: 0 };
  }
}

/** Resposta de express simulada. */
function fakeRes() {
  const res: any = { statusCode: 200, body: null as any };
  res.status = (code: number) => {
    res.statusCode = code;
    return res;
  };
  res.json = (payload: any) => {
    res.body = payload;
    return res;
  };
  return res;
}

function criarController() {
  const db = new FakeDb();
  const controller = new AuthController(db as unknown as Client);
  return { db, controller };
}


test('requestPasswordReset envia codigo com purpose reset', async () => {
  const { db, controller } = criarController();
  db.drivers.push({ driver_id: 'drv_1', email: 'joao@teste.com' });

  const res = fakeRes();
  await controller.requestPasswordReset(
    { body: { email: '  Joao@Teste.COM ' } } as any,
    res,
  );

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.equal(db.codes.length, 1);
  assert.equal(db.codes[0].email, 'joao@teste.com');
  assert.equal(db.codes[0].purpose, 'reset');
  assert.equal(db.codes[0].code.length, 6);
  assert.equal(enviados.length, 1);
  assert.equal(enviados[0].to, 'joao@teste.com');
});

test('requestPasswordReset nao revela se o e-mail nao existe', async () => {
  const { db, controller } = criarController();

  const res = fakeRes();
  await controller.requestPasswordReset(
    { body: { email: 'naoexiste@teste.com' } } as any,
    res,
  );

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.equal(db.codes.length, 0);
});

test('requestPasswordReset recusa e-mail invalido', async () => {
  const { controller } = criarController();

  const res = fakeRes();
  await controller.requestPasswordReset({ body: { email: 'abc' } } as any, res);
  assert.equal(res.statusCode, 400);
});

test('resetPassword troca a senha e consome o codigo', async () => {
  const { db, controller } = criarController();
  db.drivers.push({
    driver_id: 'drv_1',
    email: 'joao@teste.com',
    passwordHash: 'antigo',
  });

  const req = fakeRes();
  await controller.requestPasswordReset(
    { body: { email: 'joao@teste.com' } } as any,
    req,
  );
  const codigo = db.codes[0].code;

  const res = fakeRes();
  await controller.resetPassword(
    {
      body: { email: 'joao@teste.com', code: codigo, password: 'novasenha' },
    } as any,
    res,
  );

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.notEqual(db.drivers[0].passwordHash, 'antigo');
  assert.equal(db.codes[0].consumed, true);
});

test('resetPassword recusa codigo invalido', async () => {
  const { db, controller } = criarController();
  db.drivers.push({
    driver_id: 'drv_1',
    email: 'joao@teste.com',
    passwordHash: 'antigo',
  });

  const res = fakeRes();
  await controller.resetPassword(
    {
      body: { email: 'joao@teste.com', code: '000000', password: 'novasenha' },
    } as any,
    res,
  );

  assert.equal(res.statusCode, 400);
  assert.equal(db.drivers[0].passwordHash, 'antigo');
});

test('resetPassword recusa senha curta', async () => {
  const { controller } = criarController();
  const res = fakeRes();
  await controller.resetPassword(
    { body: { email: 'joao@teste.com', code: '123456', password: '123' } } as any,
    res,
  );
  assert.equal(res.statusCode, 400);
});

test('resetPassword nao aceita codigo de confirmacao de conta', async () => {
  const { db, controller } = criarController();
  db.drivers.push({
    driver_id: 'drv_1',
    email: 'joao@teste.com',
    passwordHash: 'antigo',
  });

  // Codigo de cadastro (purpose signup) nao serve para reset de senha.
  db.codes.push({
    id: 'vc_9',
    email: 'joao@teste.com',
    code: '111111',
    purpose: 'signup',
    consumed: false,
    expiresAt: Date.now() + 600000,
  });

  const res = fakeRes();
  await controller.resetPassword(
    {
      body: { email: 'joao@teste.com', code: '111111', password: 'novasenha' },
    } as any,
    res,
  );

  assert.equal(res.statusCode, 400);
  assert.equal(db.drivers[0].passwordHash, 'antigo');
});

/**
 * Fluxo completo pelas rotas HTTP:
 * cadastro -> recuperacao de senha -> login com a senha nova.
 */
test('fluxo HTTP: cadastrar, recuperar senha e entrar com a senha nova', async () => {
  const { db, controller } = criarController();

  const app = express();
  app.use(express.json());
  app.post(
    '/api/auth/register',
    controller.register.bind(controller),
  );
  app.post(
    '/api/auth/forgot-password',
    controller.requestPasswordReset.bind(controller),
  );
  app.post(
    '/api/auth/reset-password',
    controller.resetPassword.bind(controller),
  );
  app.post('/api/auth/login', controller.login.bind(controller));
  app.post('/api/auth/verify', controller.verifyCode.bind(controller));
  app.post('/api/auth/profile', requireAuth, controller.updateProfile.bind(controller));

  const server = app.listen(0);
  await new Promise((r) => server.once('listening', r));
  const porta = (server.address() as AddressInfo).port;
  const base = `http://127.0.0.1:${porta}`;

  try {
    // 1) Cadastro com e-mail misturado.
    const reg = await fetch(`${base}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: '  Motorista@Teste.COM  ',
        password: 'senha123',
        name: 'Motorista',
      }),
    });
    assert.equal(reg.status, 201);
    const regBody: any = await reg.json();
    assert.equal(regBody.requiresVerification, true);
    assert.equal(db.drivers[0].email, 'motorista@teste.com');

    // 1b) Confirma o e-mail com o codigo de cadastro.
    const signupCode = db.codes[db.codes.length - 1].code;
    const ver = await fetch(`${base}/api/auth/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'motorista@teste.com',
        code: signupCode,
      }),
    });
    assert.equal(ver.status, 200);
    assert.equal(db.drivers[0].email_verified, true);

    // 2) Recupera a senha.
    const fgt = await fetch(`${base}/api/auth/forgot-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'motorista@teste.com' }),
    });
    assert.equal(fgt.status, 200);
    const resetCode = db.codes[db.codes.length - 1].code;

    // 3) Define a senha nova.
    const rst = await fetch(`${base}/api/auth/reset-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'motorista@teste.com',
        code: resetCode,
        password: 'novasenha',
      }),
    });
    assert.equal(rst.status, 200);

    // 4) Login com a senha nova (e-mail em outra caixa) funciona.
    const login = await fetch(`${base}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'MOTORISTA@teste.com',
        password: 'novasenha',
      }),
    });
    assert.equal(login.status, 200);
    const loginBody: any = await login.json();
    assert.ok(loginBody.token);
    assert.equal(loginBody.driverId, db.drivers[0].driver_id);

    // 5) A senha antiga nao funciona mais.
    const loginAntigo = await fetch(`${base}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'motorista@teste.com',
        password: 'senha123',
      }),
    });
    assert.equal(loginAntigo.status, 401);
  } finally {
    server.close();
  }
});
