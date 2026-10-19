import { Client } from 'pg';
import { env } from '../config/env';
import * as fs from 'fs';
import * as path from 'path';

const TABLES = ['drivers', 'road_alerts', 'truck_messages', 'travel_history', 'driver_contacts', 'payments'];

export async function backupDatabase(): Promise<void> {
  const client = new Client({
    connectionString: env.databaseUrl,
    ssl: env.requiresSsl ? { rejectUnauthorized: false } : undefined,
  });
  await client.connect();

  const dump: Record<string, unknown[]> = {};
  for (const table of TABLES) {
    const result = await client.query(`SELECT * FROM ${table}`);
    dump[table] = result.rows;
  }
  await client.end();

  const dir = path.resolve(process.cwd(), 'backups');
  fs.mkdirSync(dir, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const file = path.join(dir, `backup-${stamp}.json`);
  fs.writeFileSync(file, JSON.stringify(dump, null, 2), 'utf8');
  console.log(`✅ Backup salvo em ${file}`);
}

if (require.main === module) {
  backupDatabase()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('❌ Falha no backup:', error instanceof Error ? error.message : error);
      process.exit(1);
    });
}
