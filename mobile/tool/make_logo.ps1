# Génère les images du logo Eza Zozo (même dessin que AppLogo dans mobile/lib/widgets/common.dart) :
#   mobile/assets/images/logo.png             icône carrée (iOS, Android classique)
#   mobile/assets/images/logo_foreground.png  avant-plan de l'icône adaptative Android (fond #2F6BFF)
#   backend/public/logo.png                   badge rond des pages web du serveur
# Windows : powershell -ExecutionPolicy Bypass -File mobile/tool/make_logo.ps1
# puis, dans mobile/ : dart run flutter_launcher_icons
param([string]$Root = (Resolve-Path "$PSScriptRoot\..\..").Path)
Add-Type -AssemblyName System.Drawing

$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile("$Root\mobile\assets\fonts\Poppins-Black.ttf")
$family = $fonts.Families[0]

$blue = [System.Drawing.Color]::FromArgb(255, 0x2F, 0x6B, 0xFF)
$darkBlue = [System.Drawing.Color]::FromArgb(255, 0x1A, 0x47, 0xC7)
$yellow = [System.Drawing.Color]::FromArgb(255, 0xFF, 0xC2, 0x1A)
$ink = [System.Drawing.Color]::FromArgb(255, 0x0F, 0x11, 0x15)
$white = [System.Drawing.Color]::White

# Poisson tourné vers la gauche dans le rectangle (x, y, w, h) : corps jaune, queue en V, œil et ouïe bleus.
function Draw-Fish($g, [float]$x, [float]$y, [float]$w, [float]$h) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p.AddBezier($x, ($y + $h * 0.5), ($x + $w * 0.2), ($y - $h * 0.02), ($x + $w * 0.55), ($y - $h * 0.02), ($x + $w * 0.74), ($y + $h * 0.5))
  $p.AddLine(($x + $w * 0.74), ($y + $h * 0.5), ($x + $w), ($y + $h * 0.08))
  $p.AddLine(($x + $w), ($y + $h * 0.08), ($x + $w * 0.93), ($y + $h * 0.5))
  $p.AddLine(($x + $w * 0.93), ($y + $h * 0.5), ($x + $w), ($y + $h * 0.92))
  $p.AddLine(($x + $w), ($y + $h * 0.92), ($x + $w * 0.74), ($y + $h * 0.5))
  $p.AddBezier(($x + $w * 0.74), ($y + $h * 0.5), ($x + $w * 0.55), ($y + $h * 1.02), ($x + $w * 0.2), ($y + $h * 1.02), $x, ($y + $h * 0.5))
  $p.CloseFigure()
  $g.FillPath((New-Object System.Drawing.SolidBrush($yellow)), $p)
  $r = $h * 0.09
  $g.FillEllipse((New-Object System.Drawing.SolidBrush($darkBlue)), ($x + $w * 0.17 - $r), ($y + $h * 0.42 - $r), (2 * $r), (2 * $r))
  $pen = New-Object System.Drawing.Pen($darkBlue, ($h * 0.07))
  $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  # Ouïe : arc de -0,9 à +0,9 radian (en degrés : -51,6° sur 103,1°).
  $g.DrawArc($pen, ($x + $w * 0.21), ($y + $h * 0.225), ($w * 0.1), ($h * 0.55), [single]-51.6, [single]103.1)
}

# Vague blanche (trois ondulations) dans le rectangle (x, y, w, h).
function Draw-Wave($g, [float]$x, [float]$y, [float]$w, [float]$h, [float]$stroke) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  for ($i = 0; $i -lt 3; $i++) {
    $x0 = $x + $w * $i / 3
    # Quadratiques converties en cubiques : c1 = p0 + 2/3 (q - p0), c2 = p1 + 2/3 (q - p1).
    $mid = $y + $h * 0.5
    $p.AddBezier($x0, $mid, ($x0 + $w / 18), ($mid - $h / 3), ($x0 + $w / 9), ($mid - $h / 3), ($x0 + $w / 6), $mid)
    $p.AddBezier(($x0 + $w / 6), $mid, ($x0 + $w * 2 / 9), ($mid + $h / 3), ($x0 + $w * 5 / 18), ($mid + $h / 3), ($x0 + $w / 3), $mid)
  }
  $pen = New-Object System.Drawing.Pen($white, $stroke)
  $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $g.DrawPath($pen, $p)
}

