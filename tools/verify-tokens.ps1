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

# 3. Duplicados en archivos propios: solo tokens namespaced (--md-*, --rdm-*).
# El API sin prefijo (--layer) se declara en cada componente por diseno.
Write-Output ""
Write-Output "=== Duplicados (mismo token en 2+ archivos propios) ==="
$dups = 0
foreach ($k in $defined.Keys) {
  if ($k -notmatch '^--(md|rdm)-') { continue }
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

# 13. Container en paginas: toda pagina .html de raiz usa .rdm-container
# para que ningun showroom vuelva a desparramarse de lado a lado.
Write-Output ""
Write-Output "=== Container en paginas ==="
$noc = 0
foreach ($h in (Get-ChildItem "$root\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  if ($t -notmatch 'rdm-container') { Write-Output ("  SIN CONTAINER " + $h.Name); $noc++ }
}
if ($noc -eq 0) { Write-Output "  todas" } else { $fail++ }

# 14. Opacidades de state limpias: el vendor las trae con ruido binario de
# Figma (0.07999999821186066...). Toda redeclaracion propia debe usar el
# valor exacto de la spec: 0.08, 0.12 o 0.16.
Write-Output ""
Write-Output "=== Opacidades de state ==="
$noi = 0
foreach ($f in $ownFiles) {
  $t = Read-Css $f.FullName
  foreach ($m in ([regex]::Matches($t, '--md-sys-state-(hover|focus|pressed|dragged)-state-layer-opacity\s*:\s*([^;]+);'))) {
    $v = $m.Groups[2].Value.Trim()
    if ($v -notmatch '^0\.(08|12|16)$') { Write-Output ("  RUIDO " + $f.Name + ": " + $m.Groups[1].Value + " = " + $v); $noi++ }
  }
}
if ($noi -eq 0) { Write-Output "  limpias" } else { $fail++ }

# 15. Duraciones literales: todo transition/animation en CSS propio pasa
# por token de motion. El bloque de prefers-reduced-motion se excluye:
# 0.01ms ahi es el patron estandar de accesibilidad, no una duracion.
Write-Output ""
Write-Output "=== Duraciones literales ==="
$lit = 0
foreach ($f in $ownFiles) {
  $t = Read-Css $f.FullName
  $t = [regex]::Replace($t, '@media\s*\(prefers-reduced-motion:\s*reduce\)\s*\{(?:[^{}]|\{[^{}]*\})*\}', '', 'Singleline')
  foreach ($m in ([regex]::Matches($t, '(?i)(transition(-duration|-timing-function|-delay)?|animation-duration)\s*:[^;{}]*?\b\d+(\.\d+)?m?s\b'))) {
    Write-Output ("  LITERAL " + $f.Name + ": " + $m.Groups[0].Value.Trim()); $lit++
  }
}
if ($lit -eq 0) { Write-Output "  ninguna" } else { $fail++ }

# 16. Primitiva de iconos: ningun HTML usa la clase generica de Google
# (.material-symbols-*); todo icono pasa por .rdm-icon.
Write-Output ""
Write-Output "=== Clases genericas de iconos ==="
$gen = 0
foreach ($h in (Get-ChildItem "$root\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  foreach ($m in ([regex]::Matches($t, 'material-symbols-[a-z]+'))) {
    Write-Output ("  GENERICA " + $h.Name + ": " + $m.Groups[0].Value); $gen++
  }
}
if ($gen -eq 0) { Write-Output "  ninguna" } else { $fail++ }

# 17. Espaciado literal en componentes: padding/margin/gap de css/comp/
# pasan por --rdm-space-*. El cero pelado y auto estan permitidos.
Write-Output ""
Write-Output "=== Espaciado literal en componentes ==="
$spl = 0
$compDir = Join-Path $root "css\comp"
if (Test-Path $compDir) {
  foreach ($f in (Get-ChildItem $compDir -Recurse -Filter *.css)) {
    $t = Read-Css $f.FullName
    foreach ($m in ([regex]::Matches($t, '(?i)(padding|margin|gap)(-[a-z]+)?\s*:[^;{}]*?\b\d+(\.\d+)?(px|em|rem)\b'))) {
      Write-Output ("  LITERAL " + $f.Name + ": " + $m.Groups[0].Value.Trim()); $spl++
    }
  }
}
if ($spl -eq 0) { Write-Output "  ninguno" } else { $fail++ }

# 18. Roles con tema: todo --md-sys-color-* propio se declara en light y
# en dark (2+ ocurrencias). Un rol solo en light es un bug de tema.
Write-Output ""
Write-Output "=== Roles con tema ==="
$the = 0
$colorDefs = @{}
foreach ($f in $ownFiles) {
  $t = Read-Css $f.FullName
  foreach ($m in ([regex]::Matches($t, '(?m)^\s*(--md-sys-color-[\w-]+)\s*:'))) {
    $name = $m.Groups[1].Value
    if (-not $colorDefs.ContainsKey($name)) { $colorDefs[$name] = 0 }
    $colorDefs[$name]++
  }
}
foreach ($name in ($colorDefs.Keys | Sort-Object)) {
  if ($colorDefs[$name] -lt 2) { Write-Output ("  SIN DARK " + $name); $the++ }
}
if ($the -eq 0) { Write-Output "  todos con dark" } else { $fail++ }

# 19. Chrome fuera de demo: ningun css/demo/ pinta header/section/main.
# La estructura de pagina la daran los componentes (Card); en demo solo
# viven probes y layout de filas sin fondo.
Write-Output ""
Write-Output "=== Chrome en demo ==="
$chr = 0
foreach ($f in (Get-ChildItem "$root\css\demo" -Filter *.css)) {
  $t = (Read-Css $f.FullName).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  foreach ($m in ([regex]::Matches($t, '([^{}]+)\{([^{}]*)\}'))) {
    $sel = $m.Groups[1].Value
    $body = $m.Groups[2].Value
    if ($sel -match '(^|[\s,>+~])(header|section|main)(?![\w-])' -and $body -match 'background-color\s*:') {
      Write-Output ("  CHROME " + $f.Name + ": " + $sel.Trim()); $chr++
    }
  }
}
if ($chr -eq 0) { Write-Output "  ninguno" } else { $fail++ }

# 20. Showroom por componente: cada css/comp/*.css tiene su <nombre>.html
# en la raiz. Sin pagina, el componente no existe para el proyecto.
Write-Output ""
Write-Output "=== Showroom por componente ==="
$mis = 0
foreach ($f in (Get-ChildItem "$root\css\comp" -Filter *.css -ErrorAction SilentlyContinue)) {
  $html = Join-Path $root ([System.IO.Path]::GetFileNameWithoutExtension($f.Name) + ".html")
  if (-not (Test-Path $html)) { Write-Output ("  SIN SHOWROOM " + $f.Name); $mis++ }
}
if ($mis -eq 0) { Write-Output "  todos" } else { $fail++ }

# 21. Grupo invisible: button-group.css no declara color, fondo, borde
# ni sombra. La spec lo define como container sin propiedades visuales.
Write-Output ""
Write-Output "=== Grupo invisible ==="
$vis = 0
$bg = "$root\css\comp\button-group.css"
if (Test-Path $bg) {
  $t = Read-Css $bg
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  foreach ($m in ([regex]::Matches($t, '(?i)(background-color|box-shadow)\s*:'))) {
    Write-Output ("  VISIBLE " + $m.Groups[1].Value); $vis++
  }
  foreach ($m in ([regex]::Matches($t, '(?i)(?<![\w-])(color|border)\s*:'))) {
    Write-Output ("  VISIBLE " + $m.Groups[1].Value); $vis++
  }
}
if ($vis -eq 0) { Write-Output "  invisible" } else { $fail++ }

# 22. Chrome compartido: toda pagina .html de raiz linkea showroom.css
# Y tiene al menos un <section> (el link sin secciones no aplica nada).
Write-Output ""
Write-Output "=== Chrome compartido ==="
$sho = 0
foreach ($h in (Get-ChildItem "$root\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  if ($t -notmatch 'css/demo/showroom\.css') { Write-Output ("  SIN CHROME " + $h.Name); $sho++ }
  elseif (([regex]::Matches($t, '<section[ >]')).Count -eq 0) { Write-Output ("  SIN SECCION " + $h.Name); $sho++ }
}
if ($sho -eq 0) { Write-Output "  todas" } else { $fail++ }

# 23. Sin divisores ad-hoc: ningun css/demo/ declara border-top.
# Los divisores viven en css/comp/divider.css.
Write-Output ""
Write-Output "=== Divisores ad-hoc ==="
$adh = 0
foreach ($f in (Get-ChildItem "$root\css\demo" -Filter *.css)) {
  $t = (Read-Css $f.FullName).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  if ($t -match '(?i)border-top\s*:') { Write-Output ("  ADHOC " + $f.Name); $adh++ }
}
if ($adh -eq 0) { Write-Output "  ninguno" } else { $fail++ }

# 24. Toggle con contrato: todo .rdm-icon-button--toggle lleva aria-pressed.
# Sin el atributo no hay estado selected; el producto lo alterna con JS.
Write-Output ""
Write-Output "=== Toggle con contrato ==="
$tog = 0
foreach ($h in (Get-ChildItem "$root\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  foreach ($m in ([regex]::Matches($t, '(?i)<button[^>]*>'))) {
    $tag = $m.Groups[0].Value
    if ($tag -match 'rdm-icon-button--toggle' -and $tag -notmatch 'aria-pressed=') {
      Write-Output ("  SIN CONTRATO " + $h.Name + ": " + $tag.Trim().Substring(0, [Math]::Min(70, $tag.Trim().Length))); $tog++
    }
  }
}
if ($tog -eq 0) { Write-Output "  todos" } else { $fail++ }

# 25. Divisores por seccion: <hr class="rdm-divider"> >= secciones - 1.
# La ultima no lleva (no divide nada). divider.html pasa con 3 >= 2.
Write-Output ""
Write-Output "=== Divisores por seccion ==="
$div = 0
foreach ($h in (Get-ChildItem "$root\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  $sec = ([regex]::Matches($t, '<section[ >]')).Count
  $hr = ([regex]::Matches($t, '<hr class="rdm-divider">')).Count
  if ($sec -gt 0 -and $hr -lt ($sec - 1)) { Write-Output ("  FALTAN " + $h.Name + ": " + $sec + " secciones, " + $hr + " divisores"); $div++ }
}
if ($div -eq 0) { Write-Output "  todas" } else { $fail++ }

# 26. Un componente por archivo: la primera clase .rdm-* de cada regla
# pertenece a la familia del archivo (sin el --modificador). Referencias
# cruzadas (.rdm-fab .rdm-icon) no cuentan: solo la primera.
Write-Output ""
Write-Output "=== Un componente por archivo ==="
$mix = 0
foreach ($f in (Get-ChildItem "$root\css\comp" -Filter *.css -ErrorAction SilentlyContinue)) {
  $fam = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
  $t = (Read-Css $f.FullName).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  foreach ($m in ([regex]::Matches($t, '([^{}]+)\{'))) {
    $sel = $m.Groups[1].Value
    foreach ($s in ($sel -split ',')) {
      $c = [regex]::Match($s, '\.rdm-([\w-]+)')
      if ($c.Success) {
        $cls = $c.Groups[1].Value -replace '--.*$', ''
        if ($cls -ne $fam) { Write-Output ("  MEZCLA " + $f.Name + ": ." + $c.Groups[1].Value); $mix++ }
      }
    }
  }
}
if ($mix -eq 0) { Write-Output "  puros" } else { $fail++ }

# 27. Destructive con error: toda regla .rdm-button--destructive solo
# consume tokens de la familia error (error* y on-error*). Un destructive
# en primary es bug.
Write-Output ""
Write-Output "=== Destructive con error ==="
$des = 0
foreach ($f in (Get-ChildItem "$root\css\comp" -Filter *.css -ErrorAction SilentlyContinue)) {
  $t = (Read-Css $f.FullName).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  foreach ($m in ([regex]::Matches($t, '([^{}]*rdm-button--destructive[^{}]*)\{([^{}]*)\}'))) {
    $body = $m.Groups[2].Value
    foreach ($v in ([regex]::Matches($body, 'var\(--md-sys-color-([\w-]+)\)'))) {
      if ($v.Groups[1].Value -notmatch '^(on-)?error') { Write-Output ("  NO-ERROR " + $f.Name + ": " + $v.Groups[1].Value); $des++ }
    }
  }
}
if ($des -eq 0) { Write-Output "  solo error" } else { $fail++ }

Write-Output ""
if ($fail -eq 0) { Write-Output "OK: capa de tokens integra" } else { Write-Output ("FALLA: " + $fail + " chequeo(s)") }
exit $fail
