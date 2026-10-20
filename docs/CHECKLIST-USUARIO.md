# Checklist da sua parte (usuário) — GPS Caminhoneiro Pro

Tudo que depende de você (senha, cartão, painel) está aqui. Os scripts e os
valores já estão prontos: basta executar/colar.

---

## 1) Assinatura de release (importante: hoje o APK é assinado com chave de debug)

O APK atual está assinado com a chave de **debug** — isso quebra atualizações e
não serve para o Google Play.

**Rode** (troque a senha pela do seu keystore `upload-keystore.jks`):

```powershell
pwsh -File tools/preparar-release.ps1 -SenhaKeystore "SUA_SENHA_AQUI"
```

O script:
1. descobre o alias do keystore;
2. mostra o **SHA-1** e o **SHA-256** do certificado;
3. cria `frontend-flutter/android/key.properties` (já ignorado pelo git);
4. garante `key.properties` no `.gitignore`.

Depois recompile o APK:

```powershell
cd frontend-flutter
flutter build apk --release --dart-define-from-file=keys.json
```

> Para testar antes disso, o SHA-1 da chave de **debug** já está pronto:
> `22:7C:6B:5A:B5:07:F1:F3:55:BA:00:24:FD:68:6B:F9:3F:F9:D4:FB:E8:B7:C6:CB:2D:9D:41:9B:46:EB:A2:BA`

### ✅ Keystore de release já criado (20/10/2026)

O keystore de release definitivo já foi gerado e o `android/key.properties`
(configurado no Gradle) está correto — o APK release já sai assinado com ele.

| Item | Valor |
|---|---|
| Keystore | `frontend-flutter/android/app/upload-keystore.jks` (fora do git) |
| Alias | `upload` |
| Senha | ver `C:\Users\Micro\gps-keystore-senha.txt` (**guarde no gerenciador de senhas**) |
| SHA-1 | `72:ED:AA:CD:F3:E4:E7:3B:C4:9F:AA:1D:8A:2D:DD:81:80:9C:7D:67:98:C0:E7:16:E7:19:8B:B8:E6:F3:46:15` |
| SHA-256 | `72EDAACDF3E4E73BC49FAA1D8A2DDD81809C7D6798C0E716E7198BB8E6F34615` |

Esses dois valores vão no **Play Console → seu app → Teste interno → Gerenciar →
credenciais de assinatura** (upload key). Guarde a senha: sem ela você não
consegue gerar uma nova chave de upload.

> O keytool desta máquina (Java 8) não imprime o SHA-256; o script exporta o
> certificado e calcula o hash do DER.

---

## 2) Chave do Google (rotas com trânsito em tempo real)

