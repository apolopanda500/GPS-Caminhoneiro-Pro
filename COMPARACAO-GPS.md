# Comparação: GPS Caminhoneiro Pro vs. GPS Globais

Pesquisa realizada em 01/11/2026. Comparação entre o GPS Caminhoneiro Pro (este projeto) e os principais GPS globais/comerciais e open source.

## 1. Estruturas pesquisadas

| GPS | Tipo | Stack / Plataforma | Foco |
|---|---|---|---|
| Google Maps | Comercial | Android/iOS/Web/Car | Navegação geral + trânsito |
| Waze | Comercial (Google) | Android/iOS/Car | Trânsito colaborativo |
| OsmAnd | Open source | Android/iOS | Offline + truck routing |
| Organic Maps | Open source | Android/iOS | Offline, privacidade |
| Sygic Truck | Comercial | Android/iOS/Car | Navegação para caminhão |
| CoPilot (Trimble) | Comercial | Android/iOS/Car | Fleet + truck routing |
| SNGNav | Open source (Flutter) | Android/Linux | Offline-first, inverno |
| TruckTrack | Open source | Spring Boot + RN + Angular | Fleet tracking |

## 2. Tabela comparativa de features

Legenda: sim = tem | parcial | nao = nao tem | EXCLUSIVO = so no Caminhoneiro Pro

| Feature | Caminhoneiro Pro | Google Maps | Waze | OsmAnd | Organic Maps | Sygic Truck | CoPilot |
|---|---|---|---|---|---|---|---|
| Mapa nativo in-app | sim | sim | sim | sim | sim | sim | sim |
| 3D (rotacao/tilt) | sim | sim | sim | sim | parcial | sim | sim |
| Camadas Ruas + Satelite | sim | sim | nao | sim | nao | sim | sim |
| Busca de rua/cidade | sim | sim | sim | sim | sim | sim | sim |
| Turn-by-turn voice (TTS) | nao | sim | sim | sim | sim | sim | sim |
| Lane guidance | nao | sim | sim | sim | parcial | sim | sim |
| Speed limit display | nao | sim | sim | sim | sim | sim | sim |
| Speed camera alerts | nao | parcial | sim | sim | nao | sim | sim |
| Transito em tempo real | nao | sim | sim | parcial | nao | sim | sim |
| Rota com paradas | sim | sim | parcial | sim | sim | sim | sim |
| Roteamento truck-aware (altura/peso/eixos/HAZMAT) | cadastro sim / rota nao | nao | nao | sim | nao | sim | sim |
| Modo offline real | parcial (SQLite) | sim (download) | parcial | sim (vetor+MBTiles) | sim | sim | sim |
| Dead reckoning / Kalman (tuneis) | nao | sim | nao | parcial | nao | sim | sim |
| Alertas colaborativos (radar/policia/ponte/balanca/perigo) | sim | parcial | sim | parcial | nao | sim | parcial |
| Sinalizacao por emoji no mapa (TTL 12h) | EXCLUSIVO | nao | nao | nao | nao | nao | nao |
| Rede V2X (veiculos proximos em tempo real) | EXCLUSIVO | nao | nao | nao | nao | nao | nao |
| Chat de estrada (Radio PX) | EXCLUSIVO | nao | nao | nao | nao | nao | nao |
| Reacoes emoji para motoristas especificos | EXCLUSIVO | nao | nao | nao | nao | nao | nao |
| Perfis com fotos (motorista + caminhao) | EXCLUSIVO | nao | nao | nao | nao | nao | nao |
| Velocimetro HUD flutuante | sim | sim | sim | sim | sim | sim | sim |
| Medidor de FPS on-screen | EXCLUSIVO | nao | nao | nao | nao | nao | nao |
| Tema escuro | sim | sim | sim | sim | sim | sim | sim |
| Android Auto / CarPlay | nao | sim | sim | parcial | nao | sim | sim |
| Assinatura Premium (PIX) | sim (backend) | nao (Google Pay) | nao | parcial (doacao) | nao | sim | sim |
| Historico de viagens | sim | sim | parcial | sim (GPX) | sim | sim | sim |
| Geofencing / zonas de perigo | nao | sim | sim | sim | nao | sim | sim |
| Previsao do tempo na rota | nao | sim | nao | parcial | nao | sim | parcial |
| Precos de combustivel / pedagio | nao | parcial | nao | nao | nao | sim | sim |
| Areas de descanso / estacionamento caminhao | nao | parcial | nao | parcial | nao | sim | sim |
| Hours of Service (HOS) | nao | nao | nao | nao | nao | sim | sim |
| Testes automatizados | 79 | n/a | n/a | sim | sim | n/a | n/a |
## 3. Pontos fortes do Caminhoneiro Pro

