# 🚀 Deploy — Resumo Executivo

## 1. Banco de Dados (Supabase + PostGIS)
1. Criar conta gratuita no [Supabase](https://supabase.com)
2. Criar projeto (região São Paulo)
3. Executar `database/setup_postgis.sql` no SQL Editor
4. Obter `DATABASE_URL` (usar **pooler**, não host direto — IPv6-only falha no Render)

URL do pooler (exemplo):
```
postgresql://postgres.zvuuymewijwoppgwmpqy:<senha>@aws-0-us-east-1.pooler.supabase.com:5432/postgres?sslmode=require
```

## 2. Backend (Render)
1. Conectar repositório GitHub na [Render](https://render.com)
2. Build Command: `npm install && npm run build`
3. Start Command: `npm start`
4. Instance Type: Free
5. Variáveis de ambiente (ver tabela abaixo)

## 3. App Flutter
1. Configurar `baseUrl` e `socketUrl` em `app_constants.dart` (via `dart-define-from-file=keys.json`)
2. Chave Google Routes opcional para trânsito ao vivo
3. Registrar SHA-1 no Google Cloud Console (restrição Android)
4. Gerar APK: `flutter build apk --release --target-platform android-arm64`

## Variáveis de Ambiente da Render

| Variável | Valor Exemplo |
|----------|--------------|
| `DATABASE_URL` | URL do pooler Supabase |
| `PORT` | 3000 |
| `FRONTEND_URL` | * |
| `JWT_SECRET` | segredo aleatório |
| `ADMIN_TOKEN` | token de admin |
| `PIX_KEY` | rickjax123@gmail.com |
| `PIX_NAME` | HENRIQUE DE CARVALHO |
| `PIX_CITY` | RIO DE JANEIRO |
| `PIX_AMOUNT` | 4.99 |
| `PIX_DESCRIPTION` | Assinatura Premium GPS Caminhoneiro Pro |
| `SMTP_HOST` | smtp-relay.brevo.com |
| `SMTP_PORT` | 587 |
| `SMTP_SECURE` | false |
| `SMTP_USER` | bf0f3e001@smtp-brevo.com |
| `SMTP_PASS` | (segredo) |
| `SMTP_FROM` | rickjax1234@gmail.com |
| `GEMINI_API_KEY` | (opcional) |
| `NODE_VERSION` | 20 |
