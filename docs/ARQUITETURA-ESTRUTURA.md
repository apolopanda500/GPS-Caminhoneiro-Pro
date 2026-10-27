# 📁 Estrutura de Pastas e Arquivos

```
gps-camioneiro-pro-completo/
├── AGENTS.md                          # Guia para agentes de IA
├── COORDENACAO-AGENTES.md             # Coordenação multiagente
├── DEPLOY.md                          # Guia de deploy
├── GUIA-ANDROID.md                    # Rodar no Android
├── GUIA-MAPA.md                       # Guia do mapa (MapLibre GL)
├── GUIA-PLAY-STORE.md                 # Publicar na Play Store
├── README.md                          # Visão geral
├── RESUMO-FINAL.md                    # Resumo executivo
├── database/
│   └── setup_postgis.sql              # Schema espacial PostGIS
├── backend-api/
│   ├── src/
│   │   ├── config/ (env, database, security)
│   │   ├── controllers/ (auth, alert, assistant, admin, group, payment)
│   │   ├── middleware/ (auth)
│   │   ├── routes/ (auth, alerts, assistant, groups, payment)
│   │   ├── scripts/ (backup, migrate)
│   │   ├── utils/ (assistant, group_access, mailer, pg_url, pix, session)
│   │   └── server.ts
├── frontend-flutter/
│   ├── lib/
│   │   ├── main.dart                  # Entry point + providers
│   │   ├── core/
│   │   │   ├── ai/assistant_engine.dart
│   │   │   ├── audio/ (audio_provider, falas, radio_models, radio_service, som_da_parada, sons_provider, voice_service)
│   │   │   ├── constants/app_constants.dart
│   │   │   ├── database/local_cache.dart
│   │   │   ├── map/traffic_layer.dart
│   │   │   ├── native/servico_rastreio.dart
│   │   │   ├── network/ (cambio, directions, geocoding, network_status, socket_client, weather_layers)
│   │   │   ├── premium/premium_policy.dart
│   │   │   ├── rota/monitor_paradas.dart
│   │   │   ├── theme/app_theme.dart
│   │   │   └── utils/overlay_style.dart
│   │   ├── data/models/ (driver_model, alert_model, map_marker_model, trip_model, truck_config)
│   │   ├── providers/ (auth, alert, group, marker, navigation, route, shared_routes, settings, trip, weather, map_layers)
│   │   └── views/ (splash, auth, config, contacts, history, map, onboarding, premium, profile, settings)
│   └── test/                          # 22+ arquivos de teste Flutter
├── tools/                             # Scripts de bateria e validação
└── docs/                              # Documentação
```
