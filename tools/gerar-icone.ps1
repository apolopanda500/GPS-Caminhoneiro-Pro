# =============================================================================
# GERA O ICONE DO APP (preenchido, sem borda branca, estilo Chrome)
# =============================================================================
#   powershell -ExecutionPolicy Bypass -File tools/gerar-icone.ps1
#
# Gera 3 arquivos em frontend-flutter/assets/icons:
#   app_icon.png            -> icone completo (fundo + caminhao), 1024x1024
#   app_icon_background.png  -> camada de fundo (adaptive icon), 1024x1024
#   app_icon_foreground.png  -> camada da frente (adaptive icon), 1024x1024
#
# Regras:
# - O fundo ocupa 100% da tela (sem margem branca).
# - O caminhao fica dentro da area segura do adaptive icon (66/108).
# - A camada da frente tem fundo TRANSPARENTE (so o caminhao).
# =============================================================================
param(
    [string]$Saida = (Join-Path (Split-Path -Parent $PSScriptRoot) "frontend-flutter\assets\icons")
)

Add-Type -AssemblyName System.Drawing

$Lado = 1024
$VermelhoEscuro = [System.Drawing.Color]::FromArgb(255, 92, 0, 0)
$Vermelho = [System.Drawing.Color]::FromArgb(255, 196, 26, 26)
$VermelhoVivo = [System.Drawing.Color]::FromArgb(255, 232, 78, 78)
$Preto = [System.Drawing.Color]::FromArgb(255, 18, 5, 5)
$Transparente = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
$Branco = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)

function Novo-Bitmap {
    param([int]$Lado, [System.Drawing.Color]$Cor)
    $bmp = [System.Drawing.Bitmap]::new($Lado, $Lado, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear($Cor)
    return ,@($bmp, $g)
}

function Desenhar-Fundo {
    param([System.Drawing.Graphics]$g, [int]$Lado)
    $rect = [System.Drawing.Rectangle]::new(0, 0, $Lado, $Lado)
    $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $rect,
        $Vermelho,
        $VermelhoEscuro,
        [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
    )
    $g.FillRectangle($brush, 0, 0, $Lado, $Lado)
    $brush.Dispose()

    # brilho radial (canto superior esquerdo)
    $cx = [int]($Lado * 0.28)
    $cy = [int]($Lado * 0.24)
    $r = [int]($Lado * 0.55)
    $gpath = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $gpath.AddEllipse(($cx - $r), ($cy - $r), ($r * 2), ($r * 2))
    $glow = [System.Drawing.Drawing2D.PathGradientBrush]::new($gpath)
    $glow.CenterColor = [System.Drawing.Color]::FromArgb(120, 255, 150, 150)
    $glow.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 232, 78, 78))
    $g.FillEllipse($glow, ($cx - $r), ($cy - $r), ($r * 2), ($r * 2))
    $glow.Dispose()
    $gpath.Dispose()

    # vinheta (sem faixa branca)
    $vpath = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $vpath.AddRectangle([System.Drawing.Rectangle]::new(0, 0, $Lado, $Lado))
    $vinheta = [System.Drawing.Drawing2D.PathGradientBrush]::new($vpath)
    $vinheta.CenterColor = [System.Drawing.Color]::FromArgb(0, 40, 0, 0)
    $vinheta.SurroundColors = @([System.Drawing.Color]::FromArgb(120, 40, 0, 0))
    $g.FillRectangle($vinheta, 0, 0, $Lado, $Lado)
    $vinheta.Dispose()
    $vpath.Dispose()
}

