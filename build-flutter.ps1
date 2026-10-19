#!/usr/bin/env pwsh
# ================================================================================
# SCRIPT DE BUILD - GPS Caminhoneiro Pro (Flutter APK Release)
# ================================================================================

$flutterPath = "C:\Users\Micro\gps-camioneiro-pro-completo\frontend-flutter"
$manifestRel = "android\app\src\main\AndroidManifest.xml"
$manifest = Join-Path $flutterPath $manifestRel
$manifestBackup = Join-Path $env:TEMP "AndroidManifest.gps.xml"

Write-Host "Construindo APK Release..." -ForegroundColor Cyan

Set-Location $flutterPath

# Garante que as pastas nativas (gradle, MainActivity, res) existam.
# Preserva o AndroidManifest.xml personalizado (permissões de GPS).
if (Test-Path $manifest) { Copy-Item $manifest $manifestBackup -Force }
Write-Host "Gerando estrutura nativa Android (se necessário)..." -ForegroundColor Yellow
flutter create . --platforms=android --org com.gpscamioneiro --project-name gps_camioneiro_pro
if (Test-Path $manifestBackup) { Copy-Item $manifestBackup $manifest -Force }

Write-Host "Limpando build anterior..." -ForegroundColor Yellow
flutter clean

Write-Host "Baixando dependências..." -ForegroundColor Yellow
flutter pub get

Write-Host "Verificando ambiente..." -ForegroundColor Yellow
flutter doctor

Write-Host "Gerando APK Release (arm64)..." -ForegroundColor Yellow
flutter build apk --release --target-platform android-arm64

if ($LASTEXITCODE -eq 0) {
    Write-Host "APK gerado com sucesso!" -ForegroundColor Green
    Write-Host "Caminho: $flutterPath\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
} else {
    Write-Host "Erro ao gerar APK" -ForegroundColor Red
    exit 1
}
