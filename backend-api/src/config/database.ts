import { Client } from 'pg';
import { env } from './env';

export const db = new Client({
  connectionString: env.databaseUrl,
  ssl: env.requiresSsl ? { rejectUnauthorized: false } : undefined,
});

export async function connectDatabase(): Promise<void> {
  if (!env.databaseUrl) {
    console.error('❌ DATABASE_URL não configurada.');
    process.exit(1);
  }

  const maxAttempts = 10;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await db.connect();
      console.log('✅ Conectado ao banco PostGIS com sucesso.');
      db.on('error', (err) => console.error('❌ Erro ocioso no banco:', err.message));
      return;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`❌ Falha ao conectar ao banco (tentativa ${attempt}/${maxAttempts}): ${message}`);
      if (attempt === maxAttempts) {
        console.error('❌ Conexao com o banco indisponivel. O servico vai reiniciar.');
        process.exit(1);
      }
      await new Promise((resolve) => setTimeout(resolve, Math.min(30000, 3000 * attempt)));
    }
  }
}