1. Comunidade V2X exclusiva: unico da lista com rede veicular colaborativa (veiculos proximos, chat, reacoes emoji, perfis com fotos).
2. Sinalizacao por emoji com TTL 12h: inovacao nao presente nos concorrentes.
3. Medidor de FPS on-screen + config 30/60/120: foco em performance.
4. Stack moderna: Flutter + MapLibre GL + Node.js/Socket.io + PostGIS.
5. Backend proprio com WebSocket V2X 24/7 e assinatura PIX.
6. Tema escuro otimizado para direcao noturna.
7. 79 testes automatizados.

## 4. Gaps (o que os GPS globais tem e o Caminhoneiro Pro nao tem)

### Criticos para um GPS completo:
- Turn-by-turn voice (TTS) com instrucoes de voz.
- Lane guidance (faixas corretas).
- Speed limit display + alertas de excesso.
- Transito em tempo real (traffic layer).
- Roteamento especifico para caminhao (altura, peso, largura, comprimento, eixos, HAZMAT aplicado na rota, nao so cadastro).
- Modo offline real (download de tiles MBTiles/vetor, nao so cache SQLite).
- Dead reckoning / Kalman para tuneis e perda de GPS.
- Android Auto / CarPlay.

### Importantes:
- Geofencing (zonas de perigo, alertas de entrada/saida).
- Previsao do tempo na rota.
- Precos de combustivel e pedagio.
- Areas de descanso/estacionamento para caminhao.
- Hours of Service (HOS) para conformidade legal.
- Speed camera alerts (radares fixos).

### Nice-to-have:
- Multi-modal (transit, walk, bike).
- GPX import/export.
- Contour lines / hillshade.
- Plugin system (OsmAnd).
- Conversational reporting (Waze/Gemini).

## 5. Recomendacoes de roadmap (prioridade)

1. Alta: TTS turn-by-turn + lane guidance + speed limit display.
2. Alta: Roteamento truck-aware (integrar OSRM/Valhalla com restricoes de caminhao).
3. Media: Modo offline real com MBTiles (inspiracao SNGNav).
4. Media: Transito em tempo real (layer de trafego).
5. Media: Dead reckoning/Kalman para tuneis.
6. Baixa: Android Auto / CarPlay.
7. Baixa: Geofencing, weather, fuel prices, HOS.

## 6. Conclusao

O GPS Caminhoneiro Pro se destaca fortemente na dimensao social/comunitaria (V2X, chat, reacoes, sinais colaborativos, perfis), algo que nenhum dos GPS globais oferece de forma integrada. Porem, na dimensao de navegacao pura, ainda falta o core de um GPS completo: voz turn-by-turn, lane guidance, speed limits, roteamento truck-aware e modo offline real. A combinacao das duas dimensoes (social + navegacao completa) seria o diferencial competitivo definitivo.

## 7. Apps adicionais pesquisados (2026)

