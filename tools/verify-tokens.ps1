# Verifica la capa de tokens de RDM Next.
# Uso: powershell -File tools/verify-tokens.ps1  (desde la raiz rdm-next)
# Criterios M3: ref no se importa desde componentes; sys completo light+dark;
# sin duplicados ni referencias rotas en archivos propios (css/, no vendor/).

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$fail = 0

function Read-Css($path) {
  return [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($path))
}

# 1. Definiciones propias (css/, excluye vendor/) vs usadas
$ownFiles = Get-ChildItem "$root\css" -Recurse -Filter *.css
$defined = @{}
foreach ($f in $ownFiles) {
  $t = Read-Css $f.FullName
  foreach ($m in ([regex]::Matches($t, '(?m)^\s*(--[\w-]+)\s*:'))) {
    $name = $m.Groups[1].Value
    if (-not $defined.ContainsKey($name)) { $defined[$name] = @() }
    $defined[$name] += $f.Name
  }
}

# Definiciones del vendor (solo lectura, para resolver referencias)
$vendorDefs = @{}
foreach ($f in (Get-ChildItem "$root\vendor" -Recurse -Filter *.css)) {
  $t = Read-Css $f.FullName
  foreach ($m in ([regex]::Matches($t, '(?m)^\s*(--[\w-]+)\s*:'))) {
    $vendorDefs[$m.Groups[1].Value] = $true
  }
}

