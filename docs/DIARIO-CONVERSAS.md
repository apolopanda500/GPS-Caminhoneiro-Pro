# DiÃ¡rio de conversas - GPS Caminhoneiro Pro

Registro cronolÃ³gico de cada pedido do dono do projeto e o que foi feito
nesta sessÃ£o de validaÃ§Ã£o. Serve para continuar de onde parou.

---

### Rodada 1 - "entender aplicativo completo"
**Pedido:** entender o app inteiro.
**Feito:** mapa da arquitetura (Flutter + MapLibre, backend Node/Socket.io, PostGIS,
chaves por `dart-define`, deploy Render + Supabase) e a lista de pendÃªncias
reais (PIX no Render, SHA-1 do Google, `DATABASE_URL` no pooler do Supabase).

### Rodada 2 - "validar projeto pronto pra uso real"
**Pedido:** validar para uso real, nota 10/10.
**Feito:** bateria multi-usuÃ¡rio real (10 perfis), bateria no app (13 testes),
APK release assinado instalado e testado no aparelho (permissÃµes â†’ login real
â†’ onboarding â†’ mapa â†’ GPS 24/7 em primeiro plano), zero crash.
**Achado:** Premium quebrado em produÃ§Ã£o (faltam as envs `PIX_*` no Render).

### Rodada 3 - "criar baterias de simulaÃ§Ã£o real, vÃ¡rios usuÃ¡rios diferentes"
**Pedido:** simular vÃ¡rios usuÃ¡rios, uso geral completo, comunicaÃ§Ãµes reais.
**Feito:** observador de rede (`tools/observador-v2x.js`), BlueStacks verificado
(sÃ³ a Loja: motor do emulador ausente) â†’ "PC" passou a ser o **emulador Android
(AVD `teste_apk`)**; APK **arm64-only nÃ£o roda em x86_64** (crash
`UnsatisfiedLinkError`) â†’ build **arm64+x64**; AVD precisou de partiÃ§Ã£o menor
(`-partition-size 2040`).
**Bugs reais corrigidos:** chat sem histÃ³rico, fotos de perfil iguais, Ã­cones dos
peers iguais, rota de grupo nÃ£o salva, busca de endereÃ§o travada (agora
dispara sozinha enquanto digita) e **Ã­cone novo** (preenchido, sem borda
branca, estilo Chrome) gerado por `tools/gerar-icone.ps1`.

### Rodada 4 - "criar grupos, compartilhar rota, tempo real, ver 9/10 rotas"
**Pedido:** compartilhamento de rota que funcionasse, acompanhamento ao vivo nos
dois sentidos, ediÃ§Ã£o no grupo, vÃ¡rias rotas por motorista e o usuÃ¡rio escolher
quais ver (1 de 10, 9 de 10...).
**Feito:** `share_route` com `shareId` (UUID) e paradas; `follow_route`,
`unfollow_route`, `route_progress`; `PATCH`/`DELETE` das rotas do grupo;
`SharedRoutesProvider` (visibilidade salva), `SharedRoutesPanel` (olho,
ACOMPANHAR, status ao vivo, remover), **linha da rota compartilhada no mapa** e o
dono avisando o progresso das suas paradas.

### Rodada 5 - "sons sincronizados, voz resumida, Waze/Uber/99, rÃ¡dio Muzio"
**Pedido:** sons batendo certo com as paradas, botÃ£o para ouvir sÃ³ o sino,
falar menos, perfis no estilo Waze/Uber/99, sino de estaÃ§Ã£o sempre, rÃ¡dio com
tocador estilo Muzio, mais baterias, commit/push/deploy, salvar conversas.
**Feito:** sino sÃ³ na chegada (antes tocava duas vezes), **sino de estaÃ§Ã£o**,
**som de saÃ­da** prÃ³prio, regra em `som_da_parada.dart`; `falas.dart` com 4
perfis e frases curtas; **"SÃ³ o sino (sem falar as ruas)"**; botÃµes para ouvir
cada som; **tocador estilo Muzio**; bateria do ciclo de vida (21 testes);
documentaÃ§Ã£o em `docs/`.

