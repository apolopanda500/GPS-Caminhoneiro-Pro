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

Desenvolvido com foco em performance para celulares Android e atualização verdadeira em tempo real entre caminhoneiros.
