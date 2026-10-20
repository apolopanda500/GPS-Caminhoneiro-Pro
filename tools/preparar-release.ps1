#!/usr/bin/env pwsh
# =============================================================================
# Prepara a assinatura de RELEASE do app:
#   1) cria android/key.properties (nao vai para o git)
#   2) mostra o SHA-1 e o SHA-256 do certificado (para o Google Cloud/Play)
#
# Uso:  pwsh -File tools/preparar-release.ps1 -SenhaKeystore "SUA_SENHA"
# =============================================================================
param(
  [Parameter(Mandatory = $true)][string]$SenhaKeystore,
  [string]$Alias = "upload",
  [string]$Nome = "gps-camioneiro",
  [string]$ValidadeAnos = "30"
)

$erro = $false
$raiz = Split-Path -Parent $PSScriptRoot
$android = Join-Path $raiz "frontend-flutter\android"
$app = Join-Path $android "app"
$keystore = Join-Path $app "upload-keystore.jks"
$keyProps = Join-Path $app "key.properties"

if (-not (Test-Path $keystore)) {
  Write-Host "Keystore nao encontrado em $keystore" -ForegroundColor Red
  exit 1
}

# 1) Descobre o alias real do keystore
Write-Host ">>> Lendo o keystore..." -ForegroundColor Cyan
$saida = & keytool -list -v -keystore $keystore -storepass $SenhaKeystore 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host "Senha incorreta ou keystore invalido." -ForegroundColor Red
  Write-Host $saida -ForegroundColor DarkGray
  exit 1
}
$aliasReal = ($saida | Select-String "Alias name:").ToString() -replace ".*Alias name: ", ""
if ([string]::IsNullOrWhiteSpace($aliasReal)) { $aliasReal = $Alias }
Write-Host "    Alias encontrado: $aliasReal" -ForegroundColor Green

# 2) SHA-1 / SHA-256 do certificado
$sha1 = ($saida | Select-String "SHA1:").ToString() -replace ".*SHA1: ", ""
$sha256 = ($saida | Select-String "SHA256:" | Select-Object -Skip 1) -replace ".*SHA256: ", ""
Write-Host "    SHA-1  : $sha1" -ForegroundColor Yellow
Write-Host "    SHA-256: $sha256" -ForegroundColor Yellow

# 3) Gera o key.properties (nao comitar: ja esta no .gitignore)
$conteudo = @"
storeFile=upload-keystore.jks
storePassword=$SenhaKeystore
keyAlias=$aliasReal
keyPassword=$SenhaKeystore
"@
Set-Content -Path $keyProps -Value $conteudo -Encoding utf8
Write-Host ">>> key.properties criado em $keyProps" -ForegroundColor Green

# 4) Confere o .gitignore
$ignore = Join-Path $android ".gitignore"
if ((Test-Path $ignore) -and -not (Select-String -Path $ignore -Pattern "key.properties" -Quiet)) {
  Add-Content -Path $ignore -Value "key.properties"
  Write-Host ">>> .gitignore atualizado (key.properties ignorado)" -ForegroundColor Green
}

Write-Host ""
Write-Host "PRONTO. Agora:" -ForegroundColor Cyan
Write-Host " 1) Google Cloud > APIs > credenciais > sua chave do Routes API >"
Write-Host "    Android apps > package com.gpscamioneiro.gps_camioneiro_pro"
Write-Host "    SHA-1: $sha1"
Write-Host " 2) Play Console > app > Gerenciar > credenciais de assinatura:"
Write-Host "    SHA-1: $sha1   SHA-256: $sha256"
Write-Host " 3) Recompile: flutter build apk --release --dart-define-from-file=keys.json"