### Rodada 6 - "mÃ¡ximo de baterias, 100% commit push deploy, salvar conversas"
**Pedido:** o mÃ¡ximo de baterias e testes, tudo real, 10/10, commit/push/deploy
sempre, conversas salvas e documentadas.
**Feito:** as baterias ficaram **independentes do banco** (conferem tudo pelo
servidor: API + radar), ganharam o modo `--criar` (cadastro real do app) e
passaram a rodar **tambÃ©m em produÃ§Ã£o**: 15/15 e 9/10 (o 10Âº Ã© a env `PIX_*`).
Runner Ãºnico de todas as baterias (`tools/rodar-baterias.ps1`) e este diÃ¡rio.

---

## O que estÃ¡ pronto (resumo)

- App Android assinado, rodando no celular e no emulador, contra o deploy real
- Rede V2X, chat (pÃºblico e privado), reaÃ§Ãµes, alertas por proximidade, grupos
  com rota compartilhada em tempo real, rotas com paradas/entregas, rÃ¡dio com
  tocador, voz com 4 perfis, sons sincronizados, busca automÃ¡tica, mapa 3D com
  trÃ¡fego/clima, Premium via PIX (falta sÃ³ a env no Render)

## O que falta (aÃ§Ã£o do dono do projeto)

1. **envs `PIX_*` no Render** â†’ o Premium volta a funcionar (fila #18)
2. **`DATABASE_URL` do Render para o pooler do Supabase** â†’ o Postgres do Render
   expira em 18/11/2026 (fila #20)
3. **Perfil no celular â†’ SALVAR** depois da troca do banco, para voltar a foto
   original (fila #21)
4. **SHA-1 (release + debug) na chave do Google Routes** (fila #17)

---

### Rodada 8 - "botoes e alcas visiveis, chuva e nuvens reais"
**Pedido:** corrigir botoes flutuantes e alcas transparentes/invisiveis; nuvens e
areas de chuva reais no mapa.
**Feito:** botoes do mapa com 40 px, borda, sombra e alvo de toque maior; alcas de
redimensionar agora ficam ocultas por padrao, aparecem nitidas no menu de toque
longo e a preferencia e salva; tab minimizada com fundo solido e sombra. Corrigido
o bug que impedia o radar RainViewer e o satelite infravermelho de renderizarem:
o MapLibre recebia um tile fixo `0/0/0` em vez do modelo `{z}/{x}/{y}`. A grade
Open-Meteo agora entende a resposta em lista de varias coordenadas (chuva, vento,
temperatura e nuvens previstas voltam a aparecer). Quando o feed de satelite do
RainViewer esta vazio, a camada Nuvens cai automaticamente na cobertura prevista
pela Open-Meteo e o painel avisa que o satelite esta indisponivel. Textos
corrompidos de rota, contatos, historico e permissoes restaurados. Checks:
analyze sem pendencias, 234 testes verdes e APK debug reinstalado sem FATAL/ANR.

### Rodada 7 - "GPS real, camera do caminhoneiro e rota que se corrige"
**Pedido:** GPS nao pode ficar travado ao sair da rota; transito nao pode cobrir os
nomes das ruas; a linha da rota deve acompanhar o caminhao; camera 3D frontal como a
visao do motorista; precisao de 10-20 m.
**Feito:** desvio confirmado em 3 leituras acima de 80 m recalcula a rota sozinho
(paradas entregues ficam de fora, cooldown de 25 s); trecho percorrido sai da linha;
camera segue o rumo real em 3 modos (2D, 3D navegacao e cabine 3D com tilt 60); o
seguimento nao e mais desligado por movimento programatico; transito entra abaixo dos
rotulos e mostra so lentidao; GPS em `bestForNavigation` sem filtro de distancia.