| GPS / App | Tipo | Foco principal | Preço (USD) | Destaques |
|---|---|---|---|---|
| Argus Nav | Comercial (IA) | Crash detection AI + truck routing | ~$50/ano | Alertas de acidente em <10s via 45k+ câmeras DOT; peso dinâmico por carga; low bridge; HazMat; IFTA; strategic pump pricing |
| Trucker Path | Comercial (comunidade) | POIs + parking + fuel | Grátis / $99.99/ano Pro / $14.99-$29.99/mês | 1M+ usuários; 500k+ truck stops; parking predictions 7 dias; HOS; fuel prices; live traffic cameras; DOT 511 |
| Trucker Guide | Comercial | Live cameras + weigh stations | ~$14.99-$25/mês (trial 7d) | 80k+ câmeras de estrada (EUA+Canadá); 2000+ weigh stations status; parking; fuel; Walmart overnight; CAT Scale; offline nav |
| Hammer | Comercial (ex-grátis) | Offline truck routing | $4.99/mês ou $49.99/ano | Offline maps + routing; weigh station alerts; multi-stop; (virou pago em 2026) |
| TruckMap | Comercial | Free truck routing + cargas | Grátis | Truck routing básico; cargas; sem assinatura |
| Highway Miles | Comercial | Free truck nav + multi-stop | Grátis (ads) / $5.99/mês ad-free | Perfil comercial; stops ilimitados; reordenação/otimização; "Route Through Here/Avoid"; maps baixados (offline parcial) |
| Garmin dezl | Dispositivo dedicado | Hardware truck GPS | ver site | Tela grande; sem dreno de bateria; community data limitado |
| Rand McNally | Dispositivo + app | Hardware + app | ver site | Similar ao Garmin |
| SmartTruckRoute | Comercial (frota) | Fleet-friendly routing | ver site | Roteamento para frotas |
| PC*Miler (Trimble) | Dataset profissional | Roteamento base | licença | Base de dados usada pelo CoPilot |
| Sygic Truck | Comercial | Offline navigation | $74.99-$124.99/ano ou $112.49 lifetime | Offline maps USA 5.16GB; 3D; voz multi-idioma; speed limit warnings |
| CoPilot (Trimble) | Comercial | Offline routing profissional | $9.99/mês ou $119.99/ano | PC*MILER; low-clearance; stop sequencing; rerouting live |

## 8. Features adicionais identificadas (ausentes no Caminhoneiro Pro)

### Navegação / segurança de rota
- Live traffic cameras (DOT 511) com 80k+ câmeras.
- Status de weigh stations (aberto/fechado) em tempo real.
- Alertas de low clearance em tempo real (já tem cadastro de altura, falta alerta na rota).
- Crash detection por IA (Argus) — detecta incidentes em <10s analisando câmeras DOT.
- Trânsito em tempo real (traffic layer) + rerouting automático.
- Turn-by-turn voice (TTS) + lane guidance + speed limit display + alerta de excesso.
- Dead reckoning / Kalman para túneis e perda de GPS.
- Offline real: download de tiles MBTiles/vetor + cálculo de rota + rerouting offline.

### POIs / comunidade / economia
- Banco de truck stops (500k+) com previsão de vagas de estacionamento (7 dias).
- Preços de combustível em tempo real + strategic pump pricing + tank level timing.
- HOS (Hours of Service) integration/planejamento.
- IFTA route optimization + relatórios de milhagem.
- Áreas de descanso / estacionamento para caminhão.
- Walmart overnight parking / CAT Scale locations.

### Integração / plataforma
- Android Auto / CarPlay.
- GPX import/export.
- Weather on route.
- Geofencing (zonas de perigo) com alertas de entrada/saída.
- Speed camera alerts (radares fixos).
- Contour lines / hillshade.
- Plugin system.

## 9. Roadmap expandido (prioridade)

### Alta (core GPS completo)
1. TTS turn-by-turn + lane guidance + speed limit display + alerta de excesso.
2. Roteamento truck-aware real (integrar OSRM/Valhalla com restrições de altura/peso/largura/comprimento/eixos/HAZMAT) aplicado no cálculo da rota.
3. Modo offline real com MBTiles/vetor + cálculo offline + rerouting.
4. Trânsito em tempo real (traffic layer) + alertas de acidente rápidos (inspiração Argus via 511/DOT cameras).
5. Dead reckoning / Kalman para túneis.

