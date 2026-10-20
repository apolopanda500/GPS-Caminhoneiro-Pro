#!/usr/bin/env pwsh
# =============================================================================
# GERA O KEYSTORE DE RELEASE (quando a senha antiga se perdeu)
#
#   pwsh -File tools/gerar-keystore.ps1
#
# O script:
#   1) faz backup do keystore antigo (upload-keystore.jks.bak-<data>);
#   2) pede uma SENHA NOVA (digitada de forma oculta) e cria o keystore;
#   3) grava android/key.properties;
#   4) mostra SHA-1 e SHA-256 (para o Google Play);
#   5) recompila o APK com as chaves e instala no celular.
#
# ATENCAO: guarde essa senha em um gerenciador de senhas. Quem perder ela
# precisa gerar outro keystore (e o app nao pode mais atualizar na Play Store).
# =============================================================================
param(
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
Write-Host "=== 1/5  Backup do keystore antigo ===" -ForegroundColor Cyan
if (Test-Path $keystore) {
  $backup = "$keystore.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
  Copy-Item $keystore $backup -Force
  Write-Host "    backup: $backup" -ForegroundColor Green
} else {
  Write-Host "    (nao havia keystore antigo)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=== 2/5  Nova senha do keystore ===" -ForegroundColor Cyan
Write-Host "Escolha uma senha forte e GUARDE-A (gerenciador de senhas)." -ForegroundColor Yellow
$senha = Read-Host "Senha nova (minimo 6 caracteres)" -AsSecureString
$senhaTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($senha))
if ($senhaTexto.Length -lt 6) { Falha "senha muito curta" }

$confirm = Read-Host "Repita a senha" -AsSecureString
$confirmTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirm))
if ($senhaTexto -ne $confirmTexto) { Falha "as senhas nao conferem" }

Write-Host ""
Write-Host "=== 3/5  Criando o keystore de release ===" -ForegroundColor Cyan
$args = @(
  "-genkeypair", "-v",
  "-keystore", $keystore,
  "-keyalg", "RSA", "-keysize", "2048",
  "-validity", "10000",
  "-alias", "upload",
  "-storepass", $senhaTexto,
  "-keypass", $senhaTexto,
  "-dname", "CN=GPS Caminhoneiro Pro, OU=GPS Caminhoneiro Pro, O=GPS Caminhoneiro Pro, L=Rio de Janeiro, ST=RJ, C=BR"
)
$out = & keytool @args 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host $out -ForegroundColor DarkGray
  Falha "nao foi possivel criar o keystore"
}
Write-Host "    keystore criado: $keystore" -ForegroundColor Green

$saida = & keytool -list -v -keystore $keystore -storepass $senhaTexto 2>&1
$sha1 = ($saida | Select-String "SHA1:").ToString() -replace ".*SHA1: ", ""
$sha256 = ($saida | Select-String "SHA256:" | Select-Object -Skip 1) -replace ".*SHA256: ", ""
Write-Host "    SHA-1  : $sha1" -ForegroundColor Yellow
Write-Host "    SHA-256: $sha256" -ForegroundColor Yellow

@"
storeFile=upload-keystore.jks
storePassword=$senhaTexto
keyAlias=upload
keyPassword=$senhaTexto
"@ | Set-Content -Path $keyProps -Encoding utf8
Write-Host "    key.properties criado" -ForegroundColor Green
$senhaTexto = $null; $confirmTexto = $null

Write-Host ""
Write-Host "=== 4/5  Build do APK release (com as chaves) ===" -ForegroundColor Cyan
Push-Location $front
& $flutter build apk --release --dart-define-from-file=keys.json
$buildOk = ($LASTEXITCODE -eq 0)
Pop-Location
if (-not $buildOk) { Falha "falha no build (veja o log acima)" }

$apk = Join-Path $front "build\app\outputs\flutter-apk\app-release.apk"
if (-not $NaoInstalar) {
  Write-Host ""
  Write-Host "=== 5/5  Instalando no celular ===" -ForegroundColor Cyan
  & adb install -r $apk
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Se der conflito de assinatura: adb uninstall com.gpscamioneiro.gps_camioneiro_pro" -ForegroundColor Yellow
  }
}

Write-Host ""
Write-Host "PRONTO. Anote a senha em um gerenciador de senhas." -ForegroundColor Green
Write-Host "Google Play > seu app > Gerenciar > credenciais de assinatura:" -ForegroundColor Cyan
Write-Host "   SHA-1  : $sha1"
Write-Host "   SHA-256: $sha256"
