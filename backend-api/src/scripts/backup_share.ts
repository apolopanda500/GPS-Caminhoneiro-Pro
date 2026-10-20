import { Client } from 'pg';
import { env } from '../config/env';

const TABLES = [
  'drivers',
  'road_alerts',
  'truck_messages',
  'travel_history',
  'driver_contacts',
  'payments',
];

/**
 * Backup "portatil": imprime o dump em base64 no log do job, para o arquivo
 * ser recuperado de fora (o container do job e efemero).
 */
export async function backupShare(): Promise<void> {
  const client = new Client({
    connectionString: env.databaseUrl,
    ssl: env.requiresSsl ? { rejectUnauthorized: false } : undefined,
  });
  await client.connect();

  const dump: Record<string, unknown[]> = {};
  for (const table of TABLES) {
    try {
      const result = await client.query(`SELECT * FROM ${table}`);
      dump[table] = result.rows;
    } catch (err) {
      dump[table] = [];
      console.error(`[backup] tabela ${table} indisponivel`);
    }
  }
  await client.end();

  const json = JSON.stringify(dump);
  const base64 = Buffer.from(json, 'utf8').toString('base64');
  console.log('BACKUP_BEGIN');
  console.log(base64);
  console.log('BACKUP_END');
}

if (require.main === module) {
  backupShare()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('Falha no backup:',
        error instanceof Error ? error.message : error);
      process.exit(1);
    });
}