### Média (POIs e economia)
6. Status de weigh stations + banco de truck stops + previsão de vagas.
7. Comparação de preços de combustível + strategic pump pricing + tank level timing.
8. Câmeras de estrada ao vivo (DOT 511 feeds).
9. Geofencing (zonas de perigo).
10. Weather on route.
11. HOS integration/planejamento.
12. IFTA mileage reports.
13. Speed camera alerts (radares fixos).
14. Low clearance alerts em tempo real.

### Baixa (plataforma/avançado)
15. Android Auto / CarPlay.
16. GPX import/export.
17. Contour lines / hillshade.
18. Plugin system.
19. Conversational reporting (Waze/Gemini style).
20. Crash detection por IA (Argus) — diferencial competitivo.

## 10. Diferencial competitivo proposto

Combinar as três dimensões que hoje estão separadas no mercado:
1. Social/comunitária (já exclusiva): V2X, chat PX, reações emoji, sinalização emoji TTL 12h, perfis com fotos.
2. Navegação completa (gaps a fechar): TTS, lane guidance, speed limits, roteamento truck-aware, offline real, trânsito.
3. Inteligência de economia (inspiração Trucker Path/Argus): fuel prices, parking predictions, weigh stations, HOS, IFTA, crash detection AI.

Resultado: único app que une comunidade V2X + navegação completa + economia operacional — posicionamento "GPS social para caminhoneiro com navegação profissional".

## 11. Motores de IA para complementar o GPS

### 11.1 Detecção de acidentes/tráfego em tempo real (Argus)
- **O que faz:** AI sobre 45k+ câmeras DOT, detecta crash/debris/stopped vehicle/weather/construction; alertas em <10s (vs 10-15min crowdsourced).
- **API:** REST `GET /v1/alerts?bbox=...` + iOS/Android SDK; webhook push ou polling; confidence score + source attribution.
- **Uso no app:** alertas in-cab, recalcular ETA, gatilho de rerouting, dashboard de segurança.
- **Custo:** sandbox 1.000 req grátis; per-call volume tiers.

### 11.2 Roteamento truck-aware com IA (Argus Routing)
- **O que faz:** routing class 3-8, bridge clearance, weight limit, hazmat, practical miles, tolls por eixo/peso/hora, state-by-state mileage, geocoding.
- **Substitui:** PC*Miler ($995/seat) com ~98% overlap prático; endpoints compatíveis com Mapbox/HERE consumers.
- **Uso no app:** roteamento real aplicado na rota (hoje só cadastro de veículo).

### 11.3 Assistente de voz conversacional (Cerence)
- **O que faz:** hybrid edge+cloud, STT/NLU/TTS, offline navigation, rerouting por voz, personalização, multi-idioma, integração com sensores/ELD.
- **Latência:** 1.2-1.5s em chamadas ao vivo; processamento on-device em áreas sem sinal.
- **Uso no app:** TTS turn-by-turn com comandos de voz ("evitar pedágio", "próximo posto", "quantos km até o descanso").

### 11.4 Edge AI para low bridges (Samsara)
- **O que faz:** detecção on-device (firmware da câmera) + contexto multimodal de mapa; map tile framework offline com cache de tiles relevantes; buffer de altura do caminhão calculado (não estimado).
- **Vantagem:** sem lag cloud-to-cab; funciona em túneis/zonas rurais.
- **Uso no app:** alerta de low clearance em tempo real na rota, mesmo offline.

### 11.5 Previsão de tráfego/ETA com ML (TomTom/HERE/Google Traffic)
- **O que faz:** modelos de ML sobre histórico + tempo real para ETA e congestionamento.
- **Uso no app:** traffic layer + ETA dinâmico + rerouting automático.

### 11.6 Computer vision on-device (TensorFlow Lite / ONNX Runtime Mobile)
- **Modelos:** YOLO/MobileNet para detecção de sinais de trânsito, radares, obstáculos, placas de low clearance.
- **Uso no app:** speed camera alerts, leitura de placas de altura/peso, alertas visuais.

