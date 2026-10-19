#!/usr/bin/env pwsh
# ================================================================================
# 🚀 SCRIPT DE DEPLOY - GPS Caminhoneiro Pro
# Executa no Windows PowerShell
# ================================================================================

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "🚚 GPS CAMINHONEIRO PRO - SCRIPT DE DEPLOY" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$projectRoot = "C:\Users\Micro\gps-camioneiro-pro-completo"
$backendPath = "$projectRoot\backend-api"
$flutterPath = "$projectRoot\frontend-flutter"

function Test-Command {
    param([string]$Name)
    return (Get-Command $Name -ErrorAction SilentlyContinue) -ne $null
}

Write-Host "`n[1/6] Verificando pré-requisitos..." -ForegroundColor Yellow
$nodeOk = Test-Command "node"
$npmOk = Test-Command "npm"
$flutterOk = Test-Command "flutter"

if ($nodeOk) { Write-Host "   ✅ Node.js: $(node --version)" -ForegroundColor Green } else { Write-Host "   ❌ Node.js não encontrado" -ForegroundColor Red }
if ($npmOk) { Write-Host "   ✅ npm: $(npm --version)" -ForegroundColor Green } else { Write-Host "   ❌ npm não encontrado" -ForegroundColor Red }
if ($flutterOk) { Write-Host "   ✅ Flutter encontrado" -ForegroundColor Green } else { Write-Host "   ⚠️ Flutter não encontrado" -ForegroundColor Yellow }
Write-Host "`n[2/6] Instalando dependências do Backend..." -ForegroundColor Yellow
if (Test-Path "$backendPath\package.json") {
    Set-Location $backendPath
    npm install
    if ($LASTEXITCODE -eq 0) { Write-Host "   ✅ Dependências do backend instaladas" -ForegroundColor Green } else { Write-Host "   ❌ Erro ao instalar backend" -ForegroundColor Red }
} else { Write-Host "   ❌ Pasta backend-api não encontrada" -ForegroundColor Red }

Write-Host "`n[3/6] Compilando Backend TypeScript..." -ForegroundColor Yellow
if (Test-Command "npx") {
    npx tsc
    if ($LASTEXITCODE -eq 0) { Write-Host "   ✅ Backend compilado" -ForegroundColor Green } else { Write-Host "   ❌ Erro no build TS" -ForegroundColor Red }
} else { Write-Host "   ⚠️ npx não disponível" -ForegroundColor Yellow }

Write-Host "`n[4/6] Instalando dependências do Flutter..." -ForegroundColor Yellow
if ($flutterOk) {
    Set-Location $flutterPath
    $manifest = Join-Path $flutterPath "android\app\src\main\AndroidManifest.xml"
    $manifestBackup = Join-Path $env:TEMP "AndroidManifest.gps.xml"
    if (Test-Path $manifest) { Copy-Item $manifest $manifestBackup -Force }
    flutter create . --platforms=android --org com.gpscamioneiro --project-name gps_camioneiro_pro
    if (Test-Path $manifestBackup) { Copy-Item $manifestBackup $manifest -Force }
    flutter pub get
    if ($LASTEXITCODE -eq 0) { Write-Host "   ✅ Dependências Flutter instaladas" -ForegroundColor Green } else { Write-Host "   ❌ Erro no flutter pub get" -ForegroundColor Red }
} else { Write-Host "   ⚠️ Flutter não encontrado" -ForegroundColor Yellow }

Write-Host "`n[5/6] Verificando configuração de ambiente..." -ForegroundColor Yellow
$envFile = "$backendPath\.env"
$envExample = "$backendPath\.env.example"
if (-not (Test-Path $envFile)) {
    if (Test-Path $envExample) {
        Copy-Item $envExample $envFile
        Write-Host "   ⚠️ .env criado a partir do .env.example" -ForegroundColor Yellow
        Write-Host "   📝 EDITE O ARQUIVO .env e preencha DATABASE_URL!" -ForegroundColor Yellow
    } else { Write-Host "   ❌ .env.example não encontrado" -ForegroundColor Red }
} else { Write-Host "   ✅ .env já existe" -ForegroundColor Green }

Write-Host "`n[6/6] Gerando APK de Release..." -ForegroundColor Yellow
if ($flutterOk) {
    Set-Location $flutterPath
    flutter build apk --release --target-platform android-arm64
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ APK gerado!" -ForegroundColor Green
        Write-Host "   📍 $flutterPath\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
    } else { Write-Host "   ❌ Erro ao gerar APK" -ForegroundColor Red }
} else { Write-Host "   ⚠️ Flutter não encontrado" -ForegroundColor Yellow }

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "✅ DEPLOY LOCAL CONCLUÍDO!" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "`n📝 PRÓXIMOS PASSOS MANUAIS:" -ForegroundColor Yellow
Write-Host "   1. Supabase: crie conta e rode setup_postgis.sql"
Write-Host "   2. Render: crie serviço conectando este repositório"
Write-Host "   3. Render: configure DATABASE_URL e JWT_SECRET"
Write-Host "   4. Configure baseUrl/socketUrl em app_constants.dart com a URL da Render"
Write-Host "   5. Instale o APK no Android para testar (mapa OpenStreetMap já funciona)"
