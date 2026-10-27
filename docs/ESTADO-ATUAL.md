# 📊 Estado Atual do Projeto (26/10/2026)

## Métricas de Validação

| Verificação | Resultado | Observação |
|-------------|-----------|------------|
| `flutter analyze` | Sem issues | Quando rodado com sucesso |
| `flutter test` | Todos verdes | 233+ testes (versão anterior) |
| Backend `npm test` | 29/29 verdes | Com e sem `.env` |
| Bateria simulação real (10 cenários) | 10/10 — nota 10.0 | Contra produção |
| Bateria ciclo de dias reais (10 cenários) | 10/10 — nota 10.0 | Frota de 5 contas |
| Bateria duas contas (15 cenários) | 15/15 — nota 10.0 | Celular + emulador |
| CI GitHub (4 workflows) | 4/4 verdes | Flutter, Node, Android, CodeQL |

## Recursos Implementados

- ✅ Mapa nativo dentro do app (sem navegador)
- ✅ Camadas Ruas (OpenStreetMap) e Satélite (Esri) alternáveis
- ✅ Rede veicular V2X (outros caminhões ao vivo)
- ✅ Chat Rádio PX Virtual (texto em tempo real)
- ✅ Reações por emoji (👋 👍 ☕ ⚠️)
- ✅ Perfis com foto do motorista e caminhão
- ✅ Câmera livre (pan, pinch, zoom) + 3D (rotação/inclinação)
- ✅ Botão de recentralização GPS
- ✅ Histórico de Viagens com quilometragem
- ✅ Contatos de Estrada com status online
- ✅ Configurações de Hardware (GPS, satélite, bateria)
- ✅ Portal Premium (PIX R$ 4,99/mês)
- ✅ Segurança JWT (tokens criptografados)
- ✅ Gateway PIX (BR Code + CRC16)
- ✅ Login biométrico (digital/facial)
- ✅ Alarmes com vibração (radar, perigo, pedágio)
- ✅ Modo Offline (SQLite cache)
- ✅ GPS 24/7 com tela bloqueada
- ✅ Tema escuro otimizado para direção noturna
- ✅ Medidor de FPS on-screen
- ✅ Configurações avançadas (FPS/GPS/camada)
- ✅ Rota com paradas (Google Directions + Nominatim)
- ✅ Alertas de estrada (radar, policial, ponte baixa, balança, perigo)
- ✅ Botão flutuante para aviso no mapa (2 cliques)
- ✅ Velocímetro flutuante (HUD)
- ✅ Sinais/emoji temporários (TTL 12h)
- ✅ Grupos/comboios com rota compartilhada
- ✅ Clima em tempo real (Open-Meteo)
- ✅ Radar de chuva animado (RainViewer)
- ✅ Rádio online com tocador estilo Muzio
- ✅ Voz com 4 perfis (Padrão, Waze, Uber, 99)
- ✅ Sons personalizados por slot

## Pendências (Ação do Usuário)

1. **envs `PIX_*` no Render** — Premium quebrado em produção (fila #18)
2. **`DATABASE_URL` do Render para pooler Supabase** — expira 18/11/2026 (fila #20)
3. **Perfil no celular → SALVAR** depois da troca do banco (fila #21)
4. **SHA-1 na chave Google Routes** — rota com trânsito ao vivo 403 (fila #17)

## Credenciais Úteis

| Item | Valor |
|------|-------|
| ADMIN_TOKEN local | `8f0bc17df7284e76b77500ec0ff7b17e` |
| PIX_KEY | `rickjax123@gmail.com` |
| PIX_NAME | `HENRIQUE DE CARVALHO` |
| PIX_CITY | `RIO DE JANEIRO` |
| Celular físico | `R9XY1016R6V` |
| Emulador | `emulator-5554` (AVD `teste_apk`) |

## SHA-1 e Certificados

| Keystore | SHA-1 | Uso |
|----------|-------|-----|
| `upload-keystore.jks` (release) | `2F:AE:30:A2:3F:CC:E2:5F:29:08:2A:CE:4B:02:02:07:C9:54:83:34` | APK de release |
| `debug.keystore` (debug) | `C4:EB:B1:5B:BA:7F:D2:7F:79:FA:45:6E:DF:B3:E6:09:57:73:14:DD` | APK de debug |

SHA-256 release: `72EDAACDF3E4E73BC49FAA1D8A2DDD81809C7D6798C0E716E7198BB8E6F34615`

Package name: `com.gpscamioneiro.gps_camioneiro_pro`
