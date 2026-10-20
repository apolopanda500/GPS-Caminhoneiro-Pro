#!/usr/bin/env pwsh
# =============================================================================
# ASSINATURA DE RELEASE + BUILD + INSTALAÇÃO (tudo em um comando)
#
#   pwsh -File tools/preparar-release.ps1
#
# O script:
#   1) pergunta a SENHA do keystore (não fica no histórico, não é gravada);
#   2) cria frontend-flutter/android/key.properties (já ignorado pelo git);
#   3) mostra o SHA-1 e o SHA-256 (para o Google Play e o Google Cloud);
#   4) recompila o APK release COM as chaves (keys.json);
#   5) instala no celular conectado via adb.
#
# Opções:
#   -SomenteAssinatura   não compila nem instala (só cria o key.properties)
#   -NaoInstalar         compila, mas não instala
# =============================================================================
param(
  [switch]$SomenteAssinatura,
  [switch]$NaoInstalar
)

$Erro = $false
$raiz = Split-Path -Parent $PSScriptRoot
$flutter = "C:\Users\Micro\flutter\bin\flutter.bat"
$app = Join-Path $raiz "frontend-flutter\android\app"
$keystore = Join-Path $app "upload-keystore.jks"
$keyProps = Join-Path $app "key.properties"
$front = Join-Path $raiz "frontend-flutter"

function Falha($msg) {
  Write-Host "ERRO: $msg" -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "=== 1/5  Assinatura de release ===" -ForegroundColor Cyan
if (-not (Test-Path $keystore)) { Falha "keystore nao encontrado: $keystore" }

$senha = Read-Host "Senha do keystore ($([IO.Path]::GetFileName($keystore)))" -AsSecureString
$senhaTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($senha))

$saida = & keytool '-J-Duser.language=en' '-J-Duser.country=US' -list -v -keystore $keystore -storepass $senhaTexto 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host $saida -ForegroundColor DarkGray
  Falha "senha incorreta ou keystore invalido"
}

$alias = ($saida | Select-String "Alias name:").ToString() -replace ".*Alias name: ", ""
if ([string]::IsNullOrWhiteSpace($alias)) { $alias = "upload" }
$sha1 = ($saida | Select-String "SHA1:").ToString() -replace ".*SHA1: ", ""
$sha256 = ($saida | Select-String "SHA256:").ToString() -replace ".*SHA256: ", ""
$sha1 = $sha1.Trim()
$sha256 = $sha256.Trim()

Write-Host "    alias  : $alias"
Write-Host "    SHA-1  : $sha1" -ForegroundColor Yellow
Write-Host "    SHA-256: $sha256" -ForegroundColor Yellow

$keyProps | Out-Null
@"
storeFile=upload-keystore.jks
storePassword=$senhaTexto
keyAlias=$alias
keyPassword=$senhaTexto
"@ | Set-Content -Path $keyProps -Encoding utf8
Write-Host "    key.properties criado (nao vai para o git)" -ForegroundColor Green

$ignore = Join-Path $raiz "frontend-flutter\android\.gitignore"
if ((Test-Path $ignore) -and -not (Select-String -Path $ignore -Pattern "key.properties" -Quiet)) {
  Add-Content -Path $ignore "key.properties"
}

# limpa a senha da memoria do processo
$senhaTexto = $null

if ($SomenteAssinatura) {
  Write-Host ""
  Write-Host "Use no Google Play > Gerenciar > credenciais de assinatura:" -ForegroundColor Cyan
  Write-Host "   SHA-1  : $sha1"
  Write-Host "   SHA-256: $sha256"
  exit 0
}

Write-Host ""
Write-Host "=== 2/5  Build do APK release (com as chaves) ===" -ForegroundColor Cyan
Push-Location $front
& $flutter build apk --release --dart-define-from-file=keys.json
$buildOk = ($LASTEXITCODE -eq 0)
Pop-Location
if (-not $buildOk) { Falha "falha no build (veja o log acima)" }

$apk = Join-Path $front "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apk)) { Falha "APK nao encontrado em $apk" }
Write-Host "    APK: $apk" -ForegroundColor Green

if (-not $NaoInstalar) {
  Write-Host ""
  Write-Host "=== 3/5  Instalando no celular ===" -ForegroundColor Cyan
  & adb install -r $apk
  if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Se der conflito de assinatura, o app antigo precisa sair antes:" -ForegroundColor Yellow
    Write-Host "   adb uninstall com.gpscamioneiro.gps_camioneiro_pro" -ForegroundColor Yellow
    Write-Host "   (isso apaga o login salvo no aparelho)" -ForegroundColor Yellow
  }
}

Write-Host ""
Write-Host "=== 4/5  Proximo passo: Google Play ===" -ForegroundColor Cyan
Write-Host "   Play Console > seu app > Teste interno > Gerenciar > credenciais de assinatura:"
Write-Host "   SHA-1  : $sha1"
Write-Host "   SHA-256: $sha256"
Write-Host ""
Write-Host "=== 5/5  Bundle para a Play Store (so quando for publicar) ===" -ForegroundColor Cyan
Write-Host "   cd frontend-flutter; flutter build appbundle --release --dart-define-from-file=keys.json" -ForegroundColor DarkGray
Write-Host ""
Write-Host "TUDO PRONTO." -ForegroundColor Green
