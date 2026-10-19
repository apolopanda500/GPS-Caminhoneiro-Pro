# GPS Caminhoneiro Pro

Aplicativo robusto e nativo para Android, dedicado a caminhoneiros, com mapa renderizado **dentro do app** (sem abrir navegador), rede veicular V2X, chat de estrada, reações por emoji, perfis com fotos, alertas em tempo real via WebSocket, modo offline e cadastro de dimensões do veículo.

## Estrutura do projeto

```
gps-camioneiro-pro-completo/
├── database/
│   └── setup_postgis.sql           # Banco espacial PostGIS (drivers, road_alerts, truck_messages, payments)
├── backend-api/
│   ├── package.json
│   ├── tsconfig.json
│   ├── .env.example
│   └── src/
│       ├── config/
│       │   ├── env.ts
│       │   ├── database.ts
│       │   └── security.ts
│       ├── controllers/
│       │   ├── authController.ts        # Cadastro, login, atualização de perfil
│       │   ├── alertController.ts       # Alertas e mensagens do chat V2X
│       │   └── payment_controller.ts    # Assinatura Premium (PIX)
│       ├── middleware/auth.ts
│       ├── routes/
│       │   ├── auth.ts
│       │   ├── alerts.ts
│       │   └── payment.ts
│       └── server.ts                    # Servidor 24/7: WebSocket V2X + chat + emojis + perfis
├── frontend-flutter/
│   ├── android/
│   │   └── app/src/main/AndroidManifest.xml # GPS 24/7, hardwareAccelerated
│   ├── assets/
│   │   ├── icons/                  # Ícones PNG (colocar aqui)
│   │   └── map_styles/
│   │       └── night_scheme.json   # Tema escuro do mapa
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   │   ├── theme/app_theme.dart
│   │   │   ├── constants/app_constants.dart
│   │   │   ├── network/socket_client.dart     # WebSocket V2X completo
│   │   │   ├── network/geocoding_service.dart # Busca de rua (Nominatim/OSM)
│   │   │   ├── database/local_cache.dart      # SQLite offline
│   │   │   └── utils/location_handler.dart    # GPS nativo Android (intervalo/alta precisão)
│   │   ├── data/
│   │   │   └── models/
│   │   │       ├── driver_model.dart
│   │   │       ├── alert_model.dart
│   │   │       ├── map_marker_model.dart      # Sinal/emoji colocado no mapa
│   │   │       └── truck_config.dart
│   │   ├── providers/
│   │   │   ├── auth_provider.dart
│   │   │   ├── navigation_provider.dart
│   │   │   ├── alert_provider.dart
│   │   │   ├── settings_provider.dart         # FPS, camada padrão, GPS 24/7
│   │   │   ├── marker_provider.dart           # Marcadores personalizados no mapa
│   │   │   └── alert_notifier.dart
│   │   └── views/
│   │       ├── splash/splash_screen.dart
│   │       ├── auth/login_screen.dart
│   │       ├── config/truck_setup_screen.dart
│   │       ├── map/map_screen.dart            # Mapa nativo (OpenStreetMap/Satélite) + HUD + chat
│   │       ├── map/widgets/
│   │       │   ├── report_dialog.dart
│   │       │   ├── speed_hud.dart
│   │       │   ├── fps_overlay.dart           # Medidor de FPS real (Ticker)
│   │       │   ├── marker_dialog.dart         # Colocar sinal/emoji no mapa
│   │       │   ├── street_search_sheet.dart   # Busca de rua/cidade
│   │       │   ├── alert_list.dart
│   │       │   ├── chat_panel.dart
│   │       │   └── peer_profile_panel.dart
│   │       ├── contacts/contacts_screen.dart
│   │       ├── history/travel_history_screen.dart
│   │       ├── settings/hardware_settings_screen.dart
│   │       ├── settings/advanced_settings_screen.dart # FPS/GPS/camada
│   │       └── premium/payment_gate.dart
│   ├── test/                        # 79 testes (models, providers, widgets)
│   └── pubspec.yaml
├── .gitignore
└── README.md
```

## Tecnologias utilizadas

