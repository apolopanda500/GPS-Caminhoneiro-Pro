# AGENTS.md — GPS Caminhoneiro Pro

Guia para agentes de IA trabalhando neste repositório. Responder em **português**.

> **Coordenação multiagente**: ler e atualizar `COORDENACAO-AGENTES.md` antes/depois de cada
> tarefa (donos de arquivos, log de atos, status). Um commit por agente.

## Estrutura

- `backend-api/` — Node.js + TypeScript + Socket.io + PostgreSQL/PostGIS.
- `frontend-flutter/` — App Flutter (Android). Mapa nativo com `maplibre_gl` (3D: rotação/inclinação).
- `database/setup_postgis.sql` — Schema espacial (drivers, road_alerts, truck_messages, payments).

## Comandos essenciais

Flutter SDK (fora do PATH): `C:\Users\Micro\flutter\bin\flutter.bat`.

```powershell
# A partir de frontend-flutter
& "C:\Users\Micro\flutter\bin\flutter.bat" analyze   # meta: "No issues found!"
& "C:\Users\Micro\flutter\bin\flutter.bat" test      # 79 testes
& "C:\Users\Micro\flutter\bin\flutter.bat" build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

Backend:

```bash
cd backend-api
npm install
npm run build
npm start        # ou npm run dev
```

## Regras de código

- NÃO adicionar comentários no código, salvo quando solicitado.
- Sempre rodar `flutter analyze` e `flutter test` antes de considerar uma tarefa concluída.
- Ao criar `FloatingActionButton` múltiplos na mesma tela, definir `heroTag` único.
- Evitar `flutter_local_notifications` (removido por incompatibilidade de build e não usado).
- Providers via `provider` + `ChangeNotifier`; registrar em `lib/main.dart`.
- Preferências persistidas com `shared_preferences` (ver `SettingsProvider`).
- Novos arquivos Dart seguem `lib/` (<->) `test/`.

## Ambiente (Windows)

- Shell é PowerShell 5.1: NÃO usa `&&`; usar `;` e `if ($?)`.
- Scripts `.ps1` com emojis precisam ser salvos em UTF-8 com BOM.
- Comandos longos: preferir `Start-Process` em background com log em
  `C:\Users\Micro\AppData\Local\Temp\opencode\*.log`.
- Capturar PNG do adb com `cmd /c "... > arquivo"` (redirecionamento do PowerShell corrompe binário).
- Emulador: AVD `teste_apk` (android-34, x86_64). `adb devices` deve mostrar `emulator-5554`.

## Estado atual / pendências

- Docker parado → teste do backend com PostGIS pendente.
- Sem repositório git/remoto → `git push`/deploy dependem de decisão do usuário.
- Funcionalidades recentes: mapa **MapLibre GL** com câmera 3D (rotação/tilt, botão 3D) e
  troca satélite/ruas por estilos JSON locais; UI limpa com barra inferior (Menu/Buscar/Rota/
  Avisar/Sinal/Rádio/Aqui) e menu inferior; **rota com paradas** (Google Directions + Nominatim),
  painel de rota com distância/ETA; marcadores como símbolos/imagens; FPS overlay; sinalização
  por emoji no mapa (temporária, TTL 12h); busca de rua; balão de caminhões próximos;
  configurações avançadas (FPS/GPS/camada).
- Rota com paradas exige a chave do Google Directions em `AppConstants.googleDirectionsApiKey`
  (`lib/core/constants/app_constants.dart`); sem a chave, o app avisa e não calcula.
- Assinatura de release: keystore em `android/app/upload-keystore.jks` + `android/key.properties`
  (ignorados pelo git). Não commitar esses arquivos.
