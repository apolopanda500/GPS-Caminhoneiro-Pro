# Histórico de conversas e decisões (GPS Caminhoneiro Pro)

Registro das pedidos do dono do projeto e do que foi feito em cada rodada.
Serve para o app continuar evoluindo no mesmo rumo.

---

## Rodada 1 - "entender aplicativo completo"

Pedido: entender o app inteiro (código, arquitetura, backend, banco, integrações).
Entregue: mapa completo do projeto (Flutter + MapLibre, backend Node/Socket.io,
PostGIS, chaves por `dart-define`, deploy Render + Supabase) e a lista de
pendências reais (PIX no Render, SHA-1 do Google, `DATABASE_URL` no pooler).

## Rodada 2 - "validar projeto pronto pra uso real"

Pedido: validar o projeto para uso real, nota 10/10.
Entregue:
- **Bateria multi-usuário real** (`tools/bateria-simulacao-real.js`): 10
  motoristas com perfis diferentes, cadastro/e-mail, rede V2X, alertas, chat,
  grupos, Premium via PIX, segurança e carga. Resultado **10/10**.
- **Bateria no app** (`test/bateria_simulacao_real_test.dart`): 13 testes.
- APK release assinado, instalado e testado no aparelho (Samsung, Android 15):
  permissões, login real no Render, onboarding, mapa com satélite, HUD,
  serviço de GPS 24/7 em primeiro plano, zero crash.
- Achado: **Premium quebrado em produção** (`PIX_*` ausente no Render).

## Rodada 3 - "criar baterias de simulação real, como se fosse vários usuários"

Pedido: simular vários usuários, uso geral completo, comunicações reais.
Entregue:
- **Observador de rede** (`tools/observador-v2x.js`): prova independente do que
  passa no socket.
- **BlueStacks** foi verificado (só a "Loja" instalada, motor do emulador
  ausente) → o "PC" passou a ser o **emulador Android (AVD `teste_apk`)**.
- Descoberta operacional: APK **arm64-only não roda em x86_64** (crash
  `UnsatisfiedLinkError`); o AVD precisava de partição menor (`-partition-size`).
- **Bugs reais achados e corrigidos**:
  1. chat sem histórico (a tela Rede passava `messages: const []`);
  2. fotos de perfil iguais (o app só lia foto por http, mas o banco guarda
     data URL base64) → novo utilitário `fotos_motorista.dart`;
  3. ícones dos peers iguais (o nome da imagem no MapLibre vinha do tamanho da
     foto) → agora inclui o id do motorista;
  4. rota de grupo não ficava salva (o socket só emitia);
  5. busca de endereço travada (precisava da lupa) → agora dispara sozinha
     enquanto digita, com os resultados abaixo do campo.
- **Ícone novo**: preenchido, sem borda branca (estilo Chrome), gerado por
  `tools/gerar-icone.ps1`.

## Rodada 4 - "criar grupos, compartilhar rota, tempo real, ver 9/10 rotas"

Pedido: compartilhamento de rota que funcionasse de verdade, com
acompanhamento ao vivo das paradas nos dois sentidos, edição no grupo, várias
rotas por motorista e a escolha de quais rotas ver (1 de 10, 9 de 10...).
Entregue:
- **Backend**: `share_route` com `shareId` (UUID), `follow_route`,
  `unfollow_route`, `route_progress` (chegou/entregue) e gravação do progresso
  no banco; REST `PATCH`/`DELETE` para editar e remover rota do grupo.
- **App**: `SharedRoutesProvider` (lista, visibilidade persistida, acompanhar,
  progresso ao vivo), `SharedRoutesPanel` dentro da tabela de rotas (olho por
  rota, "ACOMPANHAR", status por parada), linha da rota compartilhada desenhada
  no mapa, e o dono avisando o progresso das suas paradas.
- **Bateria nova**: cenários 13, 14 e 15 na bateria das duas contas.

## Rodada 5 - "sons sincronizados, voz resumida, perfis Waze/Uber/99, rádio"

Pedido: sons batendo certo com as paradas, botão para ouvir **só o sino**,
falar menos, perfis no estilo Waze/Uber/99, sino de estação sempre, rádio
melhorado com tocador estilo Muzio, e mais baterias até 10/10.
Entregue:
- **Sons**: sino só na chegada (antes tocava duas vezes), **sino de estação**
  (sino de trem) sempre na chegada, **som de saída** separado, e a regra
  centralizada em `som_da_parada.dart` (testável).
- **Voz**: módulo `falas.dart` com 4 perfis (Padrão resumido, Waze, Uber, 99),
  frases curtas ("Próxima: 3", "3, 2 km"), opção **"Só o sino (sem falar as
  ruas)"** e botões para ouvir cada som.
- **Rádio**: **tocador estilo Muzio** (capa grande, play/pause, anterior/
  próxima, volume, fila, favoritos) e fila no `AudioProvider`.
- **Bateria do ciclo de vida** (`test/bateria_ciclo_vida_test.dart`): 21 testes
  de voz, sons e rotas compartilhadas.

## Regras que ficaram (do dono do projeto)

- Falar **curto**: o GPS fala o essencial e não enrola.
- O sino toca **uma vez só** na chegada; a saída tem som próprio.
- O motorista escolhe **quais rotas compartilhadas quer ver**.
- Nada de "simulação no papel": toda bateria fala com o servidor de verdade.
- Commit, push e deploy sempre que a rodada fechar.
