# Próxima sessão — pendência única: reiniciar o PC (emulador)

> Documento de passo a passo para retomar o projeto **depois do reboot**.
> Quem continuar (humano ou agente) deve seguir este arquivo do início ao fim.

---

## 1. Estado atual do projeto (22/10/2026, ~00:30)

| Verificação | Resultado | Observação |
|---|---|---|
| Bateria simulação real (10 cenários) contra produção | **10/10 — nota 10.0** | PIX fechou: ADMIN_TOKEN setado no Render + bateria confere via `/api/admin/backup` |
| Bateria duas contas (15 cenários) contra produção | **14/15 — nota 9.3** | Só falha o cenário 12 (precisa de 2 aparelhos = emulador) |
| `flutter analyze` | No issues found | |
| `flutter test` | 233/233 verdes | |
| Backend `npm test` | 29/29 (com e sem `.env`) | |
| CI no GitHub (Flutter, Node, Android, CodeQL) | **4/4 verdes** | workflows curados: 12 templates inúteis removidos, 4 corrigidos |
| Celular `R9XY1016R6V` | conectado, app instalado e validado | |
| Emulador AVD `teste_apk` | **bloqueado — único pendente** | WHPX habilitado, aguarda reboot |

**Único passo que falta: reiniciar o computador.** Depois disso, tudo abaixo fecha o **15/15**.

---

## 2. Por que o reboot

- O emulador Android x86_64 exige aceleração de hardware (WHPX).
- A feature `HypervisorPlatform` foi habilitada via PowerShell elevado
  (retornou `RestartNeeded = True`), mas o Windows **não foi reiniciado** desde então.
- O WSL2 (Ubuntu-24.04) é compatível com WHPX — o reboot **não quebra** nada.
- Erro atual sem reboot: `x86_64 emulation currently requires hardware acceleration!`
  (por causa do hipervisor do WSL2 ativo).

---

## 3. Depois do reboot — passo a passo

### 3.1 Confirmar que o WHPX está ativo

```powershell
Get-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform | Select-Object State
```

Esperado: `State : Enabled`.
Se `Disabled`:

```powershell
Start-Process powershell -Verb RunAs -ArgumentList '-Command', 'Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All -NoRestart'
```

(e reiniciar de novo).

### 3.2 Subir o emulador

```powershell
$env:ANDROID_SDK_ROOT = "C:\Users\Micro\AppData\Local\Android\Sdk"
Start-Process -FilePath "$env:ANDROID_SDK_ROOT\emulator\emulator.exe" `
  -ArgumentList '-avd', 'teste_apk', '-gpu', 'swiftshader_indirect'
```

- AVD: `teste_apk` (android-34, x86_64) em `C:\Users\Micro\.android\avd\teste_apk.avd`.
- Imagem do sistema já está completa em
  `%LOCALAPPDATA%\Android\Sdk\system-images\android-34\google_apis\x86_64`
  (inclui `kernel-ranchu`). **NÃO reinstalar** via sdkmanager (estoura o disco; zip de
  1491MB teve que ser baixado na mão).
- Confirmar: `& "C:\Program Files\platform-tools\adb.exe" devices` → deve listar
  `emulator-5554 device` **e** `R9XY1016R6V device` (celular via USB).

### 3.3 Instalar/abrir o app no emulador

APKs de backup (não precisa rebuildar):

- Release: `C:\Users\Micro\AppData\Local\Temp\opencode\apks\app-release.apk` (~75 MB)
- Debug (mais recente, com as últimas melhorias): rebuildar com
  `& "C:\Users\Micro\flutter\bin\flutter.bat" build apk --debug` em `frontend-flutter`
  → `frontend-flutter\build\app\outputs\flutter-apk\app-debug.apk`

```powershell
& "C:\Program Files\platform-tools\adb.exe" -s emulator-5554 install -r "<caminho-do-apk>"
& "C:\Program Files\platform-tools\adb.exe" -s emulator-5554 shell am start -n com.gpscamioneiro.gps_camioneiro_pro/.MainActivity
```

Na primeira abertura: conceder permissões de localização/notificação no diálogo.

### 3.4 Logar a 2ª conta no emulador

- No emulador: entrar com a conta `DEV_PC` usada pela bateria
  (`DEV_PC=emulator-5554` está no topo de `tools/bateria-duas-contas.js`;
  a conta é criada pelo próprio script com `--criar` — se o app pedir login manual,
  use a conta que a bateria criar, ou cadastre uma nova no app).
- Celular: manter o app aberto (conta `DEV_CELULAR=R9XY1016R6V`).

### 3.5 Rodar a bateria final

```powershell
cd C:\Users\Micro\gps-camioneiro-pro-completo
node tools\bateria-duas-contas.js --url https://gps-truck-backend.onrender.com --criar
```

Meta: **15/15 — nota 10.0**. O cenário 12 só passa com os dois aparelhos
(app aberto, um em cada device — o script confere via `adb`).

### 3.6 Se algo falhar

| Problema | Ação |
|---|---|
| Emulador pede accel de novo | Conferir `Get-WindowsOptionalFeature ... HypervisorPlatform` (tem que estar Enabled **após** o reboot) |
| `adb devices` só mostra o celular | Fechar e reabrir o emulador; checar porta `5554` |
| Cenário 12 diz "app nao esta rodando no PC" | Abrir o app no emulador manualmente antes de rodar a bateria |
| Render dormiu (primeira chamada lenta) | Bater `https://gps-truck-backend.onrender.com/health` uma vez (404 é normal — só acorda o serviço) |
| Push de git travar | Usar o método do header Basic (ver seção 5) |

