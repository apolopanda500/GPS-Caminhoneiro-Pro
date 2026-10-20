import { Client as PgClient } from 'pg';
import { SCHEMA_SQL } from '../db/schema';
import { splitStatements } from './migrate';
import { semSslMode } from '../utils/pg_url';
import dotenv from 'dotenv';
dotenv.config();

/**
 * Copia os dados de um Postgres para outro (usado para migrar do Render
 * free, que expira em 30 dias, para um Postgres gratuito que nao expira).
 *
 *   SOURCE_DATABASE_URL=... TARGET_DATABASE_URL=... node dist/scripts/migrate_data.js
 *
 * O schema e criado no destino (SCHEMA_SQL) e as tabelas sao copiadas.
 */

const TABELAS = [
  'drivers',
  'road_alerts',
  'truck_messages',
  'travel_history',
  'driver_contacts',
  'payments',
  'convoy_groups',
  'convoy_members',
  'group_shared_routes',
  'verification_codes',
];

function sslDe(url: string) {
  if (/sslmode=disable/i.test(url)) return undefined;
  if (/sslmode=/i.test(url) || /supabase\.com/i.test(url)) {
    return { rejectUnauthorized: false };
  }
  return undefined;
}

export async function migrarDados(
  sourceUrl: string,
  targetUrl: string,
): Promise<void> {
  if (!sourceUrl || !targetUrl) {
    throw new Error(
      'Defina SOURCE_DATABASE_URL e TARGET_DATABASE_URL antes de rodar.',
    );
  }
  const origem = new PgClient({
    connectionString: semSslMode(sourceUrl),
    ssl: sslDe(sourceUrl),
  });
  const destino = new PgClient({
    connectionString: semSslMode(targetUrl),
    ssl: sslDe(targetUrl),
  });

  await origem.connect();
  await destino.connect();

  console.log('>>> Criando o schema no banco de destino...');
  for (const statement of splitStatements(SCHEMA_SQL)) {
    try {
      await destino.query(statement);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      if (/postgis|extension/i.test(msg) && /permission|superuser/i.test(msg)) {
        console.warn('   (PostGIS precisa de superusuario: rode manualmente)');
        continue;
      }
      throw err;
    }
  }

  for (const tabela of TABELAS) {
    let linhas: any[] = [];
    try {
      const r = await origem.query(`SELECT * FROM ${tabela}`);
      linhas = r.rows;
    } catch {
      console.log(`   - ${tabela}: nao existe na origem, pulando`);
      continue;
    }
    if (linhas.length === 0) {
      console.log(`   - ${tabela}: vazia`);
      continue;
    }
    const colunas = Object.keys(linhas[0]);
    const colunasSql = colunas.map((c) => `"${c}"`).join(', ');
    let copiadas = 0;
    for (const linha of linhas) {
      const valores = colunas.map((c) => linha[c]);
      const placeholders = valores.map((_, i) => `$${i + 1}`).join(', ');
      try {
        await destino.query(
          `INSERT INTO "${tabela}" (${colunasSql}) VALUES (${placeholders})
           ON CONFLICT DO NOTHING`,
          valores,
        );
        copiadas++;
      } catch (err) {
        console.error(
          `   ! ${tabela}: ${err instanceof Error ? err.message : err}`,
        );
      }
    }
    console.log(`   - ${tabela}: ${copiadas} linha(s) copiada(s)`);
  }

  await origem.end();
  await destino.end();
  console.log('✅ Migracao concluida.');
}

if (require.main === module) {
  migrarDados(
    process.env.SOURCE_DATABASE_URL || '',
    process.env.TARGET_DATABASE_URL || '',
  )
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(
        '❌ Falha na migracao:',
        error instanceof Error ? error.message : error,
      );
      process.exit(1);
    });
}
