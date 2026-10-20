# Configuração pendente no Render e no Google Cloud

Dois ajustes que **só você pode fazer** (precisam do seu login). Depois de
aplicar, o app usa o banco que **não expira** e a rota com trânsito ao vivo
passa a funcionar no modo "trânsito".

---

## 1) Render: apontar o serviço para o Supabase

O banco `gps-truck-postgis` do Render **expira em 18/11/2026**. Os dados já
foram copiados para o Supabase (14 motoristas, 4 alertas, 3 mensagens,
1 pagamento, 44 códigos de verificação). Falta só trocar a conexão.

### Passo a passo

1. Abra <https://dashboard.render.com>
2. Entre em **gps-truck-backend** (o serviço web, não o banco)
3. Menu lateral → **Environment**
4. Edite a variável **`DATABASE_URL`** e cole exatamente isto:

```
postgresql://postgres.zvuuymewijwoppgwmpqy:IRazzu8dmn2CS7Ch@aws-0-us-east-1.pooler.supabase.com:5432/postgres?sslmode=require
```

5. Clique em **Save Changes** — o Render faz o redeploy sozinho
6. Espere o deploy terminar e confira em <https://gps-truck-backend.onrender.com/status>

### Como saber que deu certo

```json
{"status":"online","database":"connected","active_trucks":0}
```

O campo `database` tem que estar **connected**. Se aparecer `error`, veja o
log do serviço: o erro real aparece agora (antes era genérico).

### ⚠️ Por que o pooler e não o host direto

| Host | Tipo | Funciona no Render? |
|---|---|---|
| `db.zvuuymewijwoppgwmpqy.supabase.co` | IPv6-only | ❌ `ENOTFOUND` |
| `aws-0-us-east-1.pooler.supabase.com` | IPv4 | ✅ |

O Render não tem IPv6, então o host direto nunca vai funcionar lá.

### Depois de confirmar

O banco `gps-truck-postgis` do Render pode ser apagado à vontade
(Render → banco → **Delete Database**). Antes disso, confira que o app
continua funcionando com o mesmo login.

### Outras variáveis do Render (confira se estão lá)

| Variável | Valor |
|---|---|
| `FRONTEND_URL` | `*` |
| `JWT_SECRET` | o valor do seu `backend-api/.env` |
| `ADMIN_TOKEN` | o valor do seu `backend-api/.env` |
| `PIX_KEY` | `rickjax123@gmail.com` |
| `PIX_NAME` | `HENRIQUE DE CARVALHO` |
| `PIX_CITY` | `RIO DE JANEIRO` |
| `PIX_AMOUNT` | `4.99` |
| `PIX_DESCRIPTION` | `Assinatura Premium GPS Caminhoneiro Pro` |
| `SMTP_HOST` | `smtp-relay.brevo.com` |
| `SMTP_PORT` | `587` |
| `SMTP_SECURE` | `false` |
| `SMTP_USER` | `bf0f3e001@smtp-brevo.com` |
| `SMTP_PASS` | o valor do seu `backend-api/.env` |
| `SMTP_FROM` | `rickjax1234@gmail.com` |
| `GEMINI_API_KEY` | (opcional) a chave do Google AI Studio |
| `NODE_VERSION` | `20` |

> `SOURCE_DATABASE_URL` e `TARGET_DATABASE_URL` **não** precisam ir no Render:
> elas só são usadas na migração (`npm run migrate-data`).

---

## 2) Google Cloud Console: registrar os SHA-1 da chave do Routes

A chave do Google Routes responde **403** ("Requests from this Android
client application ... are blocked") porque a chave está restrita para
Android e o SHA-1 registrado no console não bate com o do build instalado.

### Os dois SHA-1 do projeto

| Keystore | SHA-1 | Quando usar |
|---|---|---|
| `android/app/upload-keystore.jks` (release) | `2F:AE:30:A2:3F:CC:E2:5F:29:08:2A:CE:4B:02:02:07:C9:54:83:34` | **APK de release** (Play Store) |
| `~/.android/debug.keystore` (debug) | `C4:EB:B1:5B:BA:7F:D2:7F:79:FA:45:6E:DF:B3:E6:09:57:73:14:DD` | APK de debug (testes) |

**Package name:** `com.gpscamioneiro.gps_camioneiro_pro`

> Atenção: o `keytool` em português **desloca os rótulos** das impressões
> digitais (o que ele chama de "SHA1" é o SHA-256). Use
> `keytool -J-Duser.language=en -J-Duser.country=US` para ler o valor certo,
> ou confira com o `apksigner` do APK pronto.

### Passo a passo

1. Abra <https://console.cloud.google.com> → projeto do app
2. **APIs e serviços** → **Credenciais**
3. Abra a chave do **Routes API** (a mesma do `keys.json`)
4. Em **Restrições de aplicativo** → *Android apps* → **Adicionar**
5. Cadastre **duas** entradas (mesmo pacote, SHA-1 diferente):

   | Nome do app | Package name | SHA-1 |
   |---|---|---|
   | GPS Caminhoneiro Pro (release) | `com.gpscamioneiro.gps_camioneiro_pro` | `2F:AE:30:A2:3F:CC:E2:5F:29:08:2A:CE:4B:02:02:07:C9:54:83:34` |
   | GPS Caminhoneiro Pro (debug) | `com.gpscamioneiro.gps_camioneiro_pro` | `C4:EB:B1:5B:BA:7F:D2:7F:79:FA:45:6E:DF:B3:E6:09:57:73:14:DD` |

6. **Salvar** e aguardar alguns minutos (a propagação leva ~5 min)

### Como saber que deu certo

O app passa a calcular a rota pelo Google com trânsito ao vivo. Sem isso
**o app continua funcionando**: a rota sai pelo OpenRouteService (caminhão),
depois TomTom (trânsito ao vivo) e por fim OSRM (reserva).

### Teste rápido (opcional)

```bash
curl -s -X POST "https://routes.googleapis.com/directions/v2:computeRoutes" \
  -H "Content-Type: application/json" \
  -H "X-Goog-Api-Key: SUA_CHAVE" \
  -H "X-Android-Package: com.gpscamioneiro.gps_camioneiro_pro" \
  -H "X-Android-Cert: 2F:AE:30:A2:3F:CC:E2:5F:29:08:2A:CE:4B:02:02:07:C9:54:83:34" \
  -H "X-Goog-FieldMask: routes.distanceMeters" \
  -d '{"origin":{"location":{"lat":-22.9068,"lng":-43.1729}},
       "destination":{"location":{"lat":-22.9519,"lng":-43.2105}},
       "travelMode":"DRIVE"}'
```

Resposta com `"routes"` = funcionando. `"blocked"` = ainda falta registrar.

---

## 3) Rotina de segurança recomendada

A senha do banco do Supabase foi exposta no chat durante a configuração.
Depois de trocar o `DATABASE_URL` no Render:

1. Supabase → **Project Settings** → **Database** → **Reset database password**
2. Defina uma nova senha
3. Atualize o `DATABASE_URL` no Render com a nova senha
4. Atualize o `backend-api/.env` local (é ignorado pelo git)

---

## Verificação do ambiente

Depois de tudo, rode:

```bash
node tools/validar-ambiente.js
node tools/validar-pix.js
```

O primeiro confere chaves, build, testes e git; o segundo confere o BR Code
do PIX e recalcula o CRC16.