---

## 4. Comandos essenciais (guia rápido)

```powershell
# Flutter (SDK fora do PATH)
& "C:\Users\Micro\flutter\bin\flutter.bat" analyze    # esperado: No issues found!
& "C:\Users\Micro\flutter\bin\flutter.bat" test       # esperado: 233+ verdes
& "C:\Users\Micro\flutter\bin\flutter.bat" build apk --debug

# Backend
cd backend-api; npm test                              # 29/29

# Baterias (produção)
cd C:\Users\Micro\gps-camioneiro-pro-completo
node tools\bateria-simulacao-real.js --url https://gps-truck-backend.onrender.com      # 10/10
node tools\bateria-duas-contas.js  --url https://gps-truck-backend.onrender.com --criar # 14/15 → 15/15 pós-reboot

# adb
& "C:\Program Files\platform-tools\adb.exe" devices
& "C:\Program Files\platform-tools\adb.exe" exec-out screencap -p > tela.png   # screenshot (usar cmd /c se corromper)
```

---

## 5. Push no git (obrigatório assim — o GCM trava)

```powershell
$line = Get-Content "$env:USERPROFILE\.git-credentials" -TotalCount 1
$m = [regex]::Match($line, '://([^:]+):([^@]+)@')
$basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($m.Groups[1].Value):$($m.Groups[2].Value)"))
git -c "http.extraHeader=Authorization: Basic $basic" -c credential.helper= push origin main
```

- Não usar `git push` normal (janela de login do Windows travando).
- Push para `main` dispara auto-deploy no Render (pode haver reinício momentâneo).

---

## 6. Pendências conhecidas (opcionais, depois do 15/15)

1. **Bancos divergentes**: o Render grava no Postgres próprio (expira 18/11/2026);
   o local usa Supabase (pooler em `backend-api/.env` → `DATABASE_URL`).
   Trocar o `DATABASE_URL` do Render para o pooler do Supabase unifica os dados
   (decisão do usuário — os dados atuais do Render ficariam de trás; há 292 pagamentos
   locais vs. produção no Render).
2. **Pedidos abertos do usuário** (para novas sessões): notificação push mais rica na
   barra do Android; mais opções de ângulo/inclinação da câmera; melhorar "aparência"
   (barras, bordas, linhas, temas); duplicidade dos botões Mapa/Gráfico (manter só na
   tela principal); camadas (nuvens/terrenos/ventos/precipitação) precisam mudar de
   verdade ou serem removidas se genéricas; foto de perfil visível a todos; sensibilidade
   dos botões flutuantes; rota só com pesquisa de endereços próximos (remover bairro);
   fundir "limpar sinais" e "limpar cache"; checklist completo de todos os botões
   (real vs genérico) com baterias e documentação um a um.
3. Credenciais úteis (já usadas neste projeto): `ADMIN_TOKEN` local =
   `8f0bc17df7284e76b77500ec0ff7b17e` (idêntico ao do Render — confirmado funcionando);
   PIX_KEY `rickjax123@gmail.com`, PIX_NAME `HENRIQUE DE CARVALHO`, PIX_CITY `RIO DE JANEIRO`.

---

## 7. Regras do repositório (não esquecer)

- Responder em português; ler/atualizar `COORDENACAO-AGENTES.md` antes e depois de cada tarefa.
- Um commit por agente; mensagens em português.
- **Nunca** adicionar botões sem comando real (sem "opções genéricas").
- Sem comentários no código (salvo pedido explícito).
- Rodar `flutter analyze` + `flutter test` antes de concluir qualquer tarefa Flutter.
- Shell é PowerShell 5.1: usar `;` e `if ($?)`, nunca `&&`.
- Evitar edições via regex/PowerShell em arquivos Dart (round-trip corrompe UTF-8 —
  usar a ferramenta de edição; já aconteceu em `features_test.dart`).