Hoje a chave do Google responde **403** ("Requests from this Android client
application are blocked") porque está restrita para Android e o app não manda
os headers. O app já tem suporte: basta informar o SHA-1.

1. [Google Cloud Console](https://console.cloud.google.com) → **APIs e serviços** →
   **Credenciais** → sua chave do *Routes API*.
2. **Restrições de aplicativo** → *Android apps*:
   - Package name: `com.gpscamioneiro.gps_camioneiro_pro`
   - SHA-1: o que o script `preparar-release.ps1` mostrou
     (ou o SHA-1 de debug acima, se estiver testando).
3. Salve e espere alguns minutos.

Opcional: adicione o SHA-1 no `frontend-flutter/keys.json`:

```json
"APP_ANDROID_CERT_SHA1": "22:7C:6B:...:BA",
"APP_ANDROID_PACKAGE": "com.gpscamioneiro.gps_camioneiro_pro"
```

> Sem isso o app **ainda calcula rota** (OpenRouteService para caminhão + OSRM
> como reserva). O Google só entra como opção extra de trânsito ao vivo.

---

## 3) E-mail real (validação de conta) — Brevo

1. Crie conta em [brevo.com](https://www.brevo.com) e confirme o e-mail.
2. [SMTP & API](https://app.brevo.com/settings/keys/smtp) → **Gerar nova chave SMTP**.
3. No [Render](https://dashboard.render.com) → serviço **gps-truck-backend** →
   *Environment* → variáveis novas:

| Chave | Valor |
|---|---|
| `SMTP_HOST` | `smtp-relay.brevo.com` |
| `SMTP_PORT` | `587` |
| `SMTP_USER` | o login do SMTP (ex.: `abc123@smtp-relay.brevo.com`) |
| `SMTP_PASS` | a chave SMTP gerada |
| `SMTP_FROM` | `rickjax123@gmail.com` (ou o e-mail confirmado na Brevo) |

4. Salve → o Render faz novo deploy. No log deve aparecer
   `📧 Contas antigas sem validacao real: N` (a partir daí, **todas as contas
   passam a exigir o código de e-mail**).
5. Teste: cadastre um e-mail seu no app e confirme que o código chega.

> Enquanto o SMTP não estiver configurado, o **cadastro volta 503** (falha de
> propósito: sem validação de verdade não cria conta).

---

## 4) Banco de dados — **100% grátis** (sem plano pago)

O Postgres free do Render **expira em 18/11/2026** e o banco é apagado. Não vamos
pagar: o plano é **migrar para um Postgres gratuito que não expira**.

**Escolha (todas com plano grátis):**
- **Supabase** — 500 MB, não expira (pausa após 1 semana sem uso, retoma sozinho)
- **Neon** — 0,5 GB, sem expiração
- **Render free** — 30 dias (só como ponte)

**Passo 1 — crie o banco grátis** (Supabase: *New project → Database → URI*;
Neon: *Create project → connection string*).

**Passo 2 — me passe a URL** (ou cole no seu `backend-api/.env`, que é ignorado
pelo git — prefira isso, a senha não passa pelo chat):

```
SOURCE_DATABASE_URL=<url do Render (externa)>
TARGET_DATABASE_URL=<url do novo banco>
```

**Passo 3 — eu rodo a migração** (já está pronta):
```powershell
cd backend-api
$env:SOURCE_DATABASE_URL="..."; $env:TARGET_DATABASE_URL="..."
npm run migrate-data
```
Cria o schema no destino e copia drivers, alertas, mensagens, histórico,
contatos, pagamentos, grupos e códigos de verificação.

**Passo 4 — apontar o app para o novo banco** (grátis, 1 minuto):
No [Render](https://dashboard.render.com) → `gps-truck-backend` → *Environment* →
`DATABASE_URL` = a URL do banco novo → salvar (redeploy automático).
Depois eu rodo o backup e confirmo que está tudo lá.

> Alternativa sem mexer em nada: o app continua funcionando até 18/11 e a
> migração é feita depois. Mas o free apaga os dados nessa data, então o
> passo 2 é o que garante não perder nada.

---

## 5) IA do assistente (opcional)

Para o assistente responder com LLM em vez das respostas locais:

| Chave no Render (gps-truck-backend) | Valor |
|---|---|
| `OPENAI_API_KEY` | chave da OpenAI (`sk-...`) |
| `ANTHROPIC_API_KEY` | chave da Anthropic (`sk-ant-...`) |

Sem isso, o assistente **continua funcionando** (respostas locais sobre rota,
sinais, limite, clima e ajuda).

---

## 6) Release no Google Play (quando quiser publicar)

```powershell
cd frontend-flutter
flutter build appbundle --release --dart-define-from-file=keys.json
```

Sobe o arquivo `build/app/outputs/bundle/release/app-release.aab` no Play Console.
Guia completo em `GUIA-PLAY-STORE.md`.

---

## Como pedir ajuda de novo

- O outro agente e eu conversamos por `COORDENACAO-AGENTES.md` (leio e escrevo lá).
- O histórico das decisões está em `docs/CONVERSAS-A-B.md`.
