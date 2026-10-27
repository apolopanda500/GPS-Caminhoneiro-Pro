# 📜 Regras do Projeto

## Regras Gerais
- Responder sempre em **português do Brasil**
- Um commit por agente; push em lote pelo agente B
- Nunca adicionar botões sem comando real (sem "opções genéricas")
- Sem comentários no código (salvo pedido explícito)
- Rodar `flutter analyze` + `flutter test` antes de concluir qualquer tarefa Flutter
- Backend deve ter `npm test` verde antes de buildar APK

## Regras de Colaboração (Multiagente)
- Ler e atualizar `COORDENACAO-AGENTES.md` antes e depois de cada tarefa
- Editar somente arquivos do SEU módulo (tabela de donos no COORDENACAO-AGENTES.md)
- Arquivo alheio = registrar pedido na Fila de tarefas e aguardar
- Nada de `git checkout --` em arquivo de outro agente
- Editar `.dart`/`.ts` sempre pela ferramenta de edição, nunca com `Set-Content`/regex no PowerShell
- Se um agente estiver no meio de uma edição, o outro não mexe no mesmo arquivo

## Regras de Código Flutter
- Providers via `provider` + `ChangeNotifier`; registrar em `lib/main.dart`
- Preferências persistidas com `shared_preferences` (ver `SettingsProvider`)
- Novos arquivos Dart seguem `lib/` (<->) `test/`
- Ao criar múltiplos `FloatingActionButton` na mesma tela, definir `heroTag` único
- Evitar `flutter_local_notifications` (removido por incompatibilidade de build)

## Regras de Uso Real (App 10/10)
- Sino toca uma vez só na chegada; saída tem som próprio
- Motorista escolhe quais rotas compartilhadas quer ver
- Nada de "simulação no papel": toda bateria fala com o servidor de verdade
- Commit, push e deploy sempre que a rodada fechar
- Falar curto: o GPS fala o essencial e não enrola
