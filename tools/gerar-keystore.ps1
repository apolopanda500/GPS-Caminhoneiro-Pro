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
Write-Host "=== 2/5  Senha do keystore (gerada automaticamente) ===" -ForegroundColor Cyan
# Senha forte gerada aqui: voce nao precisa digitar nada, so precisa ANOTAR.
$alfabeto = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#%*'
$rnd = [System.Random]::new()
$senhaTexto = -join (1..24 | ForEach-Object { $alfabeto[$rnd.Next(0, $alfabeto.Length)] })

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Black
Write-Host "   SENHA DO KEYSTORE (anote em um gerenciador de senhas!)" -ForegroundColor Yellow
Write-Host "   $senhaTexto" -ForegroundColor White
Write-Host "  ============================================================" -ForegroundColor Black
Write-Host ""
Write-Host "  Sem essa senha o app nao pode mais ser atualizado na Play Store." -ForegroundColor DarkGray
Write-Host "  Aperte ENTER para continuar (ou Ctrl+C para cancelar)." -ForegroundColor DarkGray
$null = Read-Host

Write-Host ""
Write-Host "=== 3/5  Criando o keystore de release ===" -ForegroundColor Cyan
$argumentos = @(
  "-genkeypair", "-v",
  "-keystore", $keystore,
  "-keyalg", "RSA", "-keysize", "2048",
  "-validity", "10000",
  "-alias", "upload",
  "-storepass", $senhaTexto,
  "-keypass", $senhaTexto,
  "-dname", "CN=GPS Caminhoneiro Pro, OU=GPS Caminhoneiro Pro, O=GPS Caminhoneiro Pro, L=Rio de Janeiro, ST=RJ, C=BR"
)
& keytool @argumentos 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Falha "nao foi possivel criar o keystore" }
Write-Host "    keystore criado: $keystore" -ForegroundColor Green

$saida = & keytool -list -v -keystore $keystore -storepass $senhaTexto 2>&1
$sha1 = ($saida | Select-String "SHA1:").ToString() -replace ".*SHA1: ", ""
# SHA-256: o keytool desta versao do JDK nao imprime a impressao digital,
# entao exportamos o certificado e calculamos o hash do DER.
$certDer = Join-Path $env:TEMP "gps-upload-cert.der"
& keytool -exportcert -keystore $keystore -storepass $senhaTexto -alias upload -file $certDer 2>&1 | Out-Null
$sha256 = ""
if (Test-Path $certDer) {
  $sha256 = (Get-FileHash -Path $certDer -Algorithm SHA256).Hash
  Remove-Item $certDer -Force -ErrorAction SilentlyContinue
}
Write-Host "    SHA-1  : $sha1" -ForegroundColor Yellow
Write-Host "    SHA-256: $sha256" -ForegroundColor Yellow

@"
storeFile=upload-keystore.jks
storePassword=$senhaTexto
keyAlias=upload
keyPassword=$senhaTexto
"@ | Set-Content -Path $keyProps -Encoding utf8
Write-Host "    key.properties criado" -ForegroundColor Green
$senhaTexto = $null

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
