#!/usr/bin/env pwsh
# ================================================================================
# 🔍 VALIDADOR DE SINTAXE - GPS Caminhoneiro Pro
# Verifica se os arquivos críticos estão íntegros
# ================================================================================

$projectRoot = "C:\Users\Micro\gps-camioneiro-pro-completo"
$arquivos = @(
    "$projectRoot\backend-api\src\server.ts",
    "$projectRoot\backend-api\src\config\security.ts",
    "$projectRoot\backend-api\src\controllers\payment_controller.ts",
    "$projectRoot\backend-api\src\routes\payment.ts",
    "$projectRoot\frontend-flutter\lib\main.dart",
    "$projectRoot\frontend-flutter\lib\views\map\map_screen.dart",
    "$projectRoot\frontend-flutter\lib\views\auth\login_screen.dart",
    "$projectRoot\frontend-flutter\lib\views\history\travel_history_screen.dart",
    "$projectRoot\frontend-flutter\lib\views\contacts\contacts_screen.dart",
    "$projectRoot\frontend-flutter\lib\views\premium\payment_gate.dart",
    "$projectRoot\frontend-flutter\lib\views\settings\hardware_settings_screen.dart",
    "$projectRoot\frontend-flutter\android\app\src\main\AndroidManifest.xml"
)

Write-Host "🔍 Validando integridade dos arquivos..." -ForegroundColor Cyan
$todosOk = $true

foreach ($arquivo in $arquivos) {
    if (Test-Path $arquivo) {
        $tamanho = (Get-Item $arquivo).Length
        $conteudo = Get-Content $arquivo -Raw
        $linhas = ($conteudo -split "`n").Count
        Write-Host "   ✅ $(Split-Path $arquivo -Leaf) ($tamanho bytes, $linhas linhas)" -ForegroundColor Green
    } else {
        Write-Host "   ❌ FALTANDO: $arquivo" -ForegroundColor Red
        $todosOk = $false
    }
}

Write-Host "`n================================================" -ForegroundColor Cyan
if ($todosOk) {
    Write-Host "✅ TODOS OS ARQUIVOS ESTÃO PRESENTES E ÍNTegros!" -ForegroundColor Green
} else {
    Write-Host "⚠️ ALGUNS ARQUIVOS ESTÃO FALTANDO" -ForegroundColor Yellow
}
Write-Host "================================================" -ForegroundColor Cyan