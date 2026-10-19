# 🚀 GUIA DE DEPLOY - Render + Supabase
# GPS Caminhoneiro Pro

> ⚠️ Documento antigo (Supabase). O deploy atual usa **Render Postgres + Blueprint**
> (`render.yaml`), sem allowlist de IP e com migração automática do schema.
> Veja [`DEPLOY-RENDER.md`](./DEPLOY-RENDER.md).

Este guia leva você do zero ao backend rodando 24/7 na nuvem (custo zero).
**Não consigo fazer login nestes serviços para você** — você precisa criar as contas e seguir os passos abaixo.

---

## 📋 PRÉ-REQUISITOS

- Conta no [Supabase](https://supabase.com) (gratuita)
- Conta no [Render](https://render.com) (gratuita)
- Código do projeto em `C:\Users\Micro\gps-camioneiro-pro-completo`

---

## PASSO 1: Criar Banco de Dados no Supabase

### 1.1 Criar conta e projeto
1. Acesse [https://supabase.com](https://supabase.com)
2. Clique em "Start your project" ou "Sign in"
3. Crie uma conta com e-mail ou GitHub
4. No dashboard, clique em **"New Project"**
5. Preencha:
   - **Name**: `gps-camioneiro-pro`
   - **Database Password**: crie uma senha forte (anote-a!)
   - **Region**: `South America (São Paulo)`
6. Clique em "Create new project"
7. Aguarde ~2 minutos para o projeto ser provisionado

### 1.2 Obter a DATABASE_URL
1. No painel do Supabase, vá no menu esquerdo: **Settings > Database**
2. Localize a seção **"Connection string"**
3. Selecione **"URI"** (string de conexão completa)
4. Copie algo como:
   ```
   postgresql://postgres:SUA_SENHA_AQUI@db.xxxxxx.supabase.co:5432/postgres
   ```
5. **Guarde este valor** — você vai precisar no Passo 3.

### 1.3 Executar o script SQL no Supabase
1. No menu esquerdo do Supabase, clique em **SQL Editor**
2. Clique em **"New query"**
3. Abra o arquivo: `C:\Users\Micro\gps-camioneiro-pro-completo\database\setup_postgis.sql`
4. Copie TODO o conteúdo do arquivo
5. Cole no editor SQL do Supabase
6. Clique em **"Run"**
7. Verifique se apareceu uma mensagem de sucesso (sem erros em vermelho)

> 💡 Se houver erro relacionado à extensão postgis, execute primeiro:
> `CREATE EXTENSION IF NOT EXISTS postgis;`
> E depois rode o restante do script.

### 1.4 Verificar tabelas criadas
1. No menu esquerdo do Supabase, vá em **Table Editor**
2. Você deve ver estas tabelas:
   - `drivers`
   - `road_alerts`
   - `truck_messages`
   - `travel_history`
   - `driver_contacts`
--- 

## PASSO 2: Criar Serviço no Render

### 2.1 Criar conta no Render
1. Acesse [https://render.com](https://render.com)
2. Clique em "Get Started" ou "Sign in"
3. Crie conta com e-mail ou GitHub

### 2.2 Conectar o repositório
1. No dashboard do Render, clique em "New +" > "Web Service"
2. Escolha uma das opções:
   - **Opção A (GitHub)**: Conecte seu repositório GitHub onde está o código
   - **Opção B (Upload direto)**: Se não tiver GitHub, faça upload dos arquivos

### 2.3 Configurar o Web Service
Preencha os seguintes campos:

| Campo | Valor |
|-------|-------|
| **Name** | `gps-camioneiro-backend` |
| **Runtime** | `Node` |
| **Build Command** | `npm install && npm run build` |
| **Start Command** | `npm start` |
| **Instance Type** | `Free` |

### 2.4 Variáveis de Ambiente (Environment Variables)
Na seção Environment Variables, clique em "Add Environment Variable" e adicione cada uma:

| Chave | Valor | Obrigatório |
|-------|-------|-------------|
| DATABASE_URL | postgresql://postgres:SUA_SENHA@db.xxx.supabase.co:5432/postgres | Sim |
| PORT | 3000 | Sim |
| FRONTEND_URL | * | Sim |
| JWT_SECRET | qualquer-string-aleatória-segura | Sim |

> ⚠️ Substitua SUA_SENHA e db.xxx.supabase.co pelos valores reais do seu Supabase.

### 2.5 Criar o serviço
1. Clique em "Create Web Service"
2. Aguarde o build e deploy (2-5 minutos na primeira vez)
3. Você verá algo como: Live at: https://gps-camioneiro-backend.onrender.com
4. Guarde esta URL — você vai precisar no app Flutter.

### 2.6 Verificar se está online
1. Abra o navegador e acesse: https://SEU-SERVIDOR.onrender.com/status
2. Deve retornar algo como:
   ```json
   {"status":"online","timestamp":"2026-10-17T...","active_trucks":0}
   }

--- 

## PASSO 3: Configurar o App Flutter com a URL do Servidor

### 3.1 Editar app_constants.dart
Abra o arquivo:
C:\Users\Micro\gps-camioneiro-pro-completo\frontend-flutter\lib\core\constants\app_constants.dart

Localize as linhas:
static const String baseUrl = 'https://seu-servidor.onrender.com';
static const String socketUrl = 'https://seu-servidor.onrender.com';

Substitua pela URL real do seu Render:
static const String baseUrl = 'https://gps-camioneiro-backend.onrender.com';
static const String socketUrl = 'https://gps-camioneiro-backend.onrender.com';

> ⚠️ Não esqueça de usar https:// no início.

### 3.2 Gerar a estrutura nativa Android (uma vez)
```powershell
cd C:\Users\Micro\gps-camioneiro-pro-completo\frontend-flutter
flutter create . --platforms=android --org com.gpscamioneiro --project-name gps_camioneiro_pro
flutter pub get
```

### 3.3 Mapa
O mapa usa **MapLibre GL** com tiles gratuitos do OpenStreetMap e Esri (satélite) — não é necessária chave de API para o mapa. A rota com paradas usa a Google Directions API (chave opcional). Consulte `GUIA-MAPA.md`.

--- 

## PASSO 4: Configurar .env no Backend (para deploy local/teste)

Se você vai rodar o backend localmente antes de subir na Render:

1. Na pasta backend-api, copie o arquivo exemplo:
   copy .env.example .env

2. Edite o arquivo .env e preencha:
   PORT=3000
   DATABASE_URL=postgresql://postgres:SUA_SENHA@db.xxx.supabase.co:5432/postgres
   FRONTEND_URL=*
   JWT_SECRET=qualquer-string-segura

--- 

## PASSO 5: Rodar o App no Android

### 5.1 Instalar Flutter SDK (se ainda não tiver)
1. Acesse https://docs.flutter.dev/get-started/install
2. Baixe o Flutter para Windows
3. Extraia em C:\flutter
4. Adicione C:\flutter\bin ao PATH do Windows
5. No terminal, rode: flutter doctor

### 5.2 Conectar celular Android
1. No celular, vá em Configurações > Sobre o telefone
2. Toque 7 vezes em Número da compilação para ativar opções do desenvolvedor
3. Vá em Configurações > Opções do desenvolvedor
4. Ative Depuração USB
5. Conecte o celular ao computador via cabo USB
6. Autorize a depuração quando aparecer no celular

### 5.3 Rodar o app
No terminal, na pasta do Flutter:
cd C:\Users\Micro\gps-camioneiro-pro-completo\frontend-flutter
flutter pub get
flutter run

O app será instalado no celular automaticamente.

### 5.4 Testar a Conexão V2X
1. Abra o app em dois celulares diferentes (ou celular + emulador)
2. Faça login em ambos com contas diferentes
3. No celular 1, use o botão Avisar Via para enviar um alerta
4. No celular 2, o alerta deve aparecer instantaneamente no mapa
5. Toque no ícone do outro caminhoneiro para ver o perfil e enviar emojis

--- 

## 🔧 TROUBLESHOOTING (Problemas Comuns)

| Problema | Solução |
|----------|---------|
| Erro de conexão com banco no Render | Verifique se a DATABASE_URL está correta e se o IP do Render está autorizado no Supabase |
| App não conecta ao servidor | Confirme se a baseUrl e socketUrl no app_constants.dart estão com a URL correta da Render |
| Mapa não carrega | Verifique a conexão de internet e se o `flutter pub get` instalou o `maplibre_gl` |
| WebSocket não conecta | Verifique se a porta 3000 está aberta e se o FRONTEND_URL permite seu domínio |
| Build do Flutter falha | Rode `flutter create . --platforms=android` e depois flutter clean e flutter pub get |

--- 

## 📊 CUSTOS ESTIMADOS

| Serviço | Plano Gratuito | Custo |
|---------|---------------|-------|
| Supabase | 500 MB banco, 2 GB banda | R$ 0 |
| Render | 750 horas/mês, suspende após inatividade | R$ 0 |
| OpenStreetMap/Esri | Tiles gratuitos, sem chave | R$ 0 |
| Google Play Store | Taxa única de desenvolvedor | US$ 25 (uma vez) |

Custo mensal para rodar: R$ 0

--- 

## ✅ CHECKLIST FINAL

- [ ] Conta Supabase criada
- [ ] Projeto Supabase provisionado
- [ ] Script setup_postgis.sql executado no SQL Editor
- [ ] DATABASE_URL copiada do Supabase
- [ ] Conta Render criada
- [ ] Serviço Web criado no Render
- [ ] Variáveis DATABASE_URL, PORT, FRONTEND_URL, JWT_SECRET configuradas na Render
- [ ] URL do servidor obtida (ex: https://xxx.onrender.com)
- [ ] baseUrl/socketUrl atualizadas no app_constants.dart
- [ ] Estrutura nativa gerada (flutter create .)
- [ ] App Flutter rodando no Android
- [ ] Teste V2X realizado com dois celulares

---

## 📞 PRÓXIMO PASSO

Após concluir este deploy, você pode:
1. Gerar o APK final: flutter build apk --release
2. Publicar na Google Play Store
3. Ou continuar desenvolvendo novas funcionalidades

Seu backend está rodando 24/7 na Render e o banco está no Supabase! 🚚💨
