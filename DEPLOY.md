# 🚀 GUIA DE DEPLOY - GPS Caminhoneiro Pro

Este guia leva você do zero ao aplicativo rodando no celular Android com backend 24/7 na nuvem (custo zero).

---

## ETAPA 1: Banco de Dados (Supabase + PostGIS)

### 1.1 Criar conta no Supabase
1. Acesse [https://supabase.com](https://supabase.com)
2. Crie uma conta gratuita
3. Crie um novo projeto (escolha a região mais próxima do Brasil: São Paulo)

### 1.2 Ativar extensão PostGIS
1. No painel do Supabase, vá em **SQL Editor**
2. Cole e execute o conteúdo completo do arquivo:
   ```
   C:\Users\Micro\gps-camioneiro-pro-completo\database\setup_postgis.sql
   ```
3. Verifique se não houve erros. As tabelas `drivers`, `road_alerts`, `truck_messages`, `travel_history`, `driver_contacts` devem ser criadas.

### 1.3 Obter a DATABASE_URL
1. No Supabase, vá em **Settings > Database**
2. Copie a string de conexão (URI) - exemplo:
   ```
   postgresql://postgres:SUA_SENHA@db.xxx.supabase.co:5432/postgres
   ```
3. Guarde este valor - você vai precisar no passo 3.

---

## ETAPA 2: Backend na Render (24/7, Gratuito)

### 2.1 Preparar o repositório
1. Certifique-se de que o código está em uma pasta do GitHub (ou faça upload manual)
2. O backend está em: `C:\Users\Micro\gps-camioneiro-pro-completo\backend-api`

### 2.2 Criar serviço na Render
1. Acesse [https://render.com](https://render.com)
2. Crie uma conta gratuita
3. Clique em **New > Web Service**
4. Conecte seu repositório GitHub ou faça upload direto da pasta `backend-api`
5. Configure:
   - **Runtime**: Node
   - **Build Command**: `npm install && npm run build`
   - **Start Command**: `npm start`
   - **Instance Type**: Free

### 2.3 Variáveis de Ambiente na Render
No painel da Render, vá em **Environment Variables** e adicione:

| Chave | Valor |
|-------|-------|
| `DATABASE_URL` | `postgresql://postgres:SUA_SENHA@db.xxx.supabase.co:5432/postgres` (do passo 1.3) |
| `PORT` | `3000` |
| `FRONTEND_URL` | `*` |
| `JWT_SECRET` | `ROBO_DARK_SECRET_2026` (ou qualquer string aleatória segura) |

### 2.4 Obter a URL do servidor
Após o deploy, a Render dará uma URL tipo: `https://gps-truck-backend-xxx.onrender.com`
**Guarde esta URL** - você vai precisar no app Flutter.

---

## ETAPA 3: Configurar o App Flutter

### 3.1 Variável de servidor
Edite o arquivo:
```
C:\Users\Micro\gps-camioneiro-pro-completo\frontend-flutter\lib\core\constants\app_constants.dart
```

Substitua:
```dart
static const String socketUrl = 'https://seu-servidor.onrender.com';
```
Pela URL real da sua Render:
```dart
static const String socketUrl = 'https://gps-truck-backend-xxx.onrender.com';
```

### 3.2 Estrutura nativa Android (uma vez)
Gere as pastas nativas (gradle, MainActivity, res) sem apagar seu código:
```powershell
cd C:\Users\Micro\gps-camioneiro-pro-completo\frontend-flutter
flutter create . --platforms=android --org com.gpscamioneiro --project-name gps_camioneiro_pro
```
> O `AndroidManifest.xml` personalizado (permissões de GPS) já está pronto no projeto. O script `build-flutter.ps1` executa este passo automaticamente preservando-o.

### 3.3 Mapa
O mapa usa **MapLibre GL** com tiles gratuitos do OpenStreetMap e Esri (satélite) — **não é necessário chave de API** para o mapa. A rota com paradas usa a Google Directions API (chave opcional). Veja `GUIA-MAPA.md`.

---

## ETAPA 4: Instalar Flutter e rodar no Android

### 4.1 Instalar Flutter SDK
1. Acesse [https://docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install)
2. Baixe o Flutter para Windows
3. Extraia em `C:\flutter`
4. Adicione `C:\flutter\bin` ao PATH do Windows
5. No terminal, rode:
   ```powershell
   flutter doctor
   ```
   Instale quaisquer dependências faltando (Android Studio, etc.)

### 4.2 Rodar o app
```powershell
cd C:\Users\Micro\gps-camioneiro-pro-completo\frontend-flutter
flutter pub get
flutter run
```

Conecte um celular Android via USB com **Depuração USB** ativada, ou use um emulador.

---

## ETAPA 5: Compilar APK para Produção

```powershell
cd C:\Users\Micro\gps-camioneiro-pro-completo\frontend-flutter
flutter build apk --release --target-platform android-arm64
```

O APK final será gerado em:
```
build/app/outputs/flutter-apk/app-release.apk
```

Instale este APK no celular dos caminhoneiros para testar.

---

## ✅ CHECKLIST DE VERIFICAÇÃO

- [ ] Banco PostGIS criado no Supabase
- [ ] Script `setup_postgis.sql` executado
- [ ] Backend rodando na Render (URL obtida)
- [ ] `DATABASE_URL` configurada na Render
- [ ] `app_constants.dart` com URL do servidor (`baseUrl` e `socketUrl`)
- [ ] Estrutura nativa gerada (`flutter create .`)
- [ ] App Flutter rolando no Android
- [ ] Mapa renderizado nativamente (sem abrir navegador)
- [ ] Chat V2X funcionando entre dois celulares
- [ ] Alarmes de vibração ativos

---

## 🛠️ COMANDOS ÚTEIS

```powershell
# Ver status do backend (substitua pela sua URL)
Invoke-WebRequest -Uri "https://seu-servidor.onrender.com/status"

# Ver logs da Render (via painel web da Render)

# Rebuild do Flutter
flutter clean
flutter pub get
flutter run

# Build release
flutter build apk --release
```

---

## 📞 SUPORTE

Se encontrar erro:
1. Verifique se o banco PostGIS está ativo no Supabase
2. Confirme se a `DATABASE_URL` está correta na Render
3. Teste o endpoint `/status` no navegador
4. Verifique os logs no painel da Render

Desenvolvido com foco em caminhoneiros brasileiros e estradas sem sinal. 🚛🇧🇷