| Camada | Tecnologia | Para que serve |
|--------|-----------|----------------|
| Banco | PostgreSQL + PostGIS | Consultas espaciais de radares, pontes, alertas e chat por proximidade |
| Back-end | Node.js + TypeScript + Socket.io | WebSockets em tempo real: rede V2X, posições de caminhões, chat, emojis |
| Front-end | Flutter (Dart) | App nativo Android com renderização por GPU (60 FPS) |
| Mapas | MapLibre GL + OpenStreetMap / Esri | Mapa nativo 3D (rotação/inclinação), ruas e satélite, sem chave de API |
| Cache local | SQLite | Funcionamento em zonas sem sinal celular |
| Ícones | flutter_launcher_icons | Geração do ícone do app para Android |

## Funcionalidades principais

- ✅ Mapa nativo dentro do app (não abre aba de navegador)
- ✅ Camadas de **Ruas (OpenStreetMap)** e **Satélite (Esri World Imagery)** alternáveis
- ✅ **Busca de rua/cidade** (Nominatim/OpenStreetMap) com atalho para o mapa
- ✅ **Sinalização colaborativa**: toque longo no mapa (ou FAB 😀) para colocar emoji/sinal visível a todos
- ✅ Sinais/emojis **temporários**: expiram em 12h e o mapa é limpo automaticamente (opção "Limpar Sinais do Mapa")
- ✅ Botões de **minimizar** nos dois lados (◀ ▶) para deixar o mapa em tela cheia e limpa
- ✅ Rede veicular V2X: veja outros caminhões se movendo no mapa em tempo real
- ✅ **Balão flutuante** com caminhões próximos e botão de minimizar
- ✅ Chat de estrada (Rádio PX Virtual): conversa de texto entre caminhoneiros próximos
- ✅ Reações por emoji: 👋 👍 ☕ ⚠️ enviadas instantaneamente para caminhões específicos
- ✅ Perfis com fotos: avatar do motorista e foto do caminhão no card de perfil
- ✅ Cadastro de cubagem, peso, eixos e carga perigosa (HAZMAT)
- ✅ Alertas em tempo real: radar, policial, ponte baixa, balança, perigo
- ✅ Botão flutuante para escrever aviso no mapa com 2 cliques
- ✅ Velocímetro flutuante (HUD)
- ✅ **Medidor de FPS on-screen** + configuração de alvo 30/60/120 FPS
- ✅ **Configurações avançadas**: camada padrão, intervalo do GPS e alta precisão 24/7
- ✅ Tema escuro otimizado para direção noturna
- ✅ Preparado para modo offline via cache local SQLite
- ✅ Assinatura Premium (PIX) com endpoint dedicado no backend

## Testes e build

```bash
cd frontend-flutter
flutter analyze          # deve terminar com "No issues found!"
flutter test             # 79 testes (models, providers, widgets)
flutter build apk --debug
flutter build apk --release --target-platform android-arm64
```

Instalar no dispositivo/emulador conectado:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## Como rodar o back-end (Render + Supabase)

1. Crie um banco gratuito no [Supabase](https://supabase.com) com extensão PostGIS.
2. Execute o script `database/setup_postgis.sql` no editor SQL do Supabase.
3. Copie `.env.example` para `.env` na pasta `backend-api` e preencha a `DATABASE_URL`.
4. Instale dependências e inicie:
   ```bash
   cd backend-api
   npm install
   npm run build
   npm start        # ou: npm run dev
   ```
5. Hospede gratuitamente no [Render](https://render.com) conectando o repositório Git.

## Como rodar o app Flutter (Android)

1. Instale o [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Na pasta `frontend-flutter`, gere a estrutura nativa Android (uma vez):
   ```bash
   flutter create . --platforms=android --org com.gpscamioneiro --project-name gps_camioneiro_pro
   ```
   > O script `build-flutter.ps1` faz isso automaticamente preservando o `AndroidManifest.xml`.
3. Instale dependências e rode:
   ```bash
   flutter pub get
   flutter run
   ```
4. No `lib/core/constants/app_constants.dart`, substitua `baseUrl` e `socketUrl` pela URL do seu back-end na Render.
5. Adicione os ícones PNG na pasta `frontend-flutter/assets/icons/`.

## Próximos passos sugeridos

1. Configurar o ambiente Flutter no seu computador.
2. Criar a conta gratuita na Render e subir o `backend-api`.
3. Criar o banco PostGIS no Supabase e rodar o `setup_postgis.sql`.
4. Ajustar `baseUrl`/`socketUrl` em `app_constants.dart` com a URL da Render.
5. Testar o app no celular Android com o mapa renderizado nativamente.

---

Desenvolvido com foco em performance para celulares Android e atualização verdadeira em tempo real entre caminhoneiros.
