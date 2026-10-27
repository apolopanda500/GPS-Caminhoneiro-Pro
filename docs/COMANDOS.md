# ⌨️ Comandos Essenciais

## Flutter (PowerShell — frontend-flutter)

```powershell
# Análise estática (deve retornar "No issues found!")
& "C:\Users\Micro\flutter\bin\flutter.bat" analyze

# Rodar todos os testes
& "C:\Users\Micro\flutter\bin\flutter.bat" test

# Build APK debug
& "C:\Users\Micro\flutter\bin\flutter.bat" build apk --debug

# Build APK release
& "C:\Users\Micro\flutter\bin\flutter.bat" build apk --release --target-platform android-arm64

# Instalar APK no dispositivo
adb install -r build\app\outputs\flutter-apk\app-debug.apk

# Listar dispositivos conectados
adb devices

# Flutter doctor
& "C:\Users\Micro\flutter\bin\flutter.bat" doctor
```

## Backend (backend-api)

```bash
cd backend-api
npm install
npm run build
npm start        # ou npm run dev
npm test         # 29/29 testes
```

## Baterias de Simulação (Node.js)

```bash
node tools/bateria-simulacao-real.js          # 10/10 cenários
node tools/bateria-duas-contas.js --criar     # 15/15 cenários
node tools/validar-ambiente.js                # Valida chaves, build, testes, git
node tools/validar-pix.js                     # Valida BR Code PIX + CRC16
node tools/observador-v2x.js --segundos 300   # Observador de rede
```

## Emulador (AVD `teste_apk`)

```powershell
$ne = "C:\Users\Micro\AppData\Local\Android\Sdk\emulator"
Start-Process -FilePath "$ne\emulator.exe" -ArgumentList '-avd','teste_apk','-no-snapshot','-no-audio','-no-boot-anim'
```

## Git Push (com Basic Auth — GCM trava sem isso)

```powershell
$line = Get-Content "$env:USERPROFILE\.git-credentials" -TotalCount 1
$m = [regex]::Match($line, '://([^:]+):([^@]+)@')
$basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($m.Groups[1].Value):$($m.Groups[2].Value)"))
git -c "http.extraHeader=Authorization: Basic $basic" -c credential.helper= push origin main
```

## Regras PowerShell 5.1
- Usar `;` e `if ($?)`, nunca `&&`
- Scripts `.ps1` com emojis precisam ser salvos em UTF-8 com BOM
- Capturar PNG do adb com `cmd /c "... > arquivo"` (redirecionamento do PowerShell corrompe binário)
