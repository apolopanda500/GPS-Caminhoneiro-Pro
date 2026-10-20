import { Client } from 'pg';
import { SCHEMA_SQL } from '../db/schema';
import { env } from '../config/env';
import { mailerConfigured } from '../utils/mailer';

export function splitStatements(sql: string): string[] {
  const statements: string[] = [];
  let buffer = '';
  let inDollar = false;

  for (let i = 0; i < sql.length; i++) {
    const chunk = sql.slice(i, i + 2);
    if (chunk === '$$') {
      inDollar = !inDollar;
      buffer += chunk;
      i++;
      continue;
    }
    if (!inDollar && sql[i] === ';') {
      const statement = buffer.trim();
      if (statement) statements.push(statement);
      buffer = '';
      continue;
    }
    buffer += sql[i];
  }

  const last = buffer.trim();
  if (last) statements.push(last);
  return statements;
}

export async function runMigrations(): Promise<void> {
  const client = new Client({
    connectionString: env.databaseUrl,
    ssl: env.requiresSsl ? { rejectUnauthorized: false } : undefined,
  });

  await client.connect();
  console.log('🔧 Executando migracao do schema...');

  const statements = splitStatements(SCHEMA_SQL);
  for (const statement of statements) {
    const label = statement.split('\n')[0].slice(0, 70);
    try {
      await client.query(statement);
      console.log(`   ✅ ${label}`);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (/postgis|extension/i.test(message) && /permission|superuser/i.test(message)) {
        console.error('⚠️  Extensao PostGIS exige superusuario.');
        console.error('   Rode manualmente no Render Shell (banco gps-truck-postgis):');
        console.error('   CREATE EXTENSION IF NOT EXISTS postgis;');
        continue;
      }
      console.error(`   ❌ ${label} -> ${message}`);
      throw error;
    }
  }

  await client.end();
  console.log('✅ Schema atualizado.');
}

/**
 * Contas criadas enquanto o SMTP nao estava configurado nunca foram
 * validadas de verdade. Quando o e-mail passa a funcionar, elas voltam a
 * exigir confirmacao no proximo login.
 */
export async function backfillVerificacoes(): Promise<void> {
  if (!mailerConfigured()) {
    console.log('📧 SMTP ainda nao configurado: validacao real aguardando.');
    return;
  }
  const client = new Client({
    connectionString: env.databaseUrl,
    ssl: env.requiresSsl ? { rejectUnauthorized: false } : undefined,
  });
  await client.connect();
  try {
    const result = await client.query(
      `UPDATE drivers SET email_verified = FALSE
       WHERE email_verified = TRUE AND verified_at IS NULL`
    );
    console.log(
      `📧 Contas antigas sem validacao real: ${result.rowCount ?? 0}`
    );
  } finally {
    await client.end();
  }
}

if (require.main === module) {
  runMigrations()
    .then(() => backfillVerificacoes())
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('❌ Falha na migracao:', error instanceof Error ? error.message : error);
      process.exit(1);
    });
}
