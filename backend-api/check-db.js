const { Client } = require('pg');
const fs = require('fs');
const env = fs.readFileSync('backend-api/.env', 'utf8');
const pick = (key) => {
  const m = env.match(new RegExp('^' + key + '=(.*)$', 'm'));
  if (!m) return null;
  return m[1].replace(/\?sslmode=[\w-]+/, '').trim();
};
(async () => {
  for (const key of ['SOURCE_DATABASE_URL', 'TARGET_DATABASE_URL']) {
    const url = pick(key);
    const c = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
    try {
      await c.connect();
      const r = await c.query("select count(*)::int as total, max(created_at) as mais_recente from drivers");
      console.log(key.replace('_DATABASE_URL',''), '=> drivers:', r.rows[0].total, 'mais recente:', r.rows[0].mais_recente);
    } catch (e) {
      console.log(key.replace('_DATABASE_URL',''), '=> ERRO:', e.message);
    }
    await c.end().catch(() => {});
  }
})();