# 2. Referencias rotas en archivos propios
Write-Output "=== Referencias rotas (var() sin definir ni en css/ ni en vendor/) ==="
$broken = 0
foreach ($f in $ownFiles) {
  $t = Read-Css $f.FullName
  $used = [regex]::Matches($t, 'var\((--[\w-]+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
  foreach ($u in $used) {
    if (-not $defined.ContainsKey($u) -and -not $vendorDefs.ContainsKey($u)) {
      Write-Output ("  ROTO " + $f.Name + ": " + $u)
      $broken++
    }
  }
}
if ($broken -eq 0) { Write-Output "  ninguna" } else { $fail++ }

# 3. Duplicados en archivos propios
Write-Output ""
Write-Output "=== Duplicados (mismo token en 2+ archivos propios) ==="
$dups = 0
foreach ($k in $defined.Keys) {
  $files = ($defined[$k] | Sort-Object -Unique)
  if ($files.Count -gt 1) {
    Write-Output ("  DUPLICADO " + $k + " en: " + ($files -join ", "))
    $dups++
  }
}
if ($dups -eq 0) { Write-Output "  ninguno" } else { $fail++ }

# 4. Los 9 roles de superficie con light (:root) y dark (@media)
Write-Output ""
Write-Output "=== 9 roles de superficie (light + dark) ==="
$add = Read-Css "$root\css\md\additions.css"
$roles = @("surface-dim","surface-bright","surface-container-lowest","surface-container-low","surface-container","surface-container-high","surface-container-highest")
$missing = 0
foreach ($r in $roles) {
  $inLight = $add -match ("--md-sys-color-" + [regex]::Escape($r) + "\s*:")
  $darkBlock = ([regex]::Match($add, '(?s)@media[^{]*\{(.*)\}\s*$')).Groups[1].Value
  $inDark = $darkBlock -match ("--md-sys-color-" + [regex]::Escape($r) + "\s*:")
  $ok = $inLight -and $inDark
  if (-not $ok) { $missing++ }
  Write-Output ("  " + $r.PadRight(28) + "light: " + $inLight.ToString().PadRight(5) + " dark: " + $inDark)
}
if ($missing -eq 0) { Write-Output "  --> 7/7 completos" } else { Write-Output ("  --> FALTAN: " + $missing); $fail++ }

# 5. Capas invertidas: comp/, rdm/, primitives/ o demo/ leyendo --md-ref-*
# (prohibido por M3). md/ esta excluido a proposito: sys SI lee ref.
Write-Output ""
Write-Output "=== Fugas de capa (leyendo --md-ref-*) ==="
$leaks = 0
foreach ($f in (Get-ChildItem "$root\css\comp","$root\css\rdm","$root\css\primitives","$root\css\demo" -Filter *.css -ErrorAction SilentlyContinue)) {
  $t = Read-Css $f.FullName
  $n = ([regex]::Matches($t, '--md-ref-[\w-]+')).Count
  if ($n -gt 0) { Write-Output ("  FUGA " + $f.Name + ": " + $n + " lectura(s) de ref"); $leaks++ }
}
if ($leaks -eq 0) { Write-Output "  ninguna" } else { $fail++ }

# 6. Tokens DSP consumidos: -value / -unit / axis-value son ruido de Figma,
# no valores CSS. Ningun archivo propio debe leerlos en un var().
Write-Output ""
Write-Output "=== Tokens DSP consumidos (-value, -unit, axis-value) ==="
$dsp = 0
foreach ($f in $ownFiles) {
  $t = Read-Css $f.FullName
  $hits = [regex]::Matches($t, 'var\(--md-sys-[a-z-]+-(?:value|unit|axis-value)[a-z-]*\)') | ForEach-Object { $_.Groups[0].Value } | Sort-Object -Unique
  foreach ($h in $hits) { Write-Output ("  DSP " + $f.Name + ": " + $h); $dsp++ }
}
if ($dsp -eq 0) { Write-Output "  ninguno" } else { $fail++ }

# 7. Imports que resuelven: cada @import relativo apunta a un archivo que
# existe. Rutas relativas al archivo que importa; se saltan las http(s).
Write-Output ""
Write-Output "=== Imports rotos ==="
$badImp = 0
foreach ($f in $ownFiles) {
  $dir = Split-Path -Parent $f.FullName
  foreach ($m in (Select-String -Path $f.FullName -Pattern '@import url\(([^)]+?)\)')) {
    $target = $m.Matches[0].Groups[1].Value.Trim().Split(' ')[0]
    if ($target -match '^https?://') { continue }
    $full = Join-Path $dir $target
    if (-not (Test-Path $full)) {
      Write-Output ("  ROTO " + $f.Name + " -> " + $target)
      $badImp++
    }
  }
}
if ($badImp -eq 0) { Write-Output "  ninguno" } else { $fail++ }

# 8. Elementos de texto pelados: ningun <p> ni <h1-h6> sin clase en los
# .html. Cada elemento de texto declara su rol tipografico explicito.
Write-Output ""
Write-Output "=== Texto pelado en HTML (<p> o <h1-h6> sin clase) ==="
$bare = 0
foreach ($f in (Get-ChildItem "$root\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $f.FullName
  $np = ([regex]::Matches($t, '<p>')).Count
  $nh = ([regex]::Matches($t, '<h[1-6]>')).Count
  if ($np -gt 0) { Write-Output ("  PELADO " + $f.Name + ": " + $np + " <p>"); $bare += $np }
  if ($nh -gt 0) { Write-Output ("  PELADO " + $f.Name + ": " + $nh + " <h>"); $bare += $nh }
}
if ($bare -eq 0) { Write-Output "  ninguno" } else { $fail++ }

# 9. Fuente conectada: la familia de --md-ref-typeface-plain/-brand
# (valor efectivo tras overrides propios) debe estar cargada via <link>
# en los HTML. Evita repetir el desacople link-vs-token.
Write-Output ""
Write-Output "=== Fuente conectada (token ref vs <link>) ==="
$mj = 0
$ownCss = ""
foreach ($f in $ownFiles) { $ownCss += (Read-Css $f.FullName) + "`n" }
$vendorTypo = Read-Css "$root\vendor\material-tokens\css\typography.css"
$loaded = @()
foreach ($h in (Get-ChildItem "$root\*.html" -ErrorAction SilentlyContinue)) {
  $ht = Read-Css $h.FullName
  foreach ($m in ([regex]::Matches($ht, 'family=([^:&]+)'))) {
    $loaded += ($m.Groups[1].Value -replace '\+', ' ')
  }
}
$loaded = $loaded | Sort-Object -Unique
foreach ($role in @("plain","brand")) {
  $mOwn = [regex]::Match($ownCss, '--md-ref-typeface-' + $role + '\s*:\s*"([^"]+)"')
  if ($mOwn.Success) { $fam = $mOwn.Groups[1].Value }
  else {
    $mVen = [regex]::Match($vendorTypo, '--md-ref-typeface-' + $role + '\s*:\s*([^;]+)')
    $fam = $mVen.Groups[1].Value.Trim()
  }
  if ($loaded -contains $fam) { Write-Output ("  OK   typeface-" + $role + ": " + $fam + " (cargada)") }
  else { Write-Output ("  ROTA typeface-" + $role + ": " + $fam + " (no esta en ningun <link>)"); $mj++ }
}
if ($mj -eq 0) { Write-Output "  --> conectadas" } else { $fail++ }

# 10. Tokens -family consumidos: todos valen 1px o 3px (basura DSP de
# Figma). Ningun archivo propio debe leerlos en un var(). El check 6 ya
# cubre -value/-unit/axis-value; este cierra -family.
Write-Output ""
Write-Output "=== Tokens -family consumidos ==="
$fam = 0
foreach ($f in $ownFiles) {
  $t = Read-Css $f.FullName
  $hits = [regex]::Matches($t, 'var\(--md-sys-[a-z-]+-family[a-z-]*\)') | ForEach-Object { $_.Groups[0].Value } | Sort-Object -Unique
  foreach ($h in $hits) { Write-Output ("  FAMILY " + $f.Name + ": " + $h); $fam++ }
}
if ($fam -eq 0) { Write-Output "  ninguno" } else { $fail++ }

# 11. Niveles sys intactos: --md-sys-elevation-levelN son distancias dp del
# vendor (1px, 3px, 6px, 8px, 12px), no recetas de sombra. Ningun archivo
# propio debe declararlos; las sombras van en --rdm-shadow-*.
Write-Output ""
Write-Output "=== Niveles sys redeclarados ==="
$lvl = 0
foreach ($f in $ownFiles) {
  $t = Read-Css $f.FullName
  $hits = [regex]::Matches($t, '(?<!var\()--md-sys-elevation-level\d\s*:') | ForEach-Object { $_.Groups[0].Value.Trim() } | Sort-Object -Unique
  foreach ($h in $hits) { Write-Output ("  NIVEL " + $f.Name + ": " + $h); $lvl++ }
}
if ($lvl -eq 0) { Write-Output "  ninguno" } else { $fail++ }

# 12. Swatches identicos: 3+ <div> consecutivos con la misma clase no
# demuestran nada (fue el bug de Levels: 6 cajas iguales). Si un valor no
# se dibuja, va en tabla. Umbral 3: 2 identicos pueden ser estados
# legitimos, 3 ya es patron sospechoso.
Write-Output ""
Write-Output "=== Swatches identicos (3+ div consecutivos, misma clase) ==="
$dup = 0
foreach ($f in (Get-ChildItem "$root\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $f.FullName
  $classes = @([regex]::Matches($t, '<div class="([^"]+)">') | ForEach-Object { $_.Groups[1].Value })
  $run = 1
  for ($i = 1; $i -le $classes.Count; $i++) {
    if ($i -lt $classes.Count -and $classes[$i] -eq $classes[$i-1]) { $run++ }
    else {
      if ($run -ge 3) { Write-Output ("  IDENTICOS " + $f.Name + ": " + $run + "x <div class=""" + $classes[$i-1] + """>"); $dup++ }
      $run = 1
    }
  }
}
if ($dup -eq 0) { Write-Output "  ninguno" } else { $fail++ }

Write-Output ""
if ($fail -eq 0) { Write-Output "OK: capa de tokens integra" } else { Write-Output ("FALLA: " + $fail + " chequeo(s)") }
exit $fail
