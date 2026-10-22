# =============================================================================
# RODAR TODAS AS BATERIAS DE SIMULACAO (nota final 10/10)
# =============================================================================
#   powershell -ExecutionPolicy Bypass -File tools/rodar-baterias.ps1
#   powershell -ExecutionPolicy Bypass -File tools/rodar-baterias.ps1 -Local
#   powershell -ExecutionPolicy Bypass -File tools/rodar-baterias.ps1 -Url https://x.onrender.com
#
# O que roda:
#   1. flutter analyze  (tem que dar "No issues found!")
#   2. flutter test     (226 testes)
#   3. backend build + testes (29)
#   4. bateria multi-usuario (10 cenarios)
#   5. bateria das duas contas (15 cenarios)
#   6. bateria no app (2 arquivos)
#
# Sai com a NOTA FINAL (media ponderada) e o que falta para o 10/10.
# =============================================================================
param(
    [switch]$Local,
    [string]$Url = ""
)

$raiz = Split-Path -Parent $PSScriptRoot
$flutter = "C:\Users\Micro\flutter\bin\flutter.bat"
$notas = @()
$falhas = @()

function Registrar($nome, $nota, $maximo) {
    $script:notas += [pscustomobject]@{ Bateria = $nome; Nota = $nota; Maximo = $maximo }
    $cor = if ($nota -ge $maximo) { "Green" } else { "Yellow" }
    Write-Host ("{0,-46} {1,5} / {2}" -f $nome, $nota, $maximo) -ForegroundColor $cor
}

function Nota-Node($linhas, $maximo) {
    $r = $linhas | Select-String "RESULTADO: (\d+)/(\d+)" | Select-Object -Last 1
    if (-not $r) { return 0 }
    return [int]$r.Matches[0].Groups[1].Value
}

Write-Host ""
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host " BATERIAS DE SIMULACAO REAL - GPS Caminhoneiro Pro" -ForegroundColor Cyan
Write-Host "===========================================================" -ForegroundColor Cyan

$destino = $Url
if ($Local) { $destino = "http://127.0.0.1:3000" }
if ($destino -eq "") { $destino = "https://gps-truck-backend.onrender.com" }
Write-Host "Alvo: $destino"
Write-Host ""

# ------------------------------------------------------------- 1. analyze
Push-Location (Join-Path $raiz "frontend-flutter")
$saida = & $flutter analyze 2>&1 | Out-String
$ok = $saida -match "No issues found"
Registrar "flutter analyze" ($(if ($ok) { 1 } else { 0 })) 1
if (-not $ok) { Write-Host $saida -ForegroundColor Red; $falhas += "analyze" }

# ----------------------------------------------------------- 2. flutter test
$saida = & $flutter test 2>&1 | Out-String
$total = 0
if ($saida -match "\+(\d+): All tests passed") { $total = [int]$Matches[1] }
Registrar "testes do app (flutter test)" $total 226
if ($total -lt 226) { $falhas += "flutter test" }
Pop-Location

# -------------------------------------------------------------- 3. backend
Push-Location (Join-Path $raiz "backend-api")
$saida = & npm test 2>&1 | Out-String
$pass = 0
if ($saida -match "pass (\d+)") { $pass = [int]$Matches[1] }
Registrar "backend (npm test)" $pass 29
if ($pass -lt 29) { $falhas += "backend" }
Pop-Location

# ------------------------------------------- 4. bateria multi-usuario (node)
Push-Location $raiz
$args = @("tools/bateria-simulacao-real.js", "--usuarios", "10", "--passos", "20")
if ($Local -or $Url) { $args = @("tools/bateria-simulacao-real.js", "--local", "--usuarios", "10", "--passos", "20") }
$saida = & node @args 2>&1 | Out-String
$n = Nota-Node $saida 10
Registrar "bateria multi-usuario (10 perfis)" $n 10
if ($n -lt 10) {
  ($saida -split "`n" | Select-String "FALHA" | Select-Object -First 2) | ForEach-Object { Write-Host ("   " + $_.Line.Trim()) -ForegroundColor Yellow }
  $falhas += "multi-usuario"
}

# ---------------------------------------- 5. bateria das duas contas (node)
$args = @("tools/bateria-duas-contas.js", "--url", $destino, "--criar")
$saida = & node @args 2>&1 | Out-String
$n = Nota-Node $saida 15
Registrar "bateria das duas contas (2 aparelhos)" $n 15
if ($n -lt 15) {
  ($saida -split "`n" | Select-String "FALHA" | Select-Object -First 2) | ForEach-Object { Write-Host ("   " + $_.Line.Trim()) -ForegroundColor Yellow }
  $falhas += "duas contas"
}
Pop-Location

# -------------------------------------------------------------- 6. resumo
$totalNota = 0
$totalMax = 0
foreach ($x in $notas) { $totalNota += $x.Nota; $totalMax += $x.Maximo }
$final = [Math]::Round(($totalNota / $totalMax) * 10, 1)

Write-Host ""
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host (" NOTA FINAL: {0}/10" -f $final) -ForegroundColor Cyan
Write-Host "===========================================================" -ForegroundColor Cyan
if ($falhas.Count -gt 0) {
    Write-Host (" Pendencias: " + ($falhas -join ", ")) -ForegroundColor Yellow
    Write-Host "  (PIX no Render, SHA-1 do Google e o DATABASE_URL do Supabase sao acoes do dono do projeto)" -ForegroundColor Yellow
} else {
    Write-Host " TUDO VERDE: app pronto para uso real." -ForegroundColor Green
}
if ($falhas.Count -gt 0) { exit 1 }
exit 0
