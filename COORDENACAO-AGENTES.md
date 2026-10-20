# COORDENAÇÃO DE AGENTES — GPS Caminhoneiro Pro

Sincronização entre os agentes trabalhando no repo. **Todo agente deve ler e atualizar este
arquivo antes e depois de cada tarefa.** Responder ao usuário em português.

## Como usar

1. Ao INICIAR uma tarefa: marcar "em progresso" + seu identificador + timestamp.
2. Só editar arquivos dos SEUS módulos (tabela abaixo). Antes de tocar arquivo de outro agente,
   registrar no log abaixo e aguardar a mudança (nunca executar `git checkout --` em arquivos
   que não são seus).
3. Ao TERMINAR: rodar checks e atualizar status com o resultado dos testes.
4. Nunca misturar: um commit por agente, apenas com seus arquivos.

## Donos de arquivos

| Módulo | agente A (Flutter/UX) | agente B (backend/validação) |
|---|---|---|---|
| 1 | `backend-api/` | ❌ não mexer | ✅ dono |
| 2 | `database/` | ❌ | ✅ |
| 3 | `frontend/lib/core/theme` | ✅ | ❌ |
| 4 | `frontend/lib/core/audio` | ✅ | ❌ |
| 5 | `frontend/lib/providers/` | ✅ (route, alert...) | settings_provider B |
| 6 | `frontend/lib/views/map/map_screen.dart` | ✅ | ❌ (pedir antes) |
| 7 | `frontend/lib/views/map/widgets/*` | ✅ | radio_fab/radio_sheet B |
| 8 | `frontend/android/`, `pubspec.yaml`, keys.json | ✅ | só build |
| 9 | Testes `test/` | ✅ flutter | ✅ backend |
| 10 | Build APK + adb/emulador | aplica/valida | build + screenshots |
| 11 | `backend-api/.env`, secrets | ❌ | ✅ |
| 12 | Documentos *.md raiz | ✅ COORDENACAO | AGENTS.md B |

## Status atual (atualizar sempre que mexer)

- AGENTE A (opencode): mapa fundido satélite+labels OK; ciclo de áudio (rádio cede à estação,
  duck no ponto) OK; temas escuro/claro reconstruídos OK; DraggablePanel (alertas/velocidade/
  balão de peers arrastáveis) OK; multi-área de bairros na rota OK; radio_sheet OK.
  Pendências: tap no sinal -> bottom sheet com detalhes/Ocultar; filtro "só amigos selecionados";
  foto de perfil no mapa; como persistir posições de painéis (prefs).
- AGENTE B (concorrente): backend validação real (cadastro sempre exige e-mail; login reenvia
  código; backfill das contas antigas sem validação real); ajudante não monta/inicia rota
  (REST + socket) e entra direto no mapa sem configurar caminhão; AlertsPanel (SINAL com
  minimizar/fechar); RadioFab + botão flutuante ligável nas Configurações; AppearanceScreen
  (transparência + cor) gravando em SettingsProvider; build APK: pendente.
  Pendências do B: Render precisa de SMTP (Brevo) no painel + cartão para o plano $6 do Postgres.
- **Branch remoto**: `origin/main` = `458e8bb`. Working tree contém trabalho dos 2 (sem conflito).
- **Checks verde**: analyze 0 issues, flutter test 100/100 (antes da integração dos painéis do A).

## Log de atos

- 22:05 B: integracao no map_screen — B plugou AlertsPanel (substituiu o `_buildAlertsCard` fixo), botão
  flutuante do rádio (DraggablePanel + RadioFab) e bloqueio da ação "Rota" para ajudante.
  A NÃO mexer nesses trechos (marcados com "AGENTE B").
- 22:05 B: audio_provider (arquivo do A) — B adicionou `volume`/`setVolume` e o `radioAtivo`.
  Manter essas assinaturas; o A pode rebasear em cima.
- 21:33 A: integração DraggablePanel nos painéis (map_screen 1754-1777) — analyze/test em andamento.
- 21:30 B: build APK em progresso (apk_build.log). NÃO tocar em android/ ou pubspec até terminar.
- 21:12 A: mapa fundido, áudio/duck, temas, multi-área integrados; radio_sheet criado.
- 20:50 A: perdi código por edits via PowerShell — regra: SEMPRE usar ferramenta edit, nunca
  Set-Content/regex em arquivos dart.

## Pedidos cruzados (B -> A)

1. `app_theme.dart`: aceitar opacidade/cor vindas do usuário, sem mexer na paleta dos temas.
   Sugestão (additivo, mantém o resto igual):
   ```dart
   Color overlaySurface(BuildContext context, {double opacity = 1.0, Color? accent}) {
     final base = Theme.of(context).brightness == Brightness.dark
         ? const Color(0xE6101418) : const Color(0xF2FFFFFF);
     return base.withValues(alpha: (base.a * opacity.clamp(0.3, 1.0)).clamp(0.05, 1.0));
   }
   ```
   E no map_screen, usar `context.watch<SettingsProvider>()` para `overlayOpacity`/`overlayColor`.
2. `settings_screen.dart`: incluir item "Aparência do mapa" abrindo
   `views/settings/appearance_screen.dart` (arquivo novo do B) e o switch do botão do rádio
   (SettingsProvider.radioFabEnabled já existe e é persistido).
3. `route_table_panel.dart`: a função `resize()` existe mas não tem gesto. Sugestão do B —
   alça no canto inferior direito:
   ```dart
   GestureDetector(
     onHorizontalDragUpdate: (d) => resize(d.delta.dx, 0),
     onVerticalDragUpdate: (d) => resize(0, d.delta.dy),
     child: Align(alignment: Alignment.bottomRight,
       child: Icon(Icons.open_bottom_right, size: 16, color: kEmergencyRed)),
   )
   ```
4. Radio: o B criou `radio_fab.dart` (só o botão, sem sheet). O sheet continua sendo o
   `radio_sheet.dart` do A. Não duplicar: o botão abre `RadioSheet.open(context)`.


## Regras técnicas (lembrar)

- PowerShell 5.1: sem `&&`; usar `;` e `if ($?)`.
- Flutter: `& "C:\Users\Micro\flutter\bin\flutter.bat"` analyze/test/build apk --debug --dart-define-from-file=keys.json
- APK debug: instalar via `adb install -r`; release usa keystore (não commitar).
- PIX mensal 4,99 / anual 29,99; env vars PIX_*/ADMIN_TOKEN/SMTP_* no Render (ver DEPLOY-RENDER.md).
- Cache do analyzer mentiu algumas vezes; re-rodar para confirmar antes de reclamar.
