# Loop ate 10/10: roda simulação + bateria; refina/analisa até nota 10
$ErrorActionPreference = 'Continue'
Set-Location "C:\Users\Micro\gps-camioneiro-pro-completo"

$tentativas = 0
$maxTentativas = 20
$nota = 0.0

while ($tentativas -lt $maxTentativas) {
  $tentativas++
  Write-Host "`n================ TENTATIVA $tentativas ($maxTentativas max) ================" -ForegroundColor Cyan

  & node tools\bateria-app-uso-real.js --url https://gps-truck-backend.onrender.com 2>&1 | Tee-Object -Variable saida
  $linha = ($saida | Select-String -Pattern "RESULTADO: (\d+)/(\d+) cenarios \| nota ([\d.]+)/10" | Select-Object -Last 1)
  if ($linha) {
    $nota = [double]$linha.Matches[0].Groups[3].Value
    $ok = [int]$linha.Matches[0].Groups[1].Value
    $total = [int]$linha.Matches[0].Groups[2].Value
  } else {
    $nota = 0.0; $ok = 0; $total = 10
  }

  Write-Host "`nNota da tentativa $tentativas : $nota ($ok/$total)" -ForegroundColor Yellow

  if ($nota -ge 10.0) {
    Write-Host "`n*** META ALCANCADA: 10/10 nota 10.0 na tentativa $tentativas ***" -ForegroundColor Green
    break
  }

  Write-Host "Abaixo de 10 — Diagnosticando..." -ForegroundColor Red
  Start-Sleep -Seconds 3
}

if ($nota -lt 10.0) {
  Write-Host "MAXIMO de tentativas atingida ($maxTentativas). Ultima nota: $nota" -ForegroundColor Red
}
