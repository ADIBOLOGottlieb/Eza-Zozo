# Génère les images du logo Eza Zozo à partir du logo du restaurant (mobile/assets/images/logo_source.png) :
#   mobile/assets/images/logo_full.png        logo nettoyé (fond blanc pur), affiché dans l'app par AppLogo
#   mobile/assets/images/logo.png             icône carrée (iOS, Android classique)
#   mobile/assets/images/logo_foreground.png  avant-plan de l'icône adaptative Android (fond blanc)
#   backend/public/logo.png                   logo des pages web du serveur (pastille ronde)
# Windows : powershell -ExecutionPolicy Bypass -File mobile/tool/make_logo.ps1
# puis, dans mobile/ : dart run flutter_launcher_icons
param([string]$Root = (Resolve-Path "$PSScriptRoot\..\..").Path)
Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Bitmap]::FromFile("$Root\mobile\assets\images\logo_source.png")

# 1) Nettoyage : le fond gris très clair (#F3F3F3) devient blanc pur, pour se fondre dans la pastille blanche.
$clean = New-Object System.Drawing.Bitmap($src.Width, $src.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
for ($y = 0; $y -lt $src.Height; $y++) {
  for ($x = 0; $x -lt $src.Width; $x++) {
    $c = $src.GetPixel($x, $y)
    $min = [Math]::Min($c.R, [Math]::Min($c.G, $c.B))
    $max = [Math]::Max($c.R, [Math]::Max($c.G, $c.B))
    if ($min -ge 225 -and ($max - $min) -le 14) { $c = [System.Drawing.Color]::White }
    $clean.SetPixel($x, $y, $c)
  }
}
$src.Dispose()
$clean.Save("$Root\mobile\assets\images\logo_full.png", [System.Drawing.Imaging.ImageFormat]::Png)

# Logo centré dans un carré de côté $size, largeur = $ratio du carré ; $fill = couleur du fond (ou transparent).
function Save-Square([int]$size, [double]$ratio, $fill, [string]$path) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.Clear($fill)
  $w = $size * $ratio
  $h = $w * $clean.Height / $clean.Width
  $g.DrawImage($clean, [single](($size - $w) / 2), [single](($size - $h) / 2), [single]$w, [single]$h)
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}

$white = [System.Drawing.Color]::White
# 2) Icône carrée : fond blanc, logo sur presque toute la largeur.
Save-Square 1024 0.92 $white "$Root\mobile\assets\images\logo.png"
# 3) Icône adaptative : le logo tient dans la zone sûre (cercle de 66 %), fond blanc fourni par Android.
Save-Square 1024 0.62 ([System.Drawing.Color]::Transparent) "$Root\mobile\assets\images\logo_foreground.png"
# 4) Pages web : pastille ronde, le logo rectangulaire tient dans le cercle (largeur ≤ 85 %).
Save-Square 512 0.82 $white "$Root\backend\public\logo.png"

$clean.Dispose()
Write-Output 'logos ok'
