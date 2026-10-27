# 🧪 Testes

## Flutter Test (frontend-flutter/test/)

### Baterias de Simulação

| Arquivo | Cenários |
|---------|----------|
| `bateria_simulacao_real_test.dart` | 10 motoristas com rotas próprias, sinais, ocultação, expiração de marcadores, reinício do app, premium, carga de GPS |
| `bateria_ciclo_vida_test.dart` | Voz (4 perfis), sons de parada, rotas compartilhadas, visibilidade, progresso ao vivo, acompanhar/parar de acompanhar |

### Testes de Unidade/Widget

| Arquivo | O que testa |
|---------|-------------|
| `delivery_test.dart` | RouteStopEntry, entregas, raio, dwell, chat panel, peer profile, trânsito |
| `features_test.dart` | MapMarkerModel, MarkerProvider, SettingsProvider, geocoding |
| `simulacao_jornadas_test.dart` | Monitor de paradas: 1000 jornadas aleatórias, GPS ruidoso, teleporte |
| `widget_test.dart` | SpeedHUD, SplashScreen, LoginScreen, TruckSetupScreen |
| `app_constants_test.dart` | Constantes do app |
| `app_theme_test.dart` | Temas claro/escuro |
| `assistant_test.dart` | Assistente de bordo |
| `audio_assets_test.dart` | Áudios |
| `buttons_test.dart` | Botões |
| `chat_test.dart` | Chat |
| `geometria_rota_test.dart` | Geometria de rota |
| `map_panels_test.dart` | Painéis do mapa |
| `models_test.dart` | Modelos de dados |
| `payment_gate_test.dart` | Gateway PIX |
| `premium_test.dart` | Política Premium |
| `providers_test.dart` | Providers |
| `radio_provider_test.dart` | Provedor de rádio |
| `radio_sheet_test.dart` | Sheet de rádio |
| `radio_test.dart` | Rádio |
| `sons_provider_test.dart` | Sons personalizados |
| `weather_layers_test.dart` | Camadas de clima |

## Backend Test (backend-api/src/)

| Arquivo | O que testa |
|---------|-------------|
| `authController.test.ts` | Autenticação |
| `assistant.test.ts` | Assistente de bordo |
| `group_access.test.ts` | Controle de acesso a grupos |
| `pix.test.ts` | Geração PIX + CRC16 |
| `session.test.ts` | Tokens de sessão |

## Comando para rodar todos os testes
```powershell
& "C:\Users\Micro\flutter\bin\flutter.bat" test
```