### 11.7 NLP/LLM para chat de estrada e relatórios conversacionais
- **Modelos:** OpenAI/Claude/Llama via API + RAG sobre POIs/tráfego/clima.
- **Uso no app:** chat PX inteligente, resumo de viagem, "pergunte ao GPS" (Waze/Gemini style), geração de relatórios de combustível/HOS.

### 11.8 Detecção de sonolência/fadiga (MediaPipe Face Mesh)
- **O que faz:** eye aspect ratio + head pose on-device, alerta de fadiga.
- **Uso no app:** segurança do motorista, alerta de parada para descanso.

### 11.9 Previsão de consumo de combustível / eco-routing
- **O que faz:** ML sobre telemetria (velocidade, carga, terreno, clima) para estimar consumo e sugerir rota econômica.
- **Uso no app:** strategic pump pricing + tank level timing + eco-route.

### 11.10 Recomendação de vagas de estacionamento (ML)
- **O que faz:** modelo sobre histórico de ocupação de truck stops + hora/dia/semana.
- **Uso no app:** parking predictions (7 dias), alerta de vagas próximas.

### 11.11 Arquitetura sugerida (híbrida)
- **Edge (on-device):** TTS (flutter_tts), detecção de low bridge (map tiles + altura), sonolência (MediaPipe), STT (speech_to_text), cache de mapas.
- **Cloud (APIs):** Argus alerts/routing, traffic (TomTom/HERE), LLM (OpenAI/Claude), fuel prices, parking predictions, weather.
- **Fallback:** quando offline, usar tiles MBTiles + roteamento OSRM local + TTS local.

## 12. Plano de início dos trabalhos

### Sprint 0 — Fundação (já concluída)
- Mapa MapLibre 3D, rota com paradas, V2X, chat PX, perfis, FPS, tema escuro, 79 testes.

### Sprint 1 — Core GPS ✅ CONCLUÍDA
1. ✅ TTS turn-by-turn com flutter_tts (instruções de voz + lane guidance básica) — `voice_service.dart` já existente, `navegador_tbt.dart` integrado.
2. ✅ Speed limit display + alerta de excesso — `SpeedLimitService` (Overpass API) integrado no HUD.
3. ✅ Roteamento truck-aware real: `directions_service.dart` com `extrairManobrasGoogle/Osrm/ORS` + `Manobra` com `faixas` (lane guidance) + `navegador_tbt.dart` aplicando manobras.
4. ✅ Validação: `flutter analyze` → "No issues found!"; `flutter test` → 244/244 passando; APK instalado no celular R9XY1016R6V (Success).

### Melhorias adicionais entregues nesta sessão
- ✅ Botão "Configurações" no mapa → abre `SettingsScreen` existente (perfil, plano, GPS/rota, mapa/gráficos, sons/voz, aparência, permissões, histórico, limpar cache, sair).
- ✅ Clima: valida posição GPS antes de abrir `WeatherPanel`; snackbar "Aguardando posição GPS..." se não houver localização.
- ✅ `_limparSinaisDoMapa()` e `_sairDaConta()` (logout → SplashScreen).
- ✅ Correção encoding mojibake ("TrÃ¢nsito" → "Trânsito").
- ✅ APK buildado (debug) e instalado no dispositivo R9XY1016R6V.

## 13. Status atual (01/11/2026)

| Item | Status |
|---|---|
| Analyze | ✅ No issues found |
| Testes Flutter | ✅ 244/244 passando |
| APK debug | ✅ Buildado e instalado no celular |
| Commit + push | ✅ `27e7c3c` em `origin/main` |
| Clima | ✅ Radar + Open-Meteo funcionando (validado no celular) |
| Botão Configurações | ✅ Adicionado no mapa |
| Próxima sprint | Sprint 2 — Offline MBTiles + Traffic layer + Dead reckoning |

### Decisões técnicas adotadas (Sprint 1)
- **TTS:** `flutter_tts` (offline, grátis) ✅ já integrado
- **Roteamento:** OSRM/ORS/Google Directions via `directions_service.dart` ✅ já integrado
- **Speed limit:** Overpass API (sem chave) ✅ já integrado
- **Offline maps:** pendente (Sprint 2)


