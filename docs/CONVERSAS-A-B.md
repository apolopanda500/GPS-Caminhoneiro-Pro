# Conversas entre os agentes (A ↔ B) — GPS Caminhoneiro Pro

Registro resumido das decisões tomadas em paralelo pelos dois agentes que
trabalham neste repositório. O canal oficial continua sendo
[`COORDENACAO-AGENTES.md`](../COORDENACAO-AGENTES.md) (estado atual, fila de
tarefas e log append-only). Este arquivo guarda o **histórico** do que foi
combinado, para ninguém (nem humano, nem agente) reinventar o que já foi
resolvido.

## Como os agentes conversam

- **Canal**: o arquivo `COORDENACAO-AGENTES.md` na raiz.
- **Protocolo**: cada agente lê o MD no início de cada tarefa, escreve em
  "Respostas do A" ou "Respostas do B", e registra o que fez em "Log de atos"
  (append-only).
- **Donos de arquivos**: a tabela no MD define quem mexe em quê. Antes de tocar
  no arquivo de outro agente, registra o pedido e espera.
- **Commits**: um commit por agente; o agente B coordena o push em lote para
  `origin/main` (o Render faz auto-deploy no push).

## Linha do tempo

### Rodada 1 — correção de produção (agente A)
- Mapa fundido satélite + rótulos, ciclo de áudio (rádio cede à estação, duck
  no sino da parada), temas escuro/claro reconstruídos, `DraggablePanel`
  nos painéis do mapa, multi-área de bairros na rota, `radio_sheet.dart`.
- **Pedido ao B**: nada nesta rodada.

### Rodada 2 — agente B (backend, validação, ajudante, aparência)
- **Validação real de e-mail** (decidido com o usuário):
  - cadastro **sempre** exige código (503 se o SMTP não estiver configurado —
    antes ele criava a conta já "verificada" sem nunca validar);
  - e-mail com formato válido e senha com no mínimo 6 caracteres;
  - login de conta não verificada **reenvia** o código;
  - *backfill*: as contas antigas que nunca foram validadas de verdade
    (`verified_at IS NULL`) voltam a exigir confirmação — **só quando o SMTP
    está ativo**, justamente para não travar o acesso de ninguém;
  - decisão do usuário: **validar todas as contas** (não só as novas).
- **Papel "ajudante"** (decidido com o usuário): acompanha todos os
  motoristas e outros ajudantes, vê rotas compatíveis, envia sinais e alarmes,
  mas **não monta nem inicia rota**; e o cadastro de ajudante **pula a etapa de
  configurar caminhão** (entra direto no mapa).
  - bloqueio no app (ação "Rota" some, botão "INICIAR ROTA" vira aviso) e no
    backend (`shareRoute` REST e `share_route` no socket, olhando o papel no
    banco).
- **Painel de sinais (SINAL) travado na tela** (bug crítico do usuário):
  `AlertsPanel` com arrastar, **minimizar** e **fechar**, no lugar do cartão
  fixo.
- **Aparência**: tela nova `appearance_screen.dart` com transparência (30–100%)
  e 6 cores de destaque, gravadas em `SettingsProvider`.
- **Rádio digital**: `radio_fab.dart` (botão flutuante pulsante) abrindo o
  `radio_sheet` do agente A, com volume no `AudioProvider`.

### Rodada 3 — o agente A entrega os 4 pedidos do B
1. `app_theme.dart` passa a aceitar `opacity`/`accent` em
   `overlaySurface`/`overlayBorder`/`overlayAccent`.
2. Item "Aparência do mapa" nas Configurações abrindo a tela do B.
3. Alça de redimensionamento na tabela de rotas (`resize()` finalmente com
   gesto).
4. Confirmação de que o botão de rádio do B deve abrir o `radio_sheet` do A
   (sem duplicar o sheet).

### Rodada 4 — fila combinada (A e B em paralelo)
- **B**: #6 persistir a posição dos painéis (`panel.pos.<id>` em
  SharedPreferences) e #7 mandar o perfil (avatar/foto do caminhão) dos peers
  logo na entrada na rede, com cache de 60 s do perfil no banco.
- **A**: #3 foto do motorista no mapa, #4 tap no sinal com bottom sheet de
  detalhes/ocultar, #5 filtro "só amigos selecionados".

### Rodada 5 — "corrigir APIs" (usuário)
Antes, **qualquer um** podia editar o perfil/foto de qualquer motorista só
enviando o `driverId` no corpo da requisição. Agora:
- `POST /api/auth/login|register|verify` devolvem um **token de sessão**
  (HMAC-SHA256, validade de 30 dias);
- `requireAuth` (o middleware antigo era um stub que aceitava qualquer token)
  protege `/auth/profile`, `/auth/photo`, `POST /api/alerts`,
  `POST /api/alerts/messages` e todas as rotas de `/api/groups`;
- o `driverId` **nunca mais vem do corpo/query**: vem do token;
- o Socket.io aceita o token no handshake e usa essa identidade;
- 5 testes novos (`session.test.ts`) — backend com 15/15.

### Rodada 6 — limpeza e unificação (usuário)
- **"Ver rua"** deixa de abrir o Google Maps: a função existe **dentro do app**
  (imagens da rua com zoom e troca de foto).
- **Confirmação real em todo botão crítico**: novo `core/utils/confirm.dart`
  (`confirmarAcao`/`confirmarEExecutar`) usado em confirmar entrega, iniciar
  rota, limpar sinais, sair da conta e gerar o PIX.
- **Códigos mortos removidos**: `config/security.ts` (SecurityEngine sem uso),
  `_RadioSheet` duplicado dentro das Configurações, `googleStreetViewLink`,
  `googleMapsLink`, `abrirRadioDigital` e a classe `OverlayStyle` (duplicava o
  `app_theme`).
- **Temas**: `appTheme`/`appLightTheme` viraram funções com `accent` — a cor
  escolhida pelo usuário agora vale para **todo** o app (botões, cartões,
  appbar, chips, campos, switch, snackbar), e não só para o mapa.
- **Botões com o mesmo comando foram fundidos**: 3D entrou no botão de camada do
  mapa; o rádio ficou no botão flutuante + Configurações (saiu da barra
  lateral).

## Regras que os dois agentes seguem

1. Nada de `git checkout --` em arquivo de outro agente.
2. Editar `.dart`/`.ts` **sempre** pela ferramenta de edição, nunca com
   `Set-Content`/regex no PowerShell (já perdemos código assim).
3. Commit por agente; push em lote pelo B.
4. Antes de buildar o APK: `flutter analyze` + `flutter test` verdes, e o
   backend com `npm test` verde.
5. Se um agente estiver no meio de uma edição, o outro **não mexe** no mesmo
   arquivo e espera o sinal no MD.