function Desenhar-Caminhao {
    param([System.Drawing.Graphics]$g, [int]$Lado)

    $cx = $Lado / 2.0
    $cy = $Lado / 2.0
    $s = $Lado / 1024.0 * 1.0

    $roda = [System.Drawing.SolidBrush]::new($Preto)
    $aro = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 226, 226, 226))
    $faixa = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 139, 0, 0))
    $farol = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 255, 238, 160))
    $sombra = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(45, 0, 0, 0))
    $brancoB = [System.Drawing.SolidBrush]::new($Branco)

    # sombra
    $g.FillEllipse($sombra, [float]($cx - 280 * $s), [float]($cy + 148 * $s), [float](560 * $s), [float](70 * $s))

    # reboque
    $x = [float]($cx - 267 * $s)
    $y = [float]($cy - 182 * $s)
    $w = [float](360 * $s)
    $h = [float](300 * $s)
    $g.FillRectangle($brancoB, $x, $y, $w, $h)

    # cabine
    $x = [float]($cx + 93 * $s)
    $y = [float]($cy - 182 * $s)
    $w = [float](175 * $s)
    $h = [float](300 * $s)
    $g.FillRectangle($brancoB, $x, $y, $w, $h)
    $cab = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $cab.AddPolygon([System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new([float]($cx + 93 * $s), [float]($cy - 92 * $s)),
        [System.Drawing.PointF]::new([float]($cx + 163 * $s), [float]($cy - 182 * $s)),
        [System.Drawing.PointF]::new([float]($cx + 268 * $s), [float]($cy - 182 * $s)),
        [System.Drawing.PointF]::new([float]($cx + 268 * $s), [float]($cy + 118 * $s)),
        [System.Drawing.PointF]::new([float]($cx + 93 * $s), [float]($cy + 118 * $s))
    ))
    $g.FillPath($brancoB, $cab)
    $cab.Dispose()

    # janela
    $jan = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $jan.AddPolygon([System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new([float]($cx + 126 * $s), [float]($cy - 84 * $s)),
        [System.Drawing.PointF]::new([float]($cx + 172 * $s), [float]($cy - 152 * $s)),
        [System.Drawing.PointF]::new([float]($cx + 240 * $s), [float]($cy - 152 * $s)),
        [System.Drawing.PointF]::new([float]($cx + 240 * $s), [float]($cy - 84 * $s))
    ))
    $g.FillPath($roda, $jan)
    $jan.Dispose()

    # faixa do reboque
    $g.FillRectangle($faixa, [float]($cx - 237 * $s), [float]($cy - 117 * $s), [float](300 * $s), [float](42 * $s))

    # chassi
    $g.FillRectangle($brancoB, [float]($cx - 267 * $s), [float]($cy + 88 * $s), [float](535 * $s), [float](40 * $s))

    # rodas
    foreach ($c in @(-182.0, 8.0, 188.0)) {
        $g.FillEllipse($roda, [float]($cx + ($c - 62) * $s), [float]($cy + 73 * $s), [float](124 * $s), [float](124 * $s))
        $g.FillEllipse($aro, [float]($cx + ($c - 28) * $s), [float]($cy + 107 * $s), [float](56 * $s), [float](56 * $s))
    }

    # farol
    $g.FillEllipse($farol, [float]($cx + 230 * $s), [float]($cy + 8 * $s), [float](34 * $s), [float](34 * $s))

    $roda.Dispose(); $aro.Dispose(); $faixa.Dispose(); $farol.Dispose(); $sombra.Dispose(); $brancoB.Dispose()
}

if (-not (Test-Path $Saida)) { New-Item -ItemType Directory -Path $Saida | Out-Null }

function Salvar($bmp, $g, $arquivo) {
    $bmp.Save($arquivo, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

$bg = Novo-Bitmap -Lado $Lado -Cor $Transparente
Desenhar-Fundo -g $bg[1] -Lado $Lado
Salvar $bg[0] $bg[1] (Join-Path $Saida "app_icon_background.png")

$fg = Novo-Bitmap -Lado $Lado -Cor $Transparente
Desenhar-Caminhao -g $fg[1] -Lado $Lado
Salvar $fg[0] $fg[1] (Join-Path $Saida "app_icon_foreground.png")

$full = Novo-Bitmap -Lado $Lado -Cor $Transparente
Desenhar-Fundo -g $full[1] -Lado $Lado
Desenhar-Caminhao -g $full[1] -Lado $Lado
Salvar $full[0] $full[1] (Join-Path $Saida "app_icon.png")

Write-Host "Icones gerados em $Saida" -ForegroundColor Green
