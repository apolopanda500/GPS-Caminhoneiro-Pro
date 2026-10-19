# 🚀 Deploy no Render (backend + Postgres/PostGIS) — passo a passo

> Tudo já está preparado no repositório. Você precisa executar **3 etapas manuais**
> (GitHub, Blueprint no Render, rebuild do APK). O schema do banco é criado
> **automaticamente** pelo backend no boot (não precisa rodar SQL na mão).

---

## Etapa 1 — Publicar o código no GitHub (5 min)

O Render só consegue fazer deploy de repositórios Git. Rode no PowerShell, na raiz
`C:\Users\Micro\gps-camioneiro-pro-completo`:

```powershell
cd C:\Users\Micro\gps-camioneiro-pro-completo
git init
git add .
git commit -m "GPS Caminhoneiro Pro - backend, frontend e infra Render"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/gps-camioneiro-pro.git
git push -u origin main
```

Antes disso, crie o repositório em <https://github.com/new> (marque **Private**).
Se já existir repositório, apenas ajuste a URL do `git remote add origin`.

> `.gitignore` já exclui `keys.json`, `upload-keystore.jks` e `key.properties` —
> nenhuma chave/segredo vai para o GitHub.

---

## Etapa 2 — Criar tudo no Render com 1 clique (Blueprint)

1. Abra <https://dashboard.render.com> e logue-se.
2. Menu **New → Blueprint**.
3. Conecte/conecte-se à conta GitHub e escolha o repositório `gps-camioneiro-pro`.
4. Render detecta o `render.yaml` na raiz. Confirme:
   - `gps-truck-postgis` (Postgres Free, 1 GB)
   - `gps-truck-backend` (Web Service Free, Node 20)
5. Clique **Apply**.

O Render faz tudo sozinho:
- cria o banco e injeta `DATABASE_URL` no serviço (`fromDatabase`);
- gera `JWT_SECRET`;
- faz build (`npm ci && npm run build`) e deploy;
- na subida, o backend roda a migração (`✅ Schema atualizado`) e sobe o servidor.

### Acompanhar e resolver problemas

- **Logs do deploy**: Render → `gps-truck-backend` → **Logs**. Deve aparecer
  `🔧 Executando migracao do schema...` e `✅ Conectado ao banco PostGIS`.
- **Se der erro na extensão PostGIS** (o usuário do banco não é superuser),
  o log mostra o aviso. Faça manualmente uma única vez:
  1. Render → `gps-truck-postgis` → **Shell**
  2. rode: `CREATE EXTENSION IF NOT EXISTS postgis;`
  3. Render → `gps-truck-backend` → **Manual Deploy** → *Deploy latest commit*
- **Teste rápido**: <https://gps-truck-backend.onrender.com/status> deve retornar
  `{"status":"online","database":"connected",...}`.
- `https://gps-truck-backend.onrender.com/` lista os endpoints da API.

### Free tier: o que esperar (importante)

| Item | Limite free | Impacto |
|---|---|---|
| Web service | dorme após 15 min sem tráfego | o primeiro request após o "sleep" demora ~30 s (cold start) |
| Postgres | expira em **30 dias** (14 dias de carência) | o banco é **deletado** se não fizer upgrade |
| Armazenamento | 1 GB | suficiente para o app |

Mitigações recomendadas:
- **Keep-alive** (acorda o serviço): crie um monitor em
  <https://uptimerobot.com> apontando para `/status` a cada 10 min (grátis).
  O Socket.io já mantém o serviço acordado enquanto houver caminhão conectado.
- **Backup do banco** antes do dia 30 (o backend tem script pronto):
  ```powershell
  cd backend-api
  $env:DATABASE_URL="postgresql://<user>:<senha>@<host>/gps_truck_pro"
  npm run build; npm run backup     # salva em backend-api/backups/backup-<data>.json
  ```
  Para restaurar em outro banco, basta rodar o mesmo script apontando para a
  nova `DATABASE_URL` (o `INSERT` é reexecutado) — ou usar `pg_dump`/`pg_restore`.

---

## Etapa 3 — Apontar o app Android para o Render (3 min)

1. Edite `frontend-flutter/keys.json`:
   ```json
   {
     "API_URL": "https://gps-truck-backend.onrender.com",
     "SOCKET_URL": "https://gps-truck-backend.onrender.com",
     "GOOGLE_ROUTES_KEY": "<sua chave>",
     "ORS_KEY": "<sua chave>"
   }
   ```
2. Build do APK com as chaves injetadas:
   ```powershell
   cd frontend-flutter
   & "C:\Users\Micro\flutter\bin\flutter.bat" build apk --release --dart-define-from-file=keys.json
   ```
3. Instalar no aparelho:
   ```powershell
   adb install -r build\app\outputs\flutter-apk\app-release.apk
   ```

O app detecta que `API_URL` ≠ valor padrão e passa a usar o modo online
(antes disso ele roda em modo local/offline).

---

## Checklist final

- [ ] `git push` feito (repo privado no GitHub)
- [ ] Blueprint aplicado: banco + serviço criados
- [ ] `CREATE EXTENSION postgis;` executado no Shell (se o log pedir)
- [ ] `/status` retorna `database: connected`
- [ ] `keys.json` apontando para `https://gps-truck-backend.onrender.com`
- [ ] APK release instalado e testado (login, radar, chat, sinalização)
- [ ] Keep-alive configurado (UptimeRobot) e backup agendado antes do dia 30

## Variáveis de ambiente (referência)

| Variável | Origem | Observação |
|---|---|---|
| `DATABASE_URL` | automática (`fromDatabase`) | não cole no GitHub |
| `JWT_SECRET` | automática (`generateValue`) | não cole no GitHub |
| `PORT` | `3000` | Render injeta a porta real |
| `FRONTEND_URL` | `*` | restrinja ao seu domínio em produção |
| `NODE_VERSION` | `20` | mesma major do build local |
