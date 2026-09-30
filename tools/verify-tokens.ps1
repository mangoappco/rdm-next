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

# 1. Definiciones propias (css/, excluye vendor/) vs usadas.
# El bundle es generado, no fuente: fuera (lo custodia el check 69).
$ownFiles = Get-ChildItem "$root\css" -Recurse -Filter *.css | Where-Object { $_.Name -ne 'rdm-next.bundle.css' }
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
foreach ($f in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
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
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
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

# 12. Swatches identicos: 3+ <div> HERMANOS con la misma clase Y el mismo
# contenido no demuestran nada (fue el bug de Levels: 6 cajas iguales).
# Se comparan clase + contenido normalizado entre hijos del mismo padre:
# wrappers estructurales con distinto texto (como .rdm-card-content) no
# forman racha. Umbral 3. Autocerrados <div/> no se apilan.
Write-Output ""
Write-Output "=== Swatches identicos (3+ div hermanos identicos) ==="
$dup = 0
foreach ($f in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $f.FullName
  $toks = @([regex]::Matches($t, '(?i)</?div\b[^>]*>') | ForEach-Object { @{ tag=$_.Groups[0].Value; idx=$_.Index; len=$_.Groups[0].Value.Length; open=($_.Groups[0].Value -notmatch '^</'); self=($_.Groups[0].Value -match '/>$') } })
  $stack = New-Object System.Collections.Generic.List[object]
  $elems = @()
  $nextId = 0
  foreach ($tk in $toks) {
    if ($tk.open -and -not $tk.self) {
      $cm = [regex]::Match($tk.tag, 'class="([^"]*)"')
      $cls = if ($cm.Success) { $cm.Groups[1].Value } else { '' }
      $par = if ($stack.Count -gt 0) { $stack[$stack.Count-1].id } else { -1 }
      $stack.Add(@{ id=$nextId; class=$cls; openEnd=($tk.idx + $tk.len); parent=$par })
      $nextId++
    } elseif (-not $tk.open) {
      if ($stack.Count -eq 0) { continue }
      $node = $stack[$stack.Count-1]
      $stack.RemoveAt($stack.Count-1)
      $elems += @{ class=$node.class; inner=$t.Substring($node.openEnd, $tk.idx - $node.openEnd); parent=$node.parent }
    }
  }
  $byParent = @{}
  foreach ($e in $elems) {
    if (-not $byParent.ContainsKey($e.parent)) { $byParent[$e.parent] = @() }
    $byParent[$e.parent] += $e
  }
  foreach ($par in $byParent.Keys) {
    $kids = $byParent[$par]
    $run = 1
    for ($i = 1; $i -le $kids.Count; $i++) {
      $same = $false
      if ($i -lt $kids.Count) {
        $a = ([regex]::Replace($kids[$i].inner, '\s+', ' ')).Trim()
        $b = ([regex]::Replace($kids[$i-1].inner, '\s+', ' ')).Trim()
        $same = ($kids[$i].class -ceq $kids[$i-1].class) -and ($a -ceq $b)
      }
      if ($same) { $run++ }
      else {
        if ($run -ge 3) { Write-Output ("  IDENTICOS " + $f.Name + ": " + $run + "x <div class=""" + $kids[$i-1].class + """>"); $dup++ }
        $run = 1
      }
    }
  }
}
if ($dup -eq 0) { Write-Output "  ninguno" } else { $fail++ }

# 13. Container en paginas: toda pagina .html de raiz usa .rdm-container
# para que ningun showroom vuelva a desparramarse de lado a lado.
Write-Output ""
Write-Output "=== Container en paginas ==="
$noc = 0
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  if ($t -notmatch 'rdm-container') { Write-Output ("  SIN CONTAINER " + $h.Name); $noc++ }
}
if ($noc -eq 0) { Write-Output "  todas" } else { $fail++ }

# 14. Opacidades de state limpias: el vendor las trae con ruido binario de
# Figma (0.07999999821186066...) y con el 0.12 de M2. Toda redeclaracion
# propia debe usar el valor exacto de la spec: 0.08, 0.10 o 0.16.
Write-Output ""
Write-Output "=== Opacidades de state ==="
$noi = 0
foreach ($f in $ownFiles) {
  $t = Read-Css $f.FullName
  foreach ($m in ([regex]::Matches($t, '--md-sys-state-(hover|focus|pressed|dragged)-state-layer-opacity\s*:\s*([^;]+);'))) {
    $v = $m.Groups[2].Value.Trim()
    if ($v -notmatch '^0\.(08|10|16)$') { Write-Output ("  RUIDO " + $f.Name + ": " + $m.Groups[1].Value + " = " + $v); $noi++ }
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
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  foreach ($m in ([regex]::Matches($t, 'material-symbols-[a-z]+'))) {
    Write-Output ("  GENERICA " + $h.Name + ": " + $m.Groups[0].Value); $gen++
  }
}
if ($gen -eq 0) { Write-Output "  ninguna" } else { $fail++ }

# 17. Espaciado literal en componentes: padding/margin/gap de css/comp/
# pasan por --rdm-measurement-*. El cero pelado y auto estan permitidos.
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
# en views/ (v0.91). Sin pagina, el componente no existe para el proyecto.
Write-Output ""
Write-Output "=== Showroom por componente ==="
$mis = 0
foreach ($f in (Get-ChildItem "$root\css\comp" -Filter *.css -ErrorAction SilentlyContinue)) {
  $html = Join-Path $root ("views\" + [System.IO.Path]::GetFileNameWithoutExtension($f.Name) + ".html")
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
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
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
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
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
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  $sec = ([regex]::Matches($t, '<section[ >]')).Count
  $hr = ([regex]::Matches($t, '<hr class="rdm-divider">')).Count
  if ($sec -gt 0 -and $hr -lt ($sec - 1)) { Write-Output ("  FALTAN " + $h.Name + ": " + $sec + " secciones, " + $hr + " divisores"); $div++ }
}
if ($div -eq 0) { Write-Output "  todas" } else { $fail++ }

# 26. Un componente por archivo: la primera clase .rdm-* de cada regla
# pertenece a la familia del archivo. Elementos con guion simple
# (.rdm-card-content) cuentan como familia; modificadores con doble
# guion (.rdm-card--x) se recortan antes de comparar. Referencias
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
        if ($cls -ne $fam -and $cls -notlike ($fam + '-*')) { Write-Output ("  MEZCLA " + $f.Name + ": ." + $c.Groups[1].Value); $mix++ }
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

# 28. Sin acciones anidadas: una seccion con .rdm-card--interactive no
# contiene <button> ni <a href> (accion sobre superficie accionable es
# HTML invalido y viola la spec).
Write-Output ""
Write-Output "=== Sin acciones anidadas ==="
$nes = 0
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  foreach ($m in ([regex]::Matches($t, '(?s)<section>.*?</section>'))) {
    $sec = $m.Groups[0].Value
    if ($sec -match 'rdm-card--interactive') {
      $sin = [regex]::Replace($sec, '<[^>]*rdm-card--interactive[^>]*>', '')
      if ($sin -match '(<button|<a href)') { Write-Output ("  ANIDADA " + $h.Name); $nes++ }
    }
  }
}
if ($nes -eq 0) { Write-Output "  ninguna" } else { $fail++ }

# 29. Card en bloque: .rdm-card declara display block. Sin esto un <a>
# queda inline y se fragmenta por line box (fondo y radio partidos,
# layer del hover cortado a la mitad).
Write-Output ""
Write-Output "=== Card en bloque ==="
$blk = 0
$cf = "$root\css\comp\card.css"
if (Test-Path $cf) {
  $t = (Read-Css $cf).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  $m = [regex]::Match($t, '(?s)\.rdm-card\s*\{([^{}]*)\}')
  if (-not $m.Success -or $m.Groups[1].Value -notmatch '(?i)display\s*:\s*block') {
    Write-Output "  SIN BLOCK card.css"; $blk++
  }
} else { Write-Output "  SIN ARCHIVO card.css"; $blk++ }
if ($blk -eq 0) { Write-Output "  en bloque" } else { $fail++ }

# 30. Contraste contenido en card: todo boton CON fondo propio dentro de
# una .rdm-card--* da 3:1 (fondo vs fondo) en light y en dark. Los tokens
# se leen del arbol real (palette + themes + additions), no hay valores
# hardcodeados. Scope card: el tonal sobre surface pagina (1.26) es M3
# baseline, no bug nuestro. Disabled se salta (WCAG lo exime).
Write-Output ""
Write-Output "=== Contraste contenido en card ==="
$con = 0
function Get-Decls($txt) {
  $d = @{}
  foreach ($m in ([regex]::Matches($txt, '(?m)^\s*(--[\w-]+)\s*:\s*([^;{}]+);'))) { $d[$m.Groups[1].Value] = $m.Groups[2].Value.Trim() }
  return $d
}
function Resolve-Token($name, $map, $pal) {
  $v = $map[$name]
  if ($null -eq $v) { return $null }
  for ($i = 0; $i -lt 8; $i++) {
    $m = [regex]::Match($v, 'var\((--[\w-]+)\)')
    if (-not $m.Success) { break }
    $k = $m.Groups[1].Value
    if ($pal.ContainsKey($k)) { $nx = $pal[$k] } elseif ($map.ContainsKey($k)) { $nx = $map[$k] } else { return $null }
    $v = $v.Replace($m.Groups[0].Value, $nx)
  }
  return $v.Trim()
}
function Get-Lum($hex) {
  $h = ([regex]::Match($hex, '#([0-9a-fA-F]{6})')).Groups[1].Value
  $c = @([Convert]::ToInt32($h.Substring(0,2),16), [Convert]::ToInt32($h.Substring(2,2),16), [Convert]::ToInt32($h.Substring(4,2),16))
  $l = @()
  foreach ($ch in $c) { $v = $ch / 255; if ($v -le 0.03928) { $l += ($v / 12.92) } else { $l += [Math]::Pow(($v + 0.055) / 1.055, 2.4) } }
  return 0.2126 * $l[0] + 0.7152 * $l[1] + 0.0722 * $l[2]
}
function Get-Ratio($a, $b) {
  $l1 = Get-Lum $a; $l2 = Get-Lum $b
  $hi = [Math]::Max($l1, $l2); $lo = [Math]::Min($l1, $l2)
  return ($hi + 0.05) / ($lo + 0.05)
}
$pal = Get-Decls (Read-Css "$root\vendor\material-tokens\css\palette.css")
$add = Read-Css "$root\css\md\additions.css"
$addLight = Get-Decls $add.Substring($add.IndexOf(":root"), $add.IndexOf("@media") - $add.IndexOf(":root"))
$darkBlock = ([regex]::Match($add, '(?s)@media[^{]*\{(.*)\}\s*$')).Groups[1].Value
$addDark = Get-Decls $darkBlock
$lightMap = Get-Decls (Read-Css "$root\vendor\material-tokens\css\theme\light.css")
foreach ($k in $addLight.Keys) { $lightMap[$k] = $addLight[$k] }
$darkMap = Get-Decls (Read-Css "$root\vendor\material-tokens\css\theme\dark.css")
foreach ($k in $addDark.Keys) { $darkMap[$k] = $addDark[$k] }
$cardBg = @{ "elevated" = "--md-sys-color-surface-container-low"; "filled" = "--md-sys-color-surface-container-highest"; "outlined" = "--md-sys-color-surface" }
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  foreach ($m in ([regex]::Matches($t, '(?s)<(div|a)[^>]*class="[^"]*rdm-card--(elevated|filled|outlined)[^"]*"[^>]*>(.*?)</\1>'))) {
    $cv = $m.Groups[2].Value
    $inner = $m.Groups[3].Value
    foreach ($b in ([regex]::Matches($inner, '(?i)<button[^>]*class="([^"]*)"[^>]*>'))) {
      $tag = $b.Groups[0].Value
      $cls = $b.Groups[1].Value
      if ($tag -match '(?i)\bdisabled\b') { continue }
      $btnBg = $null
      if ($cls -match 'rdm-button--filled') { if ($cls -match 'rdm-button--destructive') { $btnBg = "--md-sys-color-error" } else { $btnBg = "--md-sys-color-primary" } }
      elseif ($cls -match 'rdm-button--tonal') { if ($cls -match 'rdm-button--destructive') { $btnBg = "--md-sys-color-error-container" } else { $btnBg = "--md-sys-color-secondary-container" } }
      elseif ($cls -match 'rdm-button--elevated') { $btnBg = "--md-sys-color-surface-container-low" }
      elseif ($cls -match 'rdm-icon-button--filled') {
        if (($cls -match 'rdm-icon-button--toggle') -and ($tag -notmatch 'aria-pressed="true"')) { $btnBg = "--md-sys-color-surface-container-highest" }
        elseif ($cls -match 'rdm-button--destructive') { $btnBg = "--md-sys-color-error" }
        else { $btnBg = "--md-sys-color-primary" }
      }
      elseif ($cls -match 'rdm-icon-button--tonal') {
        if (($cls -match 'rdm-icon-button--toggle') -and ($tag -notmatch 'aria-pressed="true"')) { $btnBg = "--md-sys-color-surface-container-highest" }
        else { $btnBg = "--md-sys-color-secondary-container" }
      }
      else { continue }
      foreach ($th in @("light", "dark")) {
        if ($th -eq "light") { $map = $lightMap } else { $map = $darkMap }
        $cb = Resolve-Token $cardBg[$cv] $map $pal
        $bb = Resolve-Token $btnBg $map $pal
        if ($null -eq $cb -or $null -eq $bb) { Write-Output ("  SIN-RESOLVER " + $h.Name + " " + $th + ": card=" + $cb + " btn=" + $bb); $con++; continue }
        $r = Get-Ratio $cb $bb
        if ($r -lt 3) { Write-Output ("  BAJO-CONTRASTE " + $h.Name + " " + $th + ": " + $btnBg + " en card--" + $cv + " = " + [Math]::Round($r, 2)); $con++ }
      }
    }
  }
}
if ($con -eq 0) { Write-Output "  3:1 en cards" } else { $fail++ }

# 31. Inline con caja: toda regla inline-flex/inline-block/inline-grid de
# css/comp/ declara vertical-align middle (nunca baseline). La linea base
# deriva hasta 8px con contenido mixto (glifo vs texto, medido en card);
# middle alinea por caja y es inmune al contenido interno.
Write-Output ""
Write-Output "=== Inline con caja ==="
$ali = 0
foreach ($f in (Get-ChildItem "$root\css\comp" -Filter *.css -ErrorAction SilentlyContinue)) {
  $t = (Read-Css $f.FullName).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  foreach ($m in ([regex]::Matches($t, '([^{}]+)\{([^{}]*)\}'))) {
    $body = $m.Groups[2].Value
    if ($body -match '(?i)display\s*:\s*inline-(flex|block|grid)') {
      if (($body -notmatch '(?i)vertical-align\s*:') -or ($body -match '(?i)vertical-align\s*:\s*baseline')) {
        Write-Output ("  SIN-CAJA " + $f.Name + ": " + $m.Groups[1].Value.Trim().Substring(0, [Math]::Min(50, $m.Groups[1].Value.Trim().Length))); $ali++
      }
    }
  }
}
if ($ali -eq 0) { Write-Output "  todos middle" } else { $fail++ }

# 32. Disabled interactivo con contrato: todo .rdm-card--interactive con
# .rdm-card--disabled lleva aria-disabled="true". El atributo disabled
# no existe en <a>; sin el contrato el lector no anuncia el estado.
Write-Output ""
Write-Output "=== Disabled interactivo con contrato ==="
$dic = 0
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  foreach ($m in ([regex]::Matches($t, '(?i)<(div|a)[^>]*>'))) {
    $tag = $m.Groups[0].Value
    if ($tag -match 'rdm-card--interactive' -and $tag -match 'rdm-card--disabled' -and $tag -notmatch 'aria-disabled="true"') {
      Write-Output ("  SIN-CONTRATO " + $h.Name + ": " + $tag.Trim().Substring(0, [Math]::Min(70, $tag.Trim().Length))); $dic++
    }
  }
}
if ($dic -eq 0) { Write-Output "  todos con contrato" } else { $fail++ }

# 33. Base sin estados: una .rdm-card NO interactive no lleva
# .rdm-state-layer (la spec: non-actionable no ripplea ni tiene hover)
# y ninguna regla fuera de --interactive declara cursor pointer
# (not-allowed en disabled no es estado de interaccion).
Write-Output ""
Write-Output "=== Base sin estados ==="
$bes = 0
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  foreach ($m in ([regex]::Matches($t, '(?i)<(div|a)[^>]*>'))) {
    $tag = $m.Groups[0].Value
    if ($tag -match 'rdm-card' -and $tag -notmatch 'rdm-card--interactive' -and $tag -match 'rdm-state-layer') {
      Write-Output ("  CON-LAYER " + $h.Name + ": " + $tag.Trim().Substring(0, [Math]::Min(70, $tag.Trim().Length))); $bes++
    }
  }
}
$cc = "$root\css\comp\card.css"
if (Test-Path $cc) {
  $t = (Read-Css $cc).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  foreach ($m in ([regex]::Matches($t, '([^{}]+)\{([^{}]*)\}'))) {
    if ($m.Groups[2].Value -match '(?i)cursor\s*:\s*pointer' -and $m.Groups[1].Value -notmatch 'rdm-card--interactive') {
      Write-Output ("  CON-CURSOR card.css: " + $m.Groups[1].Value.Trim()); $bes++
    }
  }
}
if ($bes -eq 0) { Write-Output "  base quieta" } else { $fail++ }

# 34. Un solo tab stop: la card NO interactive no lleva tabindex ni
# role (la spec: no es tab stop y no necesita rol; solo sus hijos
# accionables lo son).
Write-Output ""
Write-Output "=== Un solo tab stop ==="
$tbs = 0
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  foreach ($m in ([regex]::Matches($t, '(?i)<(div|a)[^>]*>'))) {
    $tag = $m.Groups[0].Value
    if ($tag -match 'rdm-card' -and $tag -notmatch 'rdm-card--interactive' -and ($tag -match '(?i)\btabindex\b' -or $tag -match '(?i)\brole=')) {
      Write-Output ("  CON-TAB " + $h.Name + ": " + $tag.Trim().Substring(0, [Math]::Min(70, $tag.Trim().Length))); $tbs++
    }
  }
}
if ($tbs -eq 0) { Write-Output "  un tab stop" } else { $fail++ }

# 35. Anillo de foco: la primitiva declara el focus indicator M3 en
# :focus-visible (outline secondary 3px, offset 2px). Los 4 componentes
# lo heredan; sin esta regla el indicador se pierde de un borrado.
Write-Output ""
Write-Output "=== Anillo de foco ==="
$rin = 0
$sl = "$root\css\primitives\state-layer.css"
if (Test-Path $sl) {
  $t = (Read-Css $sl).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  $m = [regex]::Match($t, '(?s)\.rdm-state-layer:focus-visible\s*\{([^{}]*)\}')
  if (-not $m.Success) { Write-Output "  SIN-REGLA state-layer.css"; $rin++ }
  else {
    $body = $m.Groups[1].Value
    if ($body -notmatch '(?i)outline\s*:[^;{}]*var\(--md-sys-color-secondary\)') { Write-Output "  SIN-COLOR state-layer.css"; $rin++ }
    if ($body -notmatch '(?i)outline\s*:[^;{}]*3px') { Write-Output "  SIN-GROSOR state-layer.css"; $rin++ }
    if ($body -notmatch '(?i)outline-offset\s*:\s*2px') { Write-Output "  SIN-OFFSET state-layer.css"; $rin++ }
  }
} else { Write-Output "  SIN-ARCHIVO state-layer.css"; $rin++ }
if ($rin -eq 0) { Write-Output "  anillo presente" } else { $fail++ }

# 36. Shape post-2023: los 3 niveles que el vendor no trae existen en
# css/ propio con su valor exacto (large-increased 20, extra-large-
# increased 32, extra-extra-large 48). Sin esto shape.html muestra 7
# de los 10 niveles de la spec.
Write-Output ""
Write-Output "=== Shape post-2023 ==="
$shp = 0
$ownCss = ""
foreach ($f in $ownFiles) { $ownCss += (Read-Css $f.FullName) + "`n" }
$ownCss = [regex]::Replace($ownCss, '/\*.*?\*/', '', 'Singleline')
foreach ($pair in @("--md-sys-shape-corner-large-increased-default-size:20px", "--md-sys-shape-corner-extra-large-increased-default-size:32px", "--md-sys-shape-corner-extra-extra-large-default-size:48px")) {
  $kv = $pair -split ':'
  $m = [regex]::Match($ownCss, [regex]::Escape($kv[0]) + '\s*:\s*([^;{}]+);')
  if (-not $m.Success) { Write-Output ("  FALTA " + $kv[0]); $shp++ }
  elseif ($m.Groups[1].Value.Trim() -ne $kv[1]) { Write-Output ("  MAL-VALOR " + $kv[0] + " = " + $m.Groups[1].Value.Trim()); $shp++ }
}
if ($shp -eq 0) { Write-Output "  10 niveles" } else { $fail++ }

# 37. Medidas de card: la tabla Specs de card.html lista los 4 valores
# que publica cards/specs (12dp, 16dp, 8dp max, start-aligned). Si M3
# los cambia, este guard lo detecta al actualizar la tabla.
Write-Output ""
Write-Output "=== Medidas de card ==="
$med = 0
$ch = "$root\views\card.html"
if (Test-Path $ch) {
  $t = Read-Css $ch
  foreach ($v in @("12dp", "16dp", "8dp maximo", "start-aligned")) {
    if ($t -notmatch [regex]::Escape($v)) { Write-Output ("  FALTA " + $v); $med++ }
  }
} else { Write-Output "  SIN-SHOWROOM card.html"; $med++ }
if ($med -eq 0) { Write-Output "  4 valores" } else { $fail++ }

# 38. Inset alineado: el inset del divider (middle-inset, ambos lados)
# usa el mismo token que el padding del contenido de card (decision 12;
# el padding vive en content desde la opcion A). Si el padding se mueve,
# el inset lo sigue o falla.
Write-Output ""
Write-Output "=== Inset alineado ==="
$ins = 0
function Strip-Comments($t) { return ([regex]::Replace($t.TrimStart([char]0xFEFF), '/\*.*?\*/', '', 'Singleline')) }
$cb = [regex]::Match((Strip-Comments (Read-Css "$root\css\comp\card.css")), '(?m)^\.rdm-card-content\s*\{([^{}]*)\}')
$ib = [regex]::Match((Strip-Comments (Read-Css "$root\css\comp\divider.css")), '(?m)^\.rdm-divider--middle-inset\s*\{([^{}]*)\}')
if (-not $cb.Success) { Write-Output "  SIN-BASE card.css"; $ins++ }
elseif (-not $ib.Success) { Write-Output "  SIN-INSET divider.css"; $ins++ }
else {
  $p = [regex]::Match($cb.Groups[1].Value, 'padding\s*:\s*var\((--[\w-]+)\)')
  $q = [regex]::Match($ib.Groups[1].Value, 'margin-inline\s*:\s*var\((--[\w-]+)\)')
  if (-not $p.Success) { Write-Output "  SIN-PADDING card.css"; $ins++ }
  elseif (-not $q.Success) { Write-Output "  SIN-MARGEN divider.css"; $ins++ }
  elseif ($p.Groups[1].Value -ne $q.Groups[1].Value) { Write-Output ("  DESALINEADO card=" + $p.Groups[1].Value + " inset=" + $q.Groups[1].Value); $ins++ }
}
if ($ins -eq 0) { Write-Output "  mismo token" } else { $fail++ }

# 39. Container sin padding: la base .rdm-card no declara padding (vive
# en .rdm-card-content, opcion A). Con padding en el container la media
# no puede sangrar al borde y el fallo es silencioso.
Write-Output ""
Write-Output "=== Container sin padding ==="
$pad = 0
$cb2 = [regex]::Match((Strip-Comments (Read-Css "$root\css\comp\card.css")), '(?m)^\.rdm-card\s*\{([^{}]*)\}')
if (-not $cb2.Success) { Write-Output "  SIN-BASE card.css"; $pad++ }
elseif ($cb2.Groups[1].Value -match '(?i)\bpadding\s*:') { Write-Output "  CON-PADDING card.css"; $pad++ }
if ($pad -eq 0) { Write-Output "  sin padding" } else { $fail++ }

# 40. Container que recorta: la base .rdm-card declara overflow hidden.
# El radio solo recorta con overflow; sin esto la media sangra por
# fuera de las esquinas y el fallo es visual, no de token.
Write-Output ""
Write-Output "=== Container que recorta ==="
$clip = 0
$cb3 = [regex]::Match((Strip-Comments (Read-Css "$root\css\comp\card.css")), '(?m)^\.rdm-card\s*\{([^{}]*)\}')
if (-not $cb3.Success) { Write-Output "  SIN-BASE card.css"; $clip++ }
elseif ($cb3.Groups[1].Value -notmatch '(?i)\boverflow\s*:\s*hidden') { Write-Output "  SIN-RECORTE card.css"; $clip++ }
if ($clip -eq 0) { Write-Output "  recorta" } else { $fail++ }

# 41. Elevacion de card: la tabla Elevation de card.html coincide con
# los niveles de material-web (labs/card v0_192 en vendor). Filas en
# orden Elevated, Filled, Outlined; columnas reposo-hover-focus-
# pressed-dragged. Si Google los cambia, la tabla y este guard avisan.
Write-Output ""
Write-Output "=== Elevacion de card ==="
$elv = 0
$mw = @{}
foreach ($v in @("elevated", "filled", "outlined")) {
  $vf = "$root\vendor\material-web-tokens\tokens\versions\v0_192\_md-comp-$v-card.scss"
  if (-not (Test-Path $vf)) { Write-Output ("  SIN-VENDOR " + $v); $elv++; continue }
  $t = Read-Css $vf
  $map = @{}
  foreach ($m in ([regex]::Matches($t, '''(?:(hover|focus|pressed|dragged)-)?container-elevation'':\s*map\.get\(\$deps,\s*''md-sys-elevation'',\s*''(level\d)''\)'))) {
    $st = if ($m.Groups[1].Value -eq '') { 'container' } else { $m.Groups[1].Value }
    $map[$st] = $m.Groups[2].Value
  }
  $mw[$v] = $map
}
$ch = Read-Css "$root\views\card.html"
$et = [regex]::Match($ch, '(?s)<!-- INICIO: card elevation table -->(.*?)<!-- FIN: card elevation table -->')
if (-not $et.Success) { Write-Output "  SIN-TABLA card.html"; $elv++ }
else {
  $rows = @()
  foreach ($rm in ([regex]::Matches($et.Groups[1].Value, '(?s)<tr>(.*?)</tr>'))) {
    $cells = @([regex]::Matches($rm.Groups[1].Value, '<td>(.*?)</td>') | ForEach-Object { $_.Groups[1].Value.Trim() })
    if ($cells.Count -gt 0) { $rows += ,$cells }
  }
  $order = @("container", "hover", "focus", "pressed", "dragged")
  $vars = @("elevated", "filled", "outlined")
  $vnames = @("Elevated", "Filled", "Outlined")
  if ($rows.Count -ne 3) { Write-Output ("  FILAS: " + $rows.Count); $elv++ }
  else {
    for ($i = 0; $i -lt 3; $i++) {
      $cells = $rows[$i]
      if ($cells.Count -ne 6 -or $cells[0] -cne $vnames[$i]) { Write-Output ("  FORMA fila " + $i); $elv++; continue }
      for ($j = 0; $j -lt 5; $j++) {
        $exp = $mw[$vars[$i]][$order[$j]]
        if ($cells[$j + 1] -cne $exp) { Write-Output ("  NIVEL " + $vars[$i] + "/" + $order[$j] + ": tabla=" + $cells[$j + 1] + " vendor=" + $exp); $elv++ }
      }
    }
  }
}
if ($elv -eq 0) { Write-Output "  niveles coinciden" } else { $fail++ }

# 42. Vendor con licencia: todo archivo bajo vendor/ esta cubierto por
# Apache 2.0, por cabecera propia o por LICENSE en su carpeta o
# superiores (decision 4: cada token es demostrablemente de Google).
Write-Output ""
Write-Output "=== Vendor con licencia ==="
$lic = 0
$vroot = Join-Path $root 'vendor'
foreach ($f in (Get-ChildItem $vroot -Recurse -File -ErrorAction SilentlyContinue)) {
  $t = Read-Css $f.FullName
  if ($t -match 'Apache(-| )License|SPDX-License-Identifier:\s*Apache-2\.0') { continue }
  $d = Split-Path -Parent $f.FullName
  $covered = $false
  while ($d.StartsWith($vroot)) {
    if (Test-Path (Join-Path $d 'LICENSE')) { $covered = $true; break }
    $up = Split-Path -Parent $d
    if ($up -eq $d) { break }
    $d = $up
  }
  if (-not $covered) { Write-Output ("  SIN-LICENCIA " + $f.FullName.Substring($vroot.Length + 1)); $lic++ }
}
if ($lic -eq 0) { Write-Output "  todo cubierto" } else { $fail++ }

# 43. Fila de acciones: .demo-card-actions alinea a la derecha con gap
# de token (decision 15). Sin flex-end los botones quedan a la izquierda;
# con gap literal el 8dp no se puede re-tematizar.
Write-Output ""
Write-Output "=== Fila de acciones ==="
$far = 0
$dcf = "$root\css\demo\card.css"
if (Test-Path $dcf) {
  $t = (Read-Css $dcf).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  $m = [regex]::Match($t, '(?m)^\.demo-card-actions\s*\{([^{}]*)\}')
  if (-not $m.Success) { Write-Output "  SIN-FILA demo/card.css"; $far++ }
  else {
    $body = $m.Groups[1].Value
    if ($body -notmatch '(?i)justify-content\s*:\s*flex-end') { Write-Output "  SIN-DERECHA demo/card.css"; $far++ }
    if ($body -notmatch 'gap\s*:\s*var\(--rdm-measurement-100\)') { Write-Output "  SIN-TOKEN demo/card.css"; $far++ }
  }
} else { Write-Output "  SIN-ARCHIVO demo/card.css"; $far++ }
if ($far -eq 0) { Write-Output "  fila a la derecha" } else { $fail++ }

# 44. Sin margenes UA: p, h1-h6, ul y ol llevan margin 0 en base.css.
# El ritmo vertical es 100% de tokens; el UA no gobierna ningun bloque
# de texto del proyecto.
Write-Output ""
Write-Output "=== Sin margenes UA ==="
$mrg = 0
$bb = "$root\css\rdm\base.css"
if (Test-Path $bb) {
  $t = (Read-Css $bb).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  foreach ($el in @("p", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol")) {
    $found = $false
    foreach ($m in ([regex]::Matches($t, '([^{}]+)\{([^{}]*)\}'))) {
      $sel = $m.Groups[1].Value
      $body = $m.Groups[2].Value
      if ($sel -match ('(?i)(^|[\s,])' + $el + '(?![\w-])') -and $body -match '(?i)margin\s*:\s*0') { $found = $true; break }
    }
    if (-not $found) { Write-Output ("  CON-MARGEN " + $el); $mrg++ }
  }
} else { Write-Output "  SIN-ARCHIVO base.css"; $mrg++ }
if ($mrg -eq 0) { Write-Output "  ritmo propio" } else { $fail++ }

# 45. Ritmo con token en demo: ningun css/demo/ usa em en margin* ni
# padding* (escalan con el font-size como el 1em del UA). Todo aire de
# showroom sale de --rdm-measurement-*.
Write-Output ""
Write-Output "=== Ritmo con token en demo ==="
$rem = 0
foreach ($f in (Get-ChildItem "$root\css\demo" -Filter *.css)) {
  $t = (Read-Css $f.FullName).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  foreach ($m in ([regex]::Matches($t, '(?i)(margin|padding)(-[a-z]+)?\s*:[^;{}]*?\b\d+(\.\d+)?em\b'))) {
    Write-Output ("  EM " + $f.Name + ": " + $m.Groups[0].Value.Trim()); $rem++
  }
}
if ($rem -eq 0) { Write-Output "  todo con token" } else { $fail++ }

# 46. Specimens tipograficos agrupados: typography.html enlaza su
# demo/typography.css y cada rol vive en un .demo-type (par nombre +
# spec). Ritmo con gap del padre (v0.63): flex column con gap 8, sin
# reglas en hijos.
Write-Output ""
Write-Output "=== Specimens tipograficos ==="
$typ = 0
$th = "$root\views\typography.html"
$td = "$root\css\demo\typography.css"
if (-not (Test-Path $th)) { Write-Output "  SIN-PAGINA typography.html"; $typ++ }
elseif ((Read-Css $th) -notmatch 'css/demo/typography\.css') { Write-Output "  SIN-LINK typography.html"; $typ++ }
if (-not (Test-Path $td)) { Write-Output "  SIN-DEMO demo/typography.css"; $typ++ }
else {
  $t = (Read-Css $td).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  if ($t -notmatch '(?m)^\.demo-type\s*\{[^}]*display\s*:\s*flex') { Write-Output "  SIN-GAP demo/typography.css"; $typ++ }
  if ($t -notmatch '(?m)^\.demo-type\s*\{[^}]*gap\s*:\s*var\(--rdm-measurement-100\)') { Write-Output "  SIN-PAR demo/typography.css"; $typ++ }
}
if ($typ -eq 0) { Write-Output "  15 roles agrupados" } else { $fail++ }

# 47. Demo CSS por foundation: cada pagina de foundations linkea su
# css/demo/<pagina>.css. layout.html era la segunda sin demo CSS
# (la tabla flotaba sin ritmo y Container no mostraba nada).
# index.html queda fuera (es indice, sin specimens) y las paginas de
# componentes tienen su propio contrato (check 20).
Write-Output ""
Write-Output "=== Demo CSS por foundation ==="
$fdn = 0
foreach ($pg in @("color","divider","elevation","icons","layout","motion","shape","spacing","state-layer","typography")) {
  $h = "$root\views\$pg.html"
  $d = "$root\css\demo\$pg.css"
  if (-not (Test-Path $h)) { Write-Output "  SIN-PAGINA $pg.html"; $fdn++; continue }
  if ((Read-Css $h) -notmatch ('css/demo/' + $pg + '\.css')) { Write-Output "  SIN-LINK $pg.html"; $fdn++ }
  if (-not (Test-Path $d)) { Write-Output "  SIN-DEMO demo/$pg.css"; $fdn++ }
}
if ($fdn -eq 0) { Write-Output "  10 foundations con demo" } else { $fail++ }

# 48. Escala aritmetica: todo --rdm-measurement-NNN declarado en project.css
# cumple valor = 8 x NNN/100 exacto, y estan los 17 (rango 0x a 9x de
# la spec + 4 nested + 150/250 propios). Se parsea el numero, no el
# string: un measurement-275 a 20px falla aunque exista.
Write-Output ""
Write-Output "=== Escala aritmetica ==="
$ari = 0
$pc = "$root\css\rdm\project.css"
if (-not (Test-Path $pc)) { Write-Output "  SIN-ARCHIVO project.css"; $ari++ }
else {
  $t = (Read-Css $pc).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  $decl = @{}
  foreach ($m in ([regex]::Matches($t, '--rdm-measurement-(\d+)\s*:\s*([\d.]+)(px)?'))) {
    $n = [int]$m.Groups[1].Value
    $v = [double]$m.Groups[2].Value
    $decl[$n] = $v
    $esp = 8 * $n / 100
    if ([math]::Abs($v - $esp) -gt 0.001) { Write-Output ("  MAL-CALCULO measurement-" + $n + ": " + $v + "px, debe ser " + $esp); $ari++ }
  }
  foreach ($n in @(0,25,50,75,100,125,150,200,225,250,300,400,500,600,700,800,900)) {
    if (-not $decl.ContainsKey($n)) { Write-Output ("  FALTA measurement-" + $n); $ari++ }
  }
}
if ($ari -eq 0) { Write-Output "  17 tokens exactos" } else { $fail++ }

# 49. Origen distinguido: la tabla de spacing.html marca measurement-150 y
# measurement-250 como extension del proyecto. La spec solo define los
# nested que usa activamente (0.25x, 0.5x, 0.75x, 1.25x); 150 y 250
# salen del multiplicador y lo tienen que decir.
Write-Output ""
Write-Output "=== Origen distinguido ==="
$ori = 0
$sh = "$root\views\spacing.html"
if (-not (Test-Path $sh)) { Write-Output "  SIN-PAGINA spacing.html"; $ori++ }
else {
  $t = Read-Css $sh
  foreach ($n in @(150,250)) {
    $row = [regex]::Match($t, '<tr><td><code>--rdm-measurement-' + $n + '</code></td>.*?</tr>', 'Singleline')
    if (-not $row.Success) { Write-Output ("  SIN-FILA measurement-" + $n); $ori++ }
    elseif ($row.Value -notmatch '(?i)extension del proyecto') { Write-Output ("  SIN-ORIGEN measurement-" + $n); $ori++ }
  }
}
if ($ori -eq 0) { Write-Output "  150 y 250 marcados" } else { $fail++ }

# 50. Reset propio ampliado (v0.55, decision 17): base.css resetea los
# ~20 elementos con defaults del UA vivos (headings sin geometria,
# bloques con margen lateral, listas sin sangrado, tablas planas,
# formularios con font propia, links sin azul). Sin normalize.
Write-Output ""
Write-Output "=== Reset propio ==="
$rst = 0
$bb2 = "$root\css\rdm\base.css"
if (-not (Test-Path $bb2)) { Write-Output "  SIN-ARCHIVO base.css"; $rst++ }
else {
  $t = (Read-Css $bb2).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  $rules = [regex]::Matches($t, '([^{}]+)\{([^{}]*)\}')
  $tiene = {
    param($sel, $prop)
    foreach ($m in $rules) {
      if ($m.Groups[1].Value -match ('(?i)(^|[\s,])' + $sel + '(?![\w-])') -and $m.Groups[2].Value -match ('(?i)' + $prop)) { return $true }
    }
    return $false
  }
  $pares = @(
    @("h1","font-size\s*:\s*inherit"), @("h2","font-size\s*:\s*inherit"),
    @("h3","font-size\s*:\s*inherit"), @("blockquote","margin\s*:\s*0"),
    @("figure","margin\s*:\s*0"), @("pre","margin\s*:\s*0"),
    @("ul","padding-left\s*:\s*0"), @("small","font-size\s*:\s*inherit"),
    @("code","font-family\s*:\s*monospace"),
    @("table","border-collapse\s*:\s*collapse"),
    @("th","text-align\s*:\s*start"), @("td","text-align\s*:\s*start"),
    @("button","font\s*:\s*inherit"), @("input","font\s*:\s*inherit"),
    @("select","font\s*:\s*inherit"), @("textarea","font\s*:\s*inherit"),
    @("a","color\s*:\s*inherit")
  )
  foreach ($p in $pares) {
    if (-not (& $tiene $p[0] $p[1])) { Write-Output ("  SIN-RESET " + $p[0]); $rst++ }
  }
}
if ($rst -eq 0) { Write-Output "  17 elementos reseteados" } else { $fail++ }

# 51. Tablas con patron: toda <table> del showroom lleva demo-table
# (css/demo/table.css). Ninguna depende del default del UA
# (border-spacing 2px, padding 1px, th centrado).
Write-Output ""
Write-Output "=== Tablas con patron ==="
$tab = 0
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  $tot = ([regex]::Matches($t, '<table[ >]')).Count
  $cls = ([regex]::Matches($t, '<table class="demo-table"')).Count
  if ($tot -gt $cls) { Write-Output ("  SIN-CLASE " + $h.Name + ": " + $tot + " tablas, " + $cls + " con clase"); $tab++ }
  if ($t -match 'css/demo/table\.css' -and $tot -eq 0) { Write-Output ("  LINK-SIN-TABLA " + $h.Name); $tab++ }
}
$td2 = "$root\css\demo\table.css"
if (-not (Test-Path $td2)) { Write-Output "  SIN-DEMO demo/table.css"; $tab++ }
else {
  $t = (Read-Css $td2).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  if ($t -notmatch '(?m)^\.demo-table\s*\{[^}]*margin-top\s*:\s*0') { Write-Output "  SIN-RITMO demo/table.css"; $tab++ }
}
if ($tab -eq 0) { Write-Output "  18 tablas con patron" } else { $fail++ }

# 52. Ritmo en cero (v0.56, decision 18; showroom exento desde v0.62):
# ningun css/demo/ salvo showroom.css declara un margin distinto de
# 0. El ritmo de pagina vive en showroom.css y lo custodia el check 62.
Write-Output ""
Write-Output "=== Ritmo en cero ==="
$cer = 0
foreach ($f in (Get-ChildItem "$root\css\demo" -Filter *.css | Where-Object { $_.Name -ne 'showroom.css' })) {
  $t = (Read-Css $f.FullName).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  foreach ($m in ([regex]::Matches($t, '(?i)margin[a-z-]*\s*:\s*([^;{}]+)'))) {
    if ($m.Groups[1].Value.Trim() -ne '0') { Write-Output ("  CON-RITMO " + $f.Name + ": " + $m.Groups[0].Value.Trim()); $cer++ }
  }
}
if ($cer -eq 0) { Write-Output "  18 reglas en cero" } else { $fail++ }

# 53. El divider es el unico que separa: ninguna section lleva margen
# (el gap entre secciones lo da el hr con sus 8/8 del componente).
# Sin esto el 32 de section y el 8 del hr se acumulaban a 41px.
Write-Output ""
Write-Output "=== Divider unico ==="
$dv = 0
$sb = "$root\css\demo\showroom.css"
$t = (Read-Css $sb).TrimStart([char]0xFEFF)
$t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
$m = [regex]::Match($t, '(?m)^\.rdm-container section\s*\{([^}]*)\}')
if (-not $m.Success) { Write-Output "  SIN-REGLA showroom section"; $dv++ }
elseif ($m.Groups[1].Value -match '(?i)margin[a-z-]*\s*:\s*([^;]+)' -and $Matches[1].Trim() -ne '0') { Write-Output "  SECTION-CON-MARGEN"; $dv++ }
$dc = "$root\css\comp\divider.css"
$t = (Read-Css $dc).TrimStart([char]0xFEFF)
$t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
if ($t -notmatch '(?m)^\.rdm-divider\s*\{[^}]*margin-block\s*:\s*var\(--rdm-measurement-100\)') { Write-Output "  HR-SIN-AIRE divider.css"; $dv++ }
if ($dv -eq 0) { Write-Output "  section en 0, hr en 8/8" } else { $fail++ }

# 54. Contrato de spacing (v0.57): ninguna regla de css/comp/ declara
# margin. Spec Do/Don't: el padre declara padding y gaps, los hijos
# nunca llevan margin. divider.css queda fuera: sus margins SON el
# componente (separar es su funcion, auditado en v0.26).
Write-Output ""
Write-Output "=== Contrato de spacing ==="
$con = 0
foreach ($f in (Get-ChildItem "$root\css\comp" -Filter *.css -ErrorAction SilentlyContinue)) {
  if ($f.Name -eq 'divider.css') { continue }
  $t = (Read-Css $f.FullName).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  foreach ($m in ([regex]::Matches($t, '(?m)^[^{}]+\{[^}]*?margin[a-z-]*\s*:\s*[^;]+'))) {
    Write-Output ("  CON-MARGEN " + $f.Name + ": " + $m.Value.Trim().Substring(0, [Math]::Min(70, $m.Value.Trim().Length))); $con++
  }
}
if ($con -eq 0) { Write-Output "  comp sin margin (divider exento)" } else { $fail++ }

# 55. Spacer de layout (v0.57): existe en css/rdm/, usa token en la
# base y modificadores, y rdm-next.css lo importa. En layouts el aire
# es un elemento; en componentes, gap.
Write-Output ""
Write-Output "=== Spacer de layout ==="
$sp = 0
$sf2 = "$root\css\rdm\spacer.css"
if (-not (Test-Path $sf2)) { Write-Output "  SIN-ARCHIVO rdm/spacer.css"; $sp++ }
else {
  $t = (Read-Css $sf2).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  if ($t -notmatch '(?m)^\.rdm-spacer\s*\{[^}]*block-size\s*:\s*var\(--rdm-measurement-400\)') { Write-Output "  SIN-BASE rdm/spacer.css"; $sp++ }
  if ($t -notmatch '(?m)^\.rdm-spacer--600\s*\{[^}]*block-size\s*:\s*var\(--rdm-measurement-600\)') { Write-Output "  SIN-600 rdm/spacer.css"; $sp++ }
  if ($t -notmatch '(?m)^\.rdm-spacer--900\s*\{[^}]*block-size\s*:\s*var\(--rdm-measurement-900\)') { Write-Output "  SIN-900 rdm/spacer.css"; $sp++ }
}
$en = "$root\css\rdm-next.css"
if ((Read-Css $en) -notmatch 'rdm/spacer\.css') { Write-Output "  SIN-IMPORT rdm-next.css"; $sp++ }
if ($sp -eq 0) { Write-Output "  spacer con token e import" } else { $fail++ }

# 56. Breakpoints de la spec (v0.58, mayo 2026): layout.html publica
# los 5 con sus anchos exactos. window size classes es el nombre viejo.
Write-Output ""
Write-Output "=== Breakpoints ==="
$bp = 0
$lh = "$root\views\layout.html"
if (-not (Test-Path $lh)) { Write-Output "  SIN-PAGINA layout.html"; $bp++ }
else {
  $t = Read-Css $lh
  foreach ($n in @("Compact","Medium","Expanded","Large","Extra-large")) {
    if ($t -notmatch ('<td>' + $n + '</td>')) { Write-Output ("  SIN-BREAKPOINT " + $n); $bp++ }
  }
  foreach ($w in @("600","840","1200","1600")) {
    if ($t -notmatch $w) { Write-Output ("  SIN-ANCHO " + $w); $bp++ }
  }
  if ($t -match '<(td|th|h2)>[^<]*window size class') { Write-Output "  NOMBRE-VIEJO layout.html"; $bp++ }
}
if ($bp -eq 0) { Write-Output "  5 breakpoints con anchos" } else { $fail++ }

# 57. Grid de 8 columnas (v0.58): el alt oficial publica 8 con pane
# de 4. El 12 era el grid antiguo: si vuelve, es regresion.
Write-Output ""
Write-Output "=== Grid de 8 ==="
$gr = 0
if (-not (Test-Path $lh)) { Write-Output "  SIN-PAGINA layout.html"; $gr++ }
else {
  $t = Read-Css $lh
  if ($t -notmatch '8 columnas') { Write-Output "  SIN-GRID layout.html"; $gr++ }
  if ($t -match '12 columnas') { Write-Output "  GRID-VIEJO layout.html"; $gr++ }
}
if ($gr -eq 0) { Write-Output "  8 columnas, sin 12" } else { $fail++ }

# 58. Max-width en piso publicado (v0.58, revisado v0.74): el valor es
# decision del proyecto pero debe ser un limite inferior de breakpoint
# M3 (600 medium, 840 expanded), nunca un numero arbitrario. El 1200
# caia justo en Large.
Write-Output ""
Write-Output "=== Max-width en piso publicado ==="
$mw = 0
$pc2 = "$root\css\rdm\project.css"
if (-not (Test-Path $pc2)) { Write-Output "  SIN-ARCHIVO project.css"; $mw++ }
else {
  $t = (Read-Css $pc2).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  $m = [regex]::Match($t, '--rdm-layout-max-width\s*:\s*([\d.]+)px')
  if (-not $m.Success) { Write-Output "  SIN-TOKEN max-width"; $mw++ }
  elseif ($m.Groups[1].Value -ne '600' -and $m.Groups[1].Value -ne '840') { Write-Output ("  PISO-INVALIDO " + $m.Groups[1].Value + "px (solo 600 o 840)"); $mw++ }
}
if ($mw -eq 0) { Write-Output "  max-width en piso publicado" } else { $fail++ }

# 59. Tablas con ejemplo (v0.59, decision 21): toda seccion de un
# showroom de componente con <table> tiene >=1 specimen del propio
# componente. Las medidas se muestran, no solo se listan.
Write-Output ""
Write-Output "=== Tablas con ejemplo ==="
$ej = 0
$comps = @(@("button","rdm-button"), @("card","rdm-card"), @("fab","rdm-fab"), @("extended-fab","rdm-extended-fab"), @("icon-button","rdm-icon-button"), @("button-group","rdm-button-group"))
foreach ($c in $comps) {
  $h = "$root\" + $c[0] + ".html"
  if (-not (Test-Path $h)) { continue }
  $t = Read-Css $h
  foreach ($s in ([regex]::Matches($t, '<section[^>]*>(.*?)</section>', 'Singleline'))) {
    $b = $s.Groups[1].Value
    if ($b -match '<table[ >]' -and $b -notmatch ('class="[^"]*' + $c[1] + '[\s"]')) { Write-Output ("  SIN-SPECIMEN " + $c[0] + ".html"); $ej++; break }
  }
}
if ($ej -eq 0) { Write-Output "  tablas con ejemplo" } else { $fail++ }

# 60. Anatomy con specimen (v0.60, decision 22): toda seccion Anatomy
# de un showroom de componente tiene >=1 specimen del propio
# componente. La anatomia se muestra compuesta, no se narra.
Write-Output ""
Write-Output "=== Anatomy con specimen ==="
$an = 0
$comps2 = @(@("button","rdm-button"), @("card","rdm-card"), @("fab","rdm-fab"), @("extended-fab","rdm-extended-fab"), @("icon-button","rdm-icon-button"))
foreach ($c in $comps2) {
  $h = "$root\" + $c[0] + ".html"
  if (-not (Test-Path $h)) { continue }
  $t = Read-Css $h
  $m = [regex]::Match($t, '<h2 class="rdm-typography--title-large">Anatomy</h2>(.*?)</section>', 'Singleline')
  if (-not $m.Success) { Write-Output ("  SIN-SECCION " + $c[0] + ".html"); $an++; continue }
  if ($m.Groups[1].Value -notmatch ('class="[^"]*' + $c[1] + '[\s"]')) { Write-Output ("  SIN-SPECIMEN " + $c[0] + ".html"); $an++ }
}
if ($an -eq 0) { Write-Output "  5 anatomias visuales" } else { $fail++ }

# 61. Container del menu (v0.61, paso 1): min 112, max 280, radio
# extra-small, fondo surface-container, sombra level2, padding-block
# con token. Medidas de la tabla baseline de la spec.
Write-Output ""
Write-Output "=== Container del menu ==="
$mc = 0
$mf = "$root\css\comp\menu.css"
if (-not (Test-Path $mf)) { Write-Output "  SIN-ARCHIVO comp/menu.css"; $mc++ }
else {
  $t = (Read-Css $mf).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  $m = [regex]::Match($t, '(?m)^\.rdm-menu\s*\{([^}]*)\}')
  if (-not $m.Success) { Write-Output "  SIN-BASE comp/menu.css"; $mc++ }
  else {
    $b = $m.Groups[1].Value
    $pares61 = @(
      @("min-width\s*:\s*7rem","SIN-MIN"), @("max-width\s*:\s*17\.5rem","SIN-MAX"),
      @("border-radius\s*:\s*var\(--md-sys-shape-corner-extra-small-default-size\)","SIN-RADIO"),
      @("background-color\s*:\s*var\(--md-sys-color-surface-container\)","SIN-FONDO"),
      @("box-shadow\s*:\s*var\(--rdm-shadow-level2\)","SIN-SOMBRA"),
      @("padding-block\s*:\s*var\(--rdm-measurement-100\)","SIN-PADDING")
    )
    foreach ($p in $pares61) {
      if ($b -notmatch ('(?i)' + $p[0])) { Write-Output ("  " + $p[1] + " comp/menu.css"); $mc++ }
    }
  }
}
if ($mc -eq 0) { Write-Output "  container con medidas" } else { $fail++ }

# 62. Ritmo con token (v0.62, decision 24): toda declaracion
# margin/padding en showroom.css usa var(--rdm-measurement-*).
# Sin literales: lo que impide volver a la acumulacion de v0.56.
Write-Output ""
Write-Output "=== Ritmo con token ==="
$rit = 0
$t = (Read-Css "$root\css\demo\showroom.css").TrimStart([char]0xFEFF)
$t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
foreach ($m in ([regex]::Matches($t, '(?i)(margin|padding)[a-z-]*\s*:\s*([^;{}]+)'))) {
  $v = $m.Groups[2].Value.Trim()
  if ($v -ne '0' -and $v -notmatch 'var\(--rdm-measurement-') { Write-Output ("  LITERAL " + $m.Groups[0].Value.Trim()); $rit++ }
}
foreach ($sel in @('demo-showroom-bar', 'demo-showroom-intro')) {
  if ($t -notmatch ('(?m)\.' + $sel + '\s*\{')) { Write-Output ("  SIN-REGLA " + $sel); $rit++ }
}
if ($rit -eq 0) { Write-Output "  ritmo con token" } else { $fail++ }

# 63. Estructura (v0.62, decision 24): 1 barra y 1 intro por pagina,
# h1 dentro de main y fuera de la barra.
Write-Output ""
Write-Output "=== Estructura ==="
$est = 0
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  $bar = ([regex]::Matches($t, '<header class="demo-showroom-bar">')).Count
  $intro = ([regex]::Matches($t, '<header class="demo-showroom-intro">')).Count
  if ($bar -ne 1) { Write-Output ("  SIN-BARRA " + $h.Name); $est++ }
  if ($intro -ne 1) { Write-Output ("  SIN-INTRO " + $h.Name); $est++ }
  $iMain = $t.IndexOf('<main>')
  $iH1 = $t.IndexOf('<h1')
  if ($iH1 -lt 0 -or $iH1 -lt $iMain) { Write-Output ("  H1-FUERA-MAIN " + $h.Name); $est++ }
  $m = [regex]::Match($t, '<header class="demo-showroom-bar">(.*?)</header>', 'Singleline')
  if ($m.Success -and $m.Groups[1].Value -match '<h1') { Write-Output ("  H1-EN-BARRA " + $h.Name); $est++ }
}
if ($est -eq 0) { Write-Output "  18 paginas con barra e intro" } else { $fail++ }

# 64. El padre declara (v0.63, decision 25): section e intro con flex
# + gap con token; ningun selector hijo declara margin. Do/Don't de
# M3: el padre organiza, los hijos no llevan margin.
Write-Output ""
Write-Output "=== El padre declara ==="
$pad = 0
$t = (Read-Css "$root\css\demo\showroom.css").TrimStart([char]0xFEFF)
$t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
$m = [regex]::Match($t, '(?m)^\.rdm-container section\s*\{([^}]*)\}')
if (-not $m.Success -or $m.Groups[1].Value -notmatch '(?i)display\s*:\s*flex' -or $m.Groups[1].Value -notmatch 'gap\s*:\s*var\(--rdm-measurement-200\)') { Write-Output "  SIN-GAP section"; $pad++ }
$m = [regex]::Match($t, '(?m)^\.demo-showroom-intro\s*\{([^}]*)\}')
if (-not $m.Success -or $m.Groups[1].Value -notmatch '(?i)display\s*:\s*flex' -or $m.Groups[1].Value -notmatch 'gap\s*:\s*var\(--rdm-measurement-100\)') { Write-Output "  SIN-GAP intro"; $pad++ }
foreach ($son in @('section\s*>\s*h2\s*\{', 'section\s*>\s*p\b', 'demo-showroom-intro\s*>\s*\*')) {
  if ($t -match ('(?m)' + $son)) { Write-Output ("  HIJO-CON-REGLA showroom " + $son); $pad++ }
}
foreach ($f in (Get-ChildItem "$root\css\demo" -Filter *.css)) {
  $t = (Read-Css $f.FullName).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  foreach ($son in @('demo-type\s*>\s*p\b', 'demo-card-spacing\s*>\s*\*')) {
    if ($t -match ('(?m)' + $son)) { Write-Output ("  HIJO-CON-REGLA " + $f.Name + " " + $son); $pad++ }
  }
}
if ($pad -eq 0) { Write-Output "  padres con gap, hijos sin reglas" } else { $fail++ }

# 65. Medidas del divider (v0.64): inset 16/0, middle 16/16, thickness
# 1px, color outline-variant, block 8. Tabla de la spec; el 4dp y el
# right-8 son contexto de Lists y no van en la base.
Write-Output ""
Write-Output "=== Medidas del divider ==="
$dv2 = 0
$df = "$root\css\comp\divider.css"
if (-not (Test-Path $df)) { Write-Output "  SIN-ARCHIVO comp/divider.css"; $dv2++ }
else {
  $t = (Read-Css $df).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  $regla = {
    param($sel, $prop)
    $m = [regex]::Match($t, ('(?m)^' + $sel + '\s*\{([^}]*)\}'))
    if (-not $m.Success) { return $false }
    return ($m.Groups[1].Value -match ('(?i)' + $prop))
  }
  $pares65 = @(
    @("\.rdm-divider","block-size\s*:\s*1px","SIN-GROSOR"),
    @("\.rdm-divider","background-color\s*:\s*var\(--md-sys-color-outline-variant\)","SIN-COLOR"),
    @("\.rdm-divider","margin-block\s*:\s*var\(--rdm-measurement-100\)","SIN-BLOCK"),
    @("\.rdm-divider--inset","margin-inline-start\s*:\s*var\(--rdm-measurement-200\)","SIN-INSET"),
    @("\.rdm-divider--middle-inset","margin-inline\s*:\s*var\(--rdm-measurement-200\)","SIN-MIDDLE"),
    @("\.rdm-divider--vertical","inline-size\s*:\s*1px","SIN-VERTICAL")
  )
  foreach ($p in $pares65) {
    if (-not (& $regla $p[0] $p[1])) { Write-Output ("  " + $p[2] + " comp/divider.css"); $dv2++ }
  }
  $mbase = [regex]::Match($t, '(?m)^\.rdm-divider\s*\{([^}]*)\}')
  if ($mbase.Success -and ($mbase.Groups[1].Value -match '(?i)inline-size')) { Write-Output "  ANCHO-FIJO comp/divider.css (100% + margin = overflow)"; $dv2++ }
}
if ($dv2 -eq 0) { Write-Output "  divider con medidas" } else { $fail++ }

# 66. Aire entre secciones (v0.65, decision 27): los hr hijos directos
# de main llevan aire de layout; los specimens dentro de secciones y
# del nav quedan fuera. El 8/8 del componente no se toca.
Write-Output ""
Write-Output "=== Aire entre secciones ==="
$ai = 0
$t = (Read-Css "$root\css\demo\showroom.css").TrimStart([char]0xFEFF)
$t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
if ($t -notmatch '(?m)^main\s*>\s*hr\.rdm-divider\s*\{[^}]*margin-block\s*:\s*var\(--rdm-measurement-200\)') { Write-Output "  SIN-AIRE showroom.css"; $ai++ }
if ($ai -eq 0) { Write-Output "  separadores con aire de layout" } else { $fail++ }

# 67. Menu item (v0.67): 56 una linea, 72 dos lineas, padding 12/16,
# gap 16, fondo transparent, selected con secondary-container.
# Geometria del vendor (list-item renombrado); el 12 va en
# measurement-150 (extension del proyecto, marcada en la tabla).
Write-Output ""
Write-Output "=== Menu item ==="
$mi = 0
$mf = "$root\css\comp\menu.css"
if (-not (Test-Path $mf)) { Write-Output "  SIN-ARCHIVO comp/menu.css"; $mi++ }
else {
  $t = (Read-Css $mf).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  $regla = {
    param($sel, $prop)
    $m = [regex]::Match($t, ('(?m)^' + $sel + '\s*\{([^}]*)\}'))
    if (-not $m.Success) { return $false }
    return ($m.Groups[1].Value -match ('(?i)' + $prop))
  }
  $pares67 = @(
    @("\.rdm-menu-item","min-block-size\s*:\s*var\(--rdm-measurement-700\)","SIN-ALTURA"),
    @("\.rdm-menu-item","padding-block\s*:\s*var\(--rdm-measurement-150\)","SIN-PAD-V"),
    @("\.rdm-menu-item","padding-inline\s*:\s*var\(--rdm-measurement-200\)","SIN-PAD-L"),
    @("\.rdm-menu-item","gap\s*:\s*var\(--rdm-measurement-200\)","SIN-GAP"),
    @("\.rdm-menu-item","background-color\s*:\s*transparent","SIN-FONDO"),
    @("\.rdm-menu-item","color\s*:\s*var\(--md-sys-color-on-surface\)","SIN-COLOR"),
    @("\.rdm-menu-item--two-line","min-block-size\s*:\s*var\(--rdm-measurement-900\)","SIN-DOS"),
    @("\.rdm-menu-item--selected","background-color\s*:\s*var\(--md-sys-color-secondary-container\)","SIN-SEL")
  )
  foreach ($p in $pares67) {
    if (-not (& $regla $p[0] $p[1])) { Write-Output ("  " + $p[2] + " comp/menu.css"); $mi++ }
  }
}
if ($mi -eq 0) { Write-Output "  item con medidas" } else { $fail++ }

# 68. Medidas sin auditoria (v0.68, decision 30): ninguna tabla con
# encabezado Medida/Valor declara columna Estado (el ruido de los
# coincide vive en SKILL 11). Card exenta: ahi Estado es permitido o
# prohibido por fila (dato de consumo); state-layer exenta: ahi Estado
# es el nombre del estado.
Write-Output ""
Write-Output "=== Medidas sin auditoria ==="
$au = 0
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  $m = [regex]::Match($t, '(?s)<th>Medida</th>\s*<th>Valor</th>\s*<th>Estado</th>')
  if ($m.Success) { Write-Output ("  CON-ESTADO " + $h.Name); $au++ }
}
if ($au -eq 0) { Write-Output "  medidas sin auditoria" } else { $fail++ }

# 69. Bundle servido (v0.70, decision 32): las paginas linkean el bundle
# con ?v= maxima de SKILL; el bundle trae cada comp vigente (si tocas
# CSS sin regenerar, falla).
Write-Output ""
Write-Output "=== Bundle servido ==="
$bu = 0
$bff = "$root\css\rdm-next.bundle.css"
if (-not (Test-Path $bff)) { Write-Output "  SIN-BUNDLE css/rdm-next.bundle.css"; $bu++ }
else {
  $bb = Read-Css $bff
  foreach ($c in (Get-ChildItem "$root\css\comp" -Filter *.css -ErrorAction SilentlyContinue)) {
    if ($bb -notmatch [regex]::Escape($c.Name)) { Write-Output ("  SIN-" + $c.BaseName.ToUpper() + " en bundle"); $bu++ }
  }
  $skb = Read-Css "$root\SKILL.md"
  $mx = 0; $vv = ''
  foreach ($m in [regex]::Matches($skb, '- \*\*v(\d+)\.(\d+)\*\*')) {
    $v = [int]$m.Groups[1].Value * 1000 + [int]$m.Groups[2].Value
    if ($v -gt $mx) { $mx = $v; $vv = $m.Groups[1].Value + '.' + $m.Groups[2].Value }
  }
  foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
    $t = Read-Css $h.FullName
    $mh = [regex]::Match($t, 'rdm-next\.bundle\.css\?v=([\d.]+)')
    if (-not $mh.Success) { Write-Output ("  SIN-BUNDLE-LINK " + $h.Name); $bu++ }
    elseif ($mh.Groups[1].Value -ne $vv) { Write-Output ("  VIEJO " + $h.Name + " (v" + $mh.Groups[1].Value + ", SKILL v" + $vv + ")"); $bu++ }
  }
}
if ($bu -eq 0) { Write-Output "  bundle vigente" } else { $fail++ }

# 70. Prosa con tokens reales (v0.72, decision 34): ningun HTML afirma
# 12% junto a pressed, focus o capa (el token es 0.10 desde v0.37).
# Legitimos fuera del patron: wash 12% (disabled) y borde outline 12%.
Write-Output ""
Write-Output "=== Prosa con tokens reales ==="
$pr = 0
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
  $n = 0
  foreach ($l in ([System.IO.File]::ReadAllLines($h.FullName))) {
    $n++
    if ($l -match '12%' -and $l -match '(pressed|focus|capa)') { Write-Output ("  VIEJO " + $h.Name + " L" + $n + ": " + $l.Trim()); $pr++ }
  }
}
if ($pr -eq 0) { Write-Output "  prosa con valores vigentes" } else { $fail++ }

# 71. Titulo principal (v0.79): el h1 de cada pagina lleva display-large
# (rol display = texto mas importante y corto de la vista). El specimen
# display-small de typography.html no es h1 y queda fuera por diseno.
Write-Output ""
Write-Output "=== Titulo principal ==="
$ti = 0
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  if ($t -notmatch '<h1 class="[^"]*display-large') { Write-Output ("  SIN-LARGE " + $h.Name); $ti++ }
}
if ($ti -eq 0) { Write-Output "  h1 en display-large" } else { $fail++ }

# 72. Anatomia con tabla de partes (v0.81): la seccion Anatomy de
# button nombra >=3 partes y cada fila tiene specimen. Extiende el 60
# (anatomy con specimen) sin contradecirlo: el specimen compuesto sigue
# arriba, las partes van en tabla.
Write-Output ""
Write-Output "=== Anatomia con tabla de partes ==="
$ad = 0
$bp = "$root\views\button.html"
if (-not (Test-Path $bp)) { Write-Output "  SIN-PAGINA button.html"; $ad++ }
else {
  $t = Read-Css $bp
  $m = [regex]::Match($t, '(?s)<!-- INICIO: button anatomy -->(.*?)<!-- FIN: button anatomy -->')
  if (-not $m.Success) { Write-Output "  SIN-ANATOMIA button.html"; $ad++ }
  else {
    $cuerpo = $m.Groups[1].Value
    if ($cuerpo -notmatch '<button') { Write-Output "  SIN-SPECIMEN-COMPUESTO"; $ad++ }
    $mt = [regex]::Match($cuerpo, '(?s)<table class="demo-table">(.*?)</table>')
    if (-not $mt.Success) { Write-Output "  SIN-TABLA-PARTES"; $ad++ }
    else {
      $filas = [regex]::Matches($mt.Groups[1].Value, '(?s)<tr><td>(.*?)</tr>')
      if ($filas.Count -lt 3) { Write-Output ("  PARTES " + $filas.Count + " (minimo 3)"); $ad++ }
    }
  }
}
if ($ad -eq 0) { Write-Output "  anatomia con tabla de partes" } else { $fail++ }

# 73. Formato de tabla demo (v0.82): superficie con radio y borde
# outline-variant, encabezado sobre surface-container-low y rejilla
# completa (bordes en las 4 lados). Todo con tokens: cero literales.
Write-Output ""
Write-Output "=== Formato de tabla ==="
$tf = 0
$tcf = "$root\css\demo\table.css"
if (-not (Test-Path $tcf)) { Write-Output "  SIN-ARCHIVO demo/table.css"; $tf++ }
else {
  $t = (Read-Css $tcf).TrimStart([char]0xFEFF)
  $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
  if ($t -notmatch '(?m)^\.demo-table\s*\{[^}]*border-radius\s*:\s*var\(--md-sys-shape-corner-medium-default-size\)') { Write-Output "  SIN-RADIO"; $tf++ }
  if ($t -notmatch '(?m)^\.demo-table\s*\{[^}]*border\s*:\s*1px solid var\(--md-sys-color-outline-variant\)') { Write-Output "  SIN-BORDE"; $tf++ }
  if ($t -notmatch '(?m)^\.demo-table thead th\s*\{[^}]*background-color\s*:\s*var\(--md-sys-color-surface-container-low\)') { Write-Output "  SIN-FONDO-TH"; $tf++ }
  if ($t -notmatch '(?m)^\.demo-table th,\s*\n\.demo-table td\s*\{[^}]*border-right\s*:\s*1px solid var\(--md-sys-color-outline-variant\)') { Write-Output "  SIN-REJILLA"; $tf++ }
  if ($t -notmatch '(?m)^\.demo-table th,\s*\n\.demo-table td\s*\{[^}]*padding\s*:\s*var\(--rdm-measurement-200\)\s+var\(--rdm-measurement-300\)') { Write-Output "  SIN-PADDING-TOKEN"; $tf++ }
  if ($t -match 'border-bottom-color\s*:\s*var\(--md-sys-color-outline\)') { Write-Output "  TH-CON-OUTLINE (grid debe ser uniforme)"; $tf++ }
  if ($t -notmatch '(?m)^\.demo-table thead th\s*\{[^}]*font-family\s*:\s*var\(--md-sys-typescale-title-medium-font\)') { Write-Output "  SIN-TITLE-MEDIUM"; $tf++ }
  if ($t -notmatch '(?m)^\.demo-table td\s*\{[^}]*font-family\s*:\s*var\(--md-sys-typescale-body-medium-font\)') { Write-Output "  SIN-BODY-MEDIUM"; $tf++ }
  if ($t -notmatch '(?m)^\.demo-table code\s*\{[^}]*font-family\s*:\s*monospace') { Write-Output "  SIN-MONOSPACE"; $tf++ }
}
if ($tf -eq 0) { Write-Output "  formato con tokens" } else { $fail++ }

# 74. Toda pagina con tabla linkea el patron (v0.82): button y menu
# quedaron sin el link y sus tablas salian sin formato.
Write-Output ""
Write-Output "=== Paginas con tabla enlazan el patron ==="
$tp = 0
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
  $t = Read-Css $h.FullName
  if ($t -match '<table class="demo-table">' -and $t -notmatch 'demo/table\.css') { Write-Output ("  SIN-LINK " + $h.Name); $tp++ }
}
if ($tp -eq 0) { Write-Output "  todas enlazan" } else { $fail++ }

# 75. Huerfanos conocidos (v0.89): hay tokens declarados que ningun
# CSS consume a proposito. Este check los lista y verifica que sean
# los esperados, para que una auditoria futura no los reporte como
# error ni los borre por error.
#   - motion-duration (16): se mapean por componente (decision pendiente
#     de 10, no global).
#   - rdm-layout-breakpoint (4): var() no vale en la condicion de
#     @media, asi que son documentacion.
#   - rdm-z (4): M3 no define apilamiento; se usan cuando aparezca
#     el primer componente con capas.
Write-Output ""
Write-Output "=== Huerfanos conocidos ==="
$ho = 0
$prop = Get-ChildItem "$root\css" -Recurse -Filter *.css | Where-Object { $_.Name -ne 'rdm-next.bundle.css' }
$decl = @{}
$usa = @{}
foreach ($f in $prop) {
  $tt = Read-Css $f.FullName
  foreach ($m in ([regex]::Matches($tt, '(?m)^\s*(--[\w-]+)\s*:'))) { $decl[$m.Groups[1].Value] = $true }
  foreach ($m in ([regex]::Matches($tt, 'var\(\s*(--[\w-]+)'))) { $usa[$m.Groups[1].Value] = $true }
}
$esperados = @('--md-ref-typeface-brand','--md-ref-typeface-plain','--md-sys-motion-duration-extra-long1','--md-sys-motion-duration-extra-long2','--md-sys-motion-duration-extra-long3','--md-sys-motion-duration-long1','--md-sys-motion-duration-long2','--md-sys-motion-duration-long3','--md-sys-motion-duration-long4','--md-sys-motion-duration-medium1','--md-sys-motion-duration-medium2','--md-sys-motion-duration-medium3','--md-sys-motion-duration-medium4','--md-sys-motion-duration-short1','--md-sys-motion-duration-short2','--md-sys-motion-duration-short4','--md-sys-motion-path-standard-path','--rdm-layout-breakpoint-expanded','--rdm-layout-breakpoint-extra-large','--rdm-layout-breakpoint-large','--rdm-layout-breakpoint-medium','--rdm-measurement-0','--rdm-z-base','--rdm-z-dropdown','--rdm-z-modal','--rdm-z-sticky')
$huerf = @()
foreach ($k in $decl.Keys) { if (-not $usa.ContainsKey($k)) { $huerf += $k } }
$nuevo = @($huerf | Where-Object { $esperados -notcontains $_ })
$ausente = @($esperados | Where-Object { $huerf -notcontains $_ })
foreach ($n in $nuevo) { Write-Output ("  NUEVO-HUERFANO " + $n); $ho++ }
foreach ($a in $ausente) { Write-Output ("  YA-CONSUMIDO " + $a + " (sacar de la lista)"); $ho++ }
if ($ho -eq 0) { Write-Output ("  " + $huerf.Count + " huerfanos, todos conocidos") } else { $fail++ }

# 76. Prefijo del chrome (v0.90): todo lo que NO es libreria lleva
# demo-. Ningun rdm-showroom-* sobrevive: esas clases son chrome de
# showroom, no componentes, y el prefijo las saca del bundle.
Write-Output ""
Write-Output "=== Prefijo del chrome ==="
$pc = 0
$vend = Get-ChildItem "$root\css" -Recurse -Filter *.css | Where-Object { $_.Name -ne 'rdm-next.bundle.css' }
foreach ($f in $vend) {
  $tt = Read-Css $f.FullName
  if ($tt -match 'rdm-showroom-') { Write-Output ("  RDM-SHOWROOM " + $f.Name); $pc++ }
}
foreach ($h in (Get-ChildItem "$root\views\*.html" -ErrorAction SilentlyContinue)) {
  $th = Read-Css $h.FullName
  if ($th -match 'rdm-showroom-') { Write-Output ("  RDM-SHOWROOM " + $h.Name); $pc++ }
}
# el bundle no debe contener ninguna clase demo- ni rdm-showroom-
# (se ignoran los comentarios: el bundle conserva los headers de archivo
# y algunos mencionan .demo-table al explicar que NO se incluye).
$bf = "$root\css\rdm-next.bundle.css"
if (Test-Path $bf) {
  $tb = Read-Css $bf
  $tb = [regex]::Replace($tb, '/\*.*?\*/', '', 'Singleline')
  if ($tb -match '\.demo-[a-z]') { Write-Output "  DEMO-EN-BUNDLE (chrome en la libreria)"; $pc++ }
  if ($tb -match 'rdm-showroom-') { Write-Output "  SHOWROOM-EN-BUNDLE (chrome en la libreria)"; $pc++ }
}
if ($pc -eq 0) { Write-Output "  chrome con prefijo demo-, bundle limpio" } else { $fail++ }

# 77. Acoplamiento inverso (v0.94, decision 37): ninguna regla de la
# libreria (comp/, rdm/, primitives/, md/) puede usar .demo-*. Se
# ignoran los comentarios: la frontera se verifica en las reglas, no
# en la prosa. Si la libreria conoce una clase del showroom, el
# bundle la arrastra a mango-next.
Write-Output ""
Write-Output "=== Acoplamiento inverso ==="
$ai = 0
foreach ($d in @("comp","rdm","primitives","md")) {
  foreach ($f in (Get-ChildItem "$root\css\$d" -Filter *.css -ErrorAction SilentlyContinue)) {
    $t = Read-Css $f.FullName
    $t = [regex]::Replace($t, '/\*.*?\*/', '', 'Singleline')
    if ($t -match '\.demo-[a-z]') { Write-Output ("  DEMO-EN-LIBRERIA " + $d + "/" + $f.Name); $ai++ }
  }
}
if ($ai -eq 0) { Write-Output "  libreria sin clases demo-" } else { $fail++ }

# 78. Bundle completo y limpio (v0.94, decision 37): el bundle debe
# contener las 4 capas de la libreria (rdm, md, primitives, comp) y
# cero archivos de demo/. Si alguien agrega un @import de demo al
# entry, este check lo marca.
Write-Output ""
Write-Output "=== Bundle completo y limpio ==="
$bc = 0
$bf = "$root\css\rdm-next.bundle.css"
if (-not (Test-Path $bf)) { Write-Output "  SIN-BUNDLE"; $bc++ }
else {
  $tb = Read-Css $bf
  # los marcadores de capa son comentarios CSS: buscar en el texto original
  foreach ($capa in @("rdm","md","primitives","comp")) {
    if (-not $tb.Contains('===== ' + $capa + '\')) { Write-Output ("  SIN-CAPA " + $capa); $bc++ }
  }
  $tbSinComentarios = [regex]::Replace($tb, '/\*.*?\*/', '', 'Singleline')
  if ($tbSinComentarios -match 'demo/') { Write-Output "  DEMO-EN-BUNDLE"; $bc++ }
}
if ($bc -eq 0) { Write-Output "  bundle con las 4 capas, sin demo" } else { $fail++ }

Write-Output ""
if ($fail -eq 0) { Write-Output "OK: capa de tokens integra" } else { Write-Output ("FALLA: " + $fail + " chequeo(s)") }
exit $fail