# Logo complet centré en (cx, cy) ; $u = taille de référence (diamètre du badge).
function Draw-Logo($g, [float]$cx, [float]$cy, [float]$u) {
  $em = $u * 0.24
  $fishW = $u * 0.30; $fishH = $u * 0.14
  Draw-Fish $g ($cx - $fishW / 2) ($cy - $u * 0.34) $fishW $fishH

  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = [System.Drawing.StringAlignment]::Center
  $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
  $yEza = $cy - $u * 0.07
  $yZozo = $cy + $u * 0.14
  $state = $g.Save()
  # Italique : cisaillement horizontal autour du centre du mot.
  $m = New-Object System.Drawing.Drawing2D.Matrix(1, 0, -0.18, 1, (0.18 * ($cy + $u * 0.035)), 0)
  $g.MultiplyTransform($m)
  $p1 = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p1.AddString('Eza', $family, 0, $em, (New-Object System.Drawing.PointF($cx, $yEza)), $fmt)
  $p2 = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p2.AddString('Zozo', $family, 0, $em, (New-Object System.Drawing.PointF($cx, $yZozo)), $fmt)
  $g.FillPath((New-Object System.Drawing.SolidBrush($white)), $p1)
  $shadow = $p2.Clone()
  $shift = New-Object System.Drawing.Drawing2D.Matrix
  $shift.Translate($em * 0.045, $em * 0.065)
  $shadow.Transform($shift)
  $g.FillPath((New-Object System.Drawing.SolidBrush($ink)), $shadow)
  $g.FillPath((New-Object System.Drawing.SolidBrush($yellow)), $p2)
  $g.Restore($state)

  $waveW = $u * 0.40
  Draw-Wave $g ($cx - $waveW / 2) ($cy + $u * 0.27) $waveW ($u * 0.06) ($u * 0.024)
}

function New-Canvas([int]$size) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.Clear([System.Drawing.Color]::Transparent)
  return @($bmp, $g)
}

function New-Gradient($rect) {
  return New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $blue, $darkBlue, [single]45)
}

$S = 1024

# 1) Icône carrée pleine : fond bleu, cercle jaune, logo.
$c = New-Canvas $S; $bmp = $c[0]; $g = $c[1]
$rect = New-Object System.Drawing.RectangleF(0, 0, $S, $S)
$g.FillRectangle((New-Gradient $rect), $rect)
$g.DrawEllipse((New-Object System.Drawing.Pen($yellow, ($S * 0.03))), ($S * 0.09), ($S * 0.09), ($S * 0.82), ($S * 0.82))
Draw-Logo $g ($S / 2) ($S / 2) ($S * 0.82)
$bmp.Save("$Root\mobile\assets\images\logo.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

# 2) Avant-plan de l'icône adaptative (transparent, dans la zone sûre de 66 %).
$c = New-Canvas $S; $bmp = $c[0]; $g = $c[1]
$g.DrawEllipse((New-Object System.Drawing.Pen($yellow, ($S * 0.022))), ($S * 0.2), ($S * 0.2), ($S * 0.6), ($S * 0.6))
Draw-Logo $g ($S / 2) ($S / 2) ($S * 0.6)
$bmp.Save("$Root\mobile\assets\images\logo_foreground.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

# 3) Badge rond (pages web du serveur : paiement, CGU).
$B = 512
$c = New-Canvas $B; $bmp = $c[0]; $g = $c[1]
$border = $B * 0.035
$circle = New-Object System.Drawing.RectangleF(($border / 2), ($border / 2), ($B - $border), ($B - $border))
$g.FillEllipse((New-Gradient $circle), $circle)
$g.DrawEllipse((New-Object System.Drawing.Pen($yellow, $border)), $circle)
Draw-Logo $g ($B / 2) ($B / 2) $B
$bmp.Save("$Root\backend\public\logo.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

Write-Output 'logos ok'
