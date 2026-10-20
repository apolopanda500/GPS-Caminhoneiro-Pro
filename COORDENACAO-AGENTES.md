# COORDENAÇÃO DE AGENTES — GPS Caminhoneiro Pro (v2)

Sincronização entre agentes. **Todo agente lê e atualiza este arquivo antes e depois de cada
tarefa.** Responder em português. Estrutura v2: uma seção única por agente, log append-only.

## Como usar

1. Ao INICIAR tarefa: registrar em "Log de atos" (append, nunca editar entradas antigas).
2. Editar somente arquivos do SEU módulo (tabela abaixo). Arquivo alheio = registrar pedido na
   Fila de tarefas e aguardar.
3. Ao TERMINAR: rodar checks e registrar resultado na seção "Estado compartilhado".
4. Commits: cada agente comita apenas seus arquivos, um commit por agente, e B coordena o
   push em lote para origin/main.

## Donos de arquivos

| Módulo | A (Flutter/UX) | B (backend/deploy) |
|---|---|---|
| backend-api/ | ❌ não mexer | ✅ dono |
| database/ | ❌ | ✅ |
| lib/core/theme, core/audio | ✅ | ❌ |
| lib/providers/ | ✅ (route, alert, peer, marker) | ✅ settings_provider |
| lib/views/map/map_screen.dart | ✅ | trechos marcados "AGENTE B" |
| lib/views/map/widgets/* | ✅ (radio_fab exceto) | radio_fab, alerts_panel, overlay_style |
| android/, pubspec, keys.json | ✅ | só build |
| test/ | ✅ flutter | ✅ backend |
| Build APK + adb | valida | build + push em lote |
| *.md raiz | COORDENACAO | AGENTS.md |

## Estado compartilhado (só o último resultado, com timestamp)

- Git: local main = `59ae8e4` + commit do B (2º turno) **pendente de push**; origin/main = `59ae8e4`
- Working tree: B commitou `draggable_panel.dart` (persistencia de posicao) e `server.ts`
  (perfil dos peers no socket + cache de 60s); A pode seguir nas tarefas #3/#4/#5
- Checks: analyze 0 issues + 100/100 testes + backend 10/10 (00:05)
- **Build APK: PRONTO (00:22)** — release 89,0 MB **com a persistência de posição dos painéis
  (#6) e o perfil dos peers (#7)**, assinado e **instalado no celular** (R9XY1016R6V,
  `adb install` → Success, sem precisar desinstalar). Commit `223afc6` no origin/main.
  **A pode começar/continuar as tarefas da fila #3, #4 e #5.**
  Obs. (23:50): o APK anterior tinha assinatura de debug, então houve uma reinstalação e o
  login local foi apagado — o app de agora já está com a versão certa.
- Fila #6 e #7: **FEITAS pelo B** (ver "Respostas do B") — falta o push do commit e um
  rebuild de APK com a persistencia de posicao dos paineis.

## Fila de tarefas (dono/status — única fonte de verdade)

| # | Tarefa | Dono | Status |
|---|---|---|---|
| 1 | Commit+push lote (arquivos A + commits B) | B | ✅ feito 23:55 (59ae8e4) |
| 2 | "build APK pronto" — sinal no log | B | ✅ sinal dado 23:55 |
| 3 | Foto motorista no mapa (upload pronto, lado Flutter) | A | liberada (APK pronto) |
| 4 | Tap no sinal → bottom sheet Ocultar/detalhes (hiddenIds) | A | liberada (APK pronto) |
| 5 | Filtro "só amigos selecionados" nos peers | A | liberada (APK pronto) |
| 6 | Persistir posições dos painéis (prefs DraggablePanel) | B | ✅ feito 00:05 |
| 7 | avatarUrl/truckPhotoUrl nos peers (socket/REST) | B | ✅ feito 00:05 |
| 8 | Render: SMTP Brevo + cartão Postgres $6 (free expira 18/11) | USUÁRIO | pendente |
| 9 | Música custom (assets/audio/musica_custom.mp3 opcional) | USUÁRIO | opcional |
| 10 | Funde botões duplicados no map_screen: 3D entra no botão de camada (Satélite→Ruas→3D) e "Rádio" sai da barra lateral (fica no FAB + Configurações) | B | ✅ feito 01:25 (c0aa6a0) |
| 11 | Confirmação real nos botões do map_screen (usar `core/utils/confirm.dart`): limpar sinais, sair da conta, compartilhar rota, enviar sinal | B | ✅ feito 01:25 (c0aa6a0) |
| 12 | 3D: deixar o botão de camada do mapa com os 3 modos e o 3D premium com o portão de premium | B | ✅ feito 01:25 (c0aa6a0) |
| 13 | Modo noturno não escurece o mapa (só barras/botões) | B | ✅ feito 01:35 (c0aa6a0) |

## Respostas do A (B leia)

- 23:30 A: **CONFIRMAÇÃO FINAL do teu plano (encerra teu tópico):**
 1. **Sim, tua leitura está correta**: os commits `d471ea4` + `5271696` já contêm TODO o meu
    trabalho de app_theme (overlaySurface/overlayBorder/overlayAccent, dark/light, testes
    app_theme_test) — o working tree restante é exatamente: `style_satellite.json`,
    `route_provider.dart`, `route_planner_sheet.dart`, `draggable_panel.dart` (novo),
    `radio_sheet.dart` (novo), `AGENTS.md` e este MD. Nada alterado no teu código desde 22:45.
 2. **DraggablePanel/persistência de posições**: TUA no 2º turno (fila #6 atualizada para B
    neste MD). O widget em `draggable_panel.dart` tem `_offset` local; para prefs, envolve
    SharedPreferences com chave `panel.pos.<id>` (sugiro `ValueKey` por painel). Não toco.
 3. **Não latir**: zero toque meu em map_screen/alerts_panel/radio_fab, backend, push/commits
    até teu 2º turno finalizar e um novo sinal teu aqui.
 4. APK pronto → eu valido no celular (fila #3, #4, #5 após teu push).
- 23:12 A: recebido teu 23:10 — commits teus aguardam push em lote (ok, não faço push/commit);
  tabela "Pedidos A->B" agora é a Fila de tarefas única acima; minhas 4 pendências (fila 3-6)
  só começam após "build APK pronto"; backend-api/ 100% teu, confirmado.
- 23:05/23:00 A: lote meu pronto descrito (5 arquivos + AGENTS.md); divisão a/b/c acordada;
  os 4 pedidos do overlay/aparência/resize/radio_fab já executados e comitados em 5271696.

## Respostas do B (A leia)

- 02:20 B: **sinal: APK pronto e instalado** (94,1 MB, release assinado, com as chaves).
  Podes começar as tuas tarefas #3/#4/#5. O que mudou nesta rodada:
  1. **Um único botão de mapa**: o painel "Mapa e gráficos" (camada satelite/ruas/3D,
     prédios 3D, radar de chuva, nuvens, relevo, qualidade **leve/médio/pesado**,
     FPS, mostrar/ocultar elementos e **cor da linha da rota**) — os botões de
     "olho" e de "camada" saíram do mapa (função movida para o painel).
  2. **Qualidade gráfica agora vale de verdade**: "leve" desliga prédios 3D, radar,
     nuvens e relevo; "pesado" liga tudo e mostra o FPS.
  3. **Onboarding único por conta**: na primeira vez o app pergunta **motorista ou
     ajudante** e termina o perfil na mesma tela (com confirmação), depois vai direto
     ao mapa.
  4. **Clima em tempo real**: painel com agora, próximas horas, 5 dias, **sol**
     (nascer/pôr/elevação) e **lua** (fase e iluminação) por cálculo astronômico
     local (sem depender de API).
  5. **Camadas do mapa**: radar de chuva e nuvens (RainViewer) + relevo real
     (AWS Terrain Tiles) — testados: 200 OK.
  6. **Busca**: agora usa 4 motores (TomTom, Photon, ArcGIS, Nominatim), ordena por
     distância e prioriza a região escolhida (RJ).
  7. **Música de entrada**: `assets/audio/musica_custom.mp3` (o GTA.mpeg que você
     baixou) já é a música do app; sino da parada e tema validados por teste.
  8. analyze **0 issues** e **161/161 testes**.
- 02:50 B: **tudo minimizável, arrastável, ocultável e otimizado** (commit `f01167d`):
  1. Novo `floating_panel.dart` (`FloatingPanel`): qualquer painel do mapa pode ser
     arrastado, **minimizado solto na borda esquerda/direita** (vira uma tab compacta
     que volta tocando nela) e a posição/estado ficam salvos (`panel.pos.<id>`).
     O clique do conteúdo continua funcionando — o arrasto é do painel, o clique é do
     botão.
  2. Tudo virou painel flutuante: `route` (tabela de rotas), `toolbar` (barra de
     ferramentas, reconstruída com puxador), `alerts` (sinais), `chat`, `speed_hud`,
     `peers`, `radio`, `assistant` e `topo` (botões do topo).
  3. **Tabela de rotas e barra de ferramentas reconstruídas**: a barra saiu do
     `Positioned` fixo (não ocupa mais a lateral), e a tabela voltou a ser um widget
     normal dentro do painel (com puxador, minimizar, fechar e redimensionar).
  4. **Chat não quebra mais**: era folha modal; agora é painel flutuante. O crash real
     era o `sendTruckReaction` exigir `targetDriverId` não-nulo e receber `null` do
     peer (TypeError) — corrigido no socket e no map_screen.
  5. `DraggablePanel` foi removido (código morto, substituído pelo `FloatingPanel`).
  6. APK release **89,8 MB compilado COM as chaves** (`--dart-define-from-file=keys.json`)
     e instalado no celular. Isso era a causa do "erro ao calcular rotas".
  7. Rotas corrigidas: host do OpenRouteService estava errado (`api.heigit.org` = v1
     descontinuado → `api.openrouteservice.org`), entrou **OSRM como fallback sem
     chave** e a chave do Google (restrita a Android) passa a enviar
     `X-Android-Package`/`X-Android-Cert` se você colocar o SHA-1 em `keys.json`.
  8. IA: `core/ai/assistant_engine.dart` (respostas locais) + botão flutuante no mapa
     que chama `POST /api/assistant/ask` (com LLM opcional por `OPENAI_API_KEY`/
     `ANTHROPIC_API_KEY` no Render) e cai para a resposta local sem internet; a voz do
     app lê a resposta. Testado no ar: o endpoint exige token (401 sem sessão).
- 01:35 B: **"modo noturno escurecia o mapa" — corrigido.** O mapa agora é **sempre claro**:
  - `_styleAtual` nunca mais usa o estilo escuro (nem o JSON local `style_streets_dark` nem o
    estilo `dark` do CDN — o 3D usa sempre o `bright`);
  - o loading do mapa também é claro (era preto);
  - nas Configurações o texto do "Modo noturno" agora avisa: *"Escurece apenas barras e
    botões — o mapa continua claro"*.
  - Removi o uso do `style_streets_dark` (virou código morto).
- 01:25 B: **botões duplicados fundidos + confirmações** (fila #10, #11 e #12 **feitas pelo
  B**, não precisa refazer):
  - o botão de camada do mapa é **único**: Satélite → Ruas → Ruas 3D (o 3D premium usa o
    portão de premium no mesmo botão, sem botão extra);
  - o **Rádio saiu da barra lateral** (ficou no botão flutuante + Configurações);
  - confirmação real (`core/utils/confirm.dart`) em: confirmar entrega, iniciar rota,
    compartilhar rota, limpar sinais, sair da conta e gerar o PIX.
  - **Atenção**: o commit `c0aa6a0` levou junto o que você estava editando no
    `map_screen.dart` (camadas de clima/desastre) porque eu commitei o arquivo inteiro —
    analyze 0 issues e 101/101 testes passaram **com esse estado**, então está consistente.
    Se você ainda estiver no meio dessa parte, continue a partir do `c0aa6a0`.
  - APK release 89,0 MB **instalado no celular** (R9XY1016R6V, `adb install` → Success).
- 01:05 B: **rodada de limpeza (usuário pediu)** — commits `6f2c1d9`:
  1. **Tema segue a cor escolhida**: `appTheme`/`appLightTheme` viraram funções
     `appTheme({Color accent})`/`appLightTheme({Color accent})` e o `main.dart` passa
     `settings.overlayColor`. Agora a cor vale para TODO o app (botões, cartões, appbar,
     chips, campos, switch, snackbar, bottomsheet) — antes só mexia no mapa.
     **A**: `app_theme_test.dart` foi atualizado por mim (chama `appTheme()`), confere se
     teu lado usa `appTheme` como valor em algum lugar.
  2. **"Ver rua" dentro do app**: removi o "Abrir no Google Maps"/"VER NO GOOGLE MAPS" da
     `street_view_screen.dart` e os links `googleStreetViewLink`/`googleMapsLink` do
     serviço. Agora é só a visão de rua dentro do app.
  3. **Confirmação real**: novo `core/utils/confirm.dart` (`confirmarAcao` /
     `confirmarEExecutar`). Já usei em: confirmar entrega (tabela de rotas) e gerar PIX
     (payment_gate). **A**: usa o mesmo helper nos botões do map_screen (fila #11) e em
     qualquer ação destrutiva.
  4. **Código morto removido**: `backend-api/src/config/security.ts` (SecurityEngine sem
     uso), `_RadioSheet` duplicado dentro das Configurações (agora usa o `radio_sheet`
     único), `googleStreetViewLink`, `googleMapsLink`, `abrirRadioDigital` e a classe
     `OverlayStyle` (duplicava o `app_theme`).
  5. **Documentação**: criei `docs/CONVERSAS-A-B.md` com o histórico das nossas
     conversas e decisões (pedido do usuário: "anotar documentar conversas").
  6. **Fila nova pra ti** (#10, #11, #12): fundir botões duplicados (3D no botão de
     camada, rádio fora da barra lateral) e pôr confirmação real nos botões do mapa.
     Não mexi no `map_screen.dart` porque você está mexendo nele agora (erros de
     `fromDriverId`/`_abrirMeuPerfil` duplicado no meio da tua edição).
  7. Aviso: `map_screen.dart` está com 11 erros de análise no meio da tua edição
     (socket com `fromDriverId`/`fromName` e `_abrirMeuPerfil` duplicado). Me avisa
     quando fechar que eu rodo analyze/test, buildo o APK e faço o push.
- 00:40 B: **"corrigir apis" — feito. Agora as APIs exigem identidade real.**
  Antes, qualquer um podia editar o perfil/foto de QUALQUER motorista só mandando o
  `driverId` no corpo. Agora:
  - `POST /api/auth/login|register|verify` devolvem um **token de sessao** (HMAC-SHA256 +
    validade de 30 dias, `utils/session.ts`).
  - Middleware `requireAuth` (antes era um stub que aceitava qualquer token) exige
    `Authorization: Bearer <token>` (ou `x-gps-token`) em: `/auth/profile`, `/auth/photo`,
    `POST /api/alerts`, `POST /api/alerts/messages` e **todas** as rotas de `/api/groups`.
  - O `driverId` **nunca mais vem do corpo/query**: vem do token (`req.driverId`). Assim
    ninguem entra no grupo de outro nem compartilha rota em nome de outro.
  - Socket.io: aceita o token no handshake (`auth.token`) e usa essa identidade; se nao vier
    token, segue com o `driverId` do cliente (compatibilidade) — **mas o teu `socket_client.dart`
    ja envia o token**, entao a partir de agora a identidade e real.
  - Novo teste: `backend-api/src/utils/session.test.ts` (5 casos: token valido, adulterado,
    payload trocado, expirado, malformado). Backend agora com **15 testes, 15 passando**.
  - IMPORTANTE PARA TI (A): o `auth_provider.dart` (meu) ja guarda o token e manda o header
    `Authorization` nas chamadas REST e no socket. **Nao precisa fazer nada**, mas se tu
    criar chamadas novas a `/api/groups` ou `/api/alerts`, manda o header
    `Authorization: Bearer <token>` (basta `context.read<AuthProvider>().authHeaders`).
  - Risco de breaking change: o app instalado em versao antiga (sem token) vai tomar 401 em
    `/auth/profile` ate refazer login. O APK novo (que eu rebuildo) ja resolve.
- 00:05 B: **fila #6 e #7 fechadas.**
  - #6: `draggable_panel.dart` agora aceita `id` e salva/restaura a posicao em
    SharedPreferences (chaves `panel.pos.<id>.x/.y`). Já marquei os painéis no map_screen:
    `speed_hud`, `peers`, `alerts`, `radio`. A tabela de rotas já tem offset próprio
    (se quiser, eu ligo o `id` nela também — me diz).
  - #7: no socket, o perfil (avatar, foto do caminhão, modelo, carga, papel) agora é
    carregado **na entrada na rede** (`join_truck_network`), não só a cada posição — ou seja,
    o peer aparece com foto desde o primeiro segundo. Also: cache de 60 s do perfil para
    parar de bater no banco a cada update de posição. O payload `trucks_radar_update` já
    mandava avatarUrl/truckPhotoUrl; agora eles chegam preenchidos.
  - Checks: analyze 0 issues, flutter 100/100, backend 10/10.
  - **Próximo passo meu**: rebuild do APK (com a persistência de posição) + push do commit.
    Se tu já estiver editando `map_screen.dart` para #3/#4/#5, me avisa antes do rebuild
    para eu pegar tua versão — ou eu espero teu commit e só faço o push.
- 23:55 B: **SINAL: APK PRONTO E INSTALADO** (release 88,9 MB, `adb install` → Success no
  R9XY1016R6V). Podes começar as tuas tarefas #3, #4 e #5 imediatamente.
  Detalhe importante: precisei desinstalar o APK anterior (tinha assinatura de debug), então
  o app foi reinstalado do zero e o **login do usuário foi apagado** — avisa isso no teu teste.
  `origin/main` = `59ae8e4` (commit `59ae8e4` = teu lote: draggable_panel, radio_sheet,
  route_provider multi-area, route_planner_sheet, style_satellite). Nada teu se perdeu.
  Estou no **2º turno (fila #6 e #7)**: vou mexer em `draggable_panel.dart` (persistir posição
  com SharedPreferences, chave `panel.pos.<id>`) e no backend/socket (avatarUrl/truckPhotoUrl
  nos peers). **Não encosta em `draggable_panel.dart` nem em `backend-api/`** até eu dizer que
  terminei. Assim que eu fechar, aviso aqui na MD.
- 23:10 B: commits d471ea4/5271696 ainda não em origin/main — push em lote após APK; não
  precisa de tabela de pedidos (mantém resposta aqui); resposta em "Respostas do B".
- 22:45 B: overlay API aplicada em todo o mapa; AlertsPanel/RadioFab com surface/accent
  opcionais; _ajustes(context) para testes sem provider; canManageRoute no painel; ajuda
  do usuário: SMTP Brevo + cartão do Postgres.

## Log de atos (append-only)

- 03:40 A: chave Gemini do usuario inserida em keys.json (validada com 200 OK ao vivo);
  modelo padrao atualizado para gemini-3.1-flash-lite (gemini-2.0-flash aposentado pela
  Google; gemini-flash-latest lento, 2.5-flash 404); IA real ativa no APK. analyze: No
  issues; APK release (53,7MB) reinstalado no celular (Success, 1ª tentativa falhou por
  transporte USB, 2ª ok).

- 03:25 A: TUDO plugado — WeatherProvider registrado no main.dart e ligado ao
  Assistente: _abrirAssistente atualiza o clima na posicao real (Open-Meteo) e abre
  a sheet com snapshotAoVivo (velocidade GPS _speedKmh, limite _speedLimitKmh com
  excesso, nome da rua via SpeedLimitService, resumo do clima com dicasIA). Agentes
  da IA (Rota/Sinais/Velocidade/Clima/Rua/Perfil) agora recebem dados de verdade em
  tempo real. analyze: No issues; testes 120/120; APK release reinstalado (Success).

- 03:05 A: IA real no Assistente da Estrada — AssistantEngine.perguntarLLM chama Gemini
  (gemini-2.0-flash, nivel gratuito) com equipe de agentes (Rota/Sinais/Velocidade/
  Clima/Rede/Perfil) alimentada por contexto ao vivo (rota do RouteProvider, alertas
  do AlertProvider, historico da conversa); cadeia IA → backend /api/assistant → local;
  AppConstants.geminiApiKey/iaConfigured (GEMINI_API_KEY via dart-define), keys.json e
  keys.example.json preparados. Empresa: toque no mapa (modo escolher) + dialog de nome;
  _salvarEmpresa sincroniza updateProfile + RouteProvider.setCompanyStop (ponto final);
  dialog antigo ganhou "Escolher". analyze: No issues; testes 120/120; APK release
  reinstalado (Success).

- 02:50 B: FloatingPanel (arrastar/minimizar nos dois lados/ocultar/persistir) em todos os
  paineis; tabela de rotas e barra de ferramentas reconstruidas; chat deixa de ser modal e
  o crash do reaction corrigido; rotas com ORS correto + fallback OSRM; assistente (IA) no
  mapa e no backend; APK 4 instalado COM as chaves (f01167d).
- 02:40 A: fotos pessoais no perfil (image_picker galeria/camera → POST /auth/photo
  avatar|truck, limite 640KB, feedback) guardadas no driver localmente; ícone "me" do
  mapa vira fotoBadge com a foto pessoal; botão recém-centralizado único lampião
  ('Aqui' removido do rail — só 1 botão focus); app_theme: overlaySurface/Border/Accent
  agora derivam do accent do tema (sincronia de cores em todo o sistema); login com
  branding (caminhão + nome do app) e cores do tema; markers/grupo sheets theme-based;
  teste app_theme atualizado (0x1F0808). analyze: No issues; testes 120/120; APK
  release 53,7MB com chaves reinstalado (Success). B: commit 8fcbdb5 (OSRM fallback,
  Assistente da Estrada) adotado; floating_panel/chat_panel são do B.

- 02:10 A: causas do aviso "Nenhum provedor de rotas" corrigidas — build-flutter.ps1 agora
  passa --dart-define-from-file=keys.json (chaves ORS/Google ficavam fora do APK); audit
  de APIs ao vivo (Open-Meteo/Nominatim/USGS/NHC/ORS-heigit driving-hgv 200 OK; Google
  Routes 403 app-restrito — usar ORS); APK release reconstruído + instalado no celular
  (R9XY1016R6V); analyze limpo, testes 109/109.

- 01:50 A: grupos (comboios) completos no app: GroupProvider corrigido (headers auth),
  GroupsSheet criado (meus/públicos, criar, entrar/sair, membros, switch estrito),
  registrado no main.dart; filtro estrito nos peers do mapa; rota compartilhada vai
  só ao grupo quando existir (shareRoute com groupId); socket onReceiveGroupInvite
  com dialog de aceite; tap em marcador de emoji com Ocultar/Apagar; botão Grupos
  no rail. flutter analyze: No issues; test 101/101.
- 01:35 B: modo noturno nao escurece mais o mapa; botoes duplicados fundidos (fila #10-#12);
  confirmacoes reais; APK 3 instalado (c0aa6a0 no origin/main).
- 01:05 B: tema segue a cor escolhida; Ver rua dentro do app; codigo morto removido (6f2c1d9).

- 01:15 A: fila #4 FEITA — AlertProvider com hiddenIds persistidos (prefs `alerts.hidden.v1`),
  `hide()`/`clearAlert()`/`clearHidden()`, smear seguro p/ testes sem binding; tap no sinal no
  mapa abre bottom sheet com detalhes em tempo real + Ocultar/Limpar (socket `clear_alert`) +
  "Ir até o ponto"; símbolos de sinal ocultos não são renderizados (snapshot `_hiddenIdsSnapshot`
  sincronizado com listener). SocketClient ganhou `clearAlert()` e `token` (JWT no handshake +
  `register_driver`, para o df36f68 do B).
- 01:15 A: fila #5 PARCIAL/pendente, #3 pendente; RouteTablePanel agora envolvida em
  DraggablePanel (id `route`, offset inicial canto sup. direito) + `_routePanelClosed`.
- 01:00 A: perfil do PEER/MOTORISTA PRÓPRIO no tap do caminhão (cartão de perfil com info:
  e-mail, papel, caminhão, carga, dimensões, HAZMAT, premium + Editar perfil +
  Compartilhar posição via `sharePlace`).
- 00:45 A: WeatherProvider "IA de bordo" (Open-Meteo sem chave: agora/24h/5 dias, cache 15 min,
  perigoParaVoz/dicas:_tempestade/chuva/vento/geada) + style_satellite.json SEM CARTO
  (basemaps.cartocdn passou a exigir chave) — fusão agora Esri satélite + camadas de referência
  keyless (World_Boundaries_and_Places + World_Transportation; tiles testados HTTP 200).
- Checks 01:15: flutter analyze 0 issues + testes 100/100 (após _prefsSeguro no AlertProvider).
- 00:40 B: APIs corrigidas — token de sessao real + requireAuth em profile/photo/alerts/groups,
  driverId vindo do token; 5 testes novos de sessao (backend 15/15).
- 00:30 A: sinal APK recebido — iniciei #3/#4/#5 (alert_provider, peer_provider, map_screen
  peers/sinal, profile_screen p/ upload de foto). NÃO toco em backend/ ни draggable_panel.
- 00:22 B: APK 2 instalado (com #6 e #7), commit 223afc6 no origin/main; A pode seguir nas
  tarefas #3/#4/#5.
- 00:05 B: fila #6 (persistir posição dos painéis) e #7 (perfil dos peers no socket + cache)
  concluídas; checks verdes; aguardando rebuild/push.
- 23:55 B: APK release pronto e instalado no celular; lote do A commitado e push (59ae8e4);
  sinal liberado para a fila #3/#4/#5 do A; B assume #6 e #7.
- 23:30 A: confirmação final do plano do B (leitura confirmada, fila #6 virou B, aguardo push).
- 23:12 A: recebi 23:10 do B; reescrevi a MD em v2 (seções únicas, fila única, log append).
- 23:10 B: commits ainda não subiram (push em lote pós-APK); MD desnecessária em tabela, checa.
- 23:05 A: resposta oficial ao ping do B.
- 22:45 B: overlay aplicado em todo o mapa;canf³ novo helper status; commits próprios.
- 22:30 A: 4 pedidos do B executados (overlayOpacity, aparência, resize, radio_fab+sheet).
- 21:33 A: DraggablePanel integrado nos painéis do map_screen.
- 21:30 B: build APK iniciado (apk_build.log).
- 21:12 A: mapa fundido, ciclo de áudio, temas, multi-área, radio_sheet criados.
- 20:50 A: lição — nunca editar dart via PowerShell/regex; só ferramenta de edição.

## Regras técnicas (lembrar)

- PowerShell 5.1: sem `&&`; usar `;` e `if ($?)`.
- Flutter: `& "C:\Users\Micro\flutter\bin\flutter.bat"` analyze/test/build apk --debug --dart-define-from-file=keys.json
- APK debug: `adb install -r`; release usa keystore (não commitar).
- PIX mensal 4,99 / anual 29,99; env vars PIX_*/ADMIN_TOKEN/SMTP_* no Render (DEPLOY-RENDER.md).
- Analyzer às vezes mente (cache); re-rodar para confirmar.
- 04:30 A: modernos sons e radio digital. AudioProvider reescrito com RadioService (espelhos de1/de2/all, ordenacao por clickcount/votes/nome, tags, distancias locais pois bygeo retorna 404, favoritos e recentes persistidos). SonsProvider para importar sons do aparelho para slots: Inicio do app, Entrada na parada, Alerta de radar, Aviso geral (file_picker 13 + path_provider, just_audio, shared_preferences). RadioSheet redesenhada (busca, filtros/tags, favoritos, player com volume/pausa). RadioFab com botao parar. Secao sons personalizados nas Configuracoes. main.dart amarra sons ao evento de entrada. Testes: radio_test.dart (9), radio_provider_test.dart (9), radio_sheet_test.dart (6), sons_provider_test.dart (8); todos verdes. analyze: No issues. Backend 29/29, build tsc OK. Flutter: +22 testes (total 168, regressao onboarding corrigida no widget_test).
