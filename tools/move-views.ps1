# RDM Next - Mueve los 18 showrooms de componente a views/ (v0.91)
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File tools/move-views.ps1
#   powershell -ExecutionPolicy Bypass -File tools/move-views.ps1 -DryRun
#
# Que hace:
#   1. Mueve los 17 HTML de componente a views/ (index.html queda en la raiz).
#   2. Reescribe las rutas de los movidos: href="css/..." y href="x.html"
#      pasan a ../css/... y x.html (los HTML siguen siendo hermanos).
#   3. Reescribe el href de css/ en index.html (los 18 pasan a views/x.html).
#   4. Actualiza los globs $root\*.html -> $root\views\*.html en el
#      script y en tools/bundle-css.ps1, salvo los que deben seguir viendo
#      la raiz (index.html: estructura de la landing).
#   5. Verifica: 0 rutas rotas, 0 restos en la raiz, checks en verde.
#
# Por que 3 y 4 no son el mismo cambio: index.html sigue en la raiz, asi
# que sus href a componentes pasan a views/x.html, mientras que sus href a
# css/ siguen siendo css/... (no baja un nivel). Los HTML movidos si bajan
# un nivel para todo.

$root = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
$enc = New-Object System.Text.UTF8Encoding($false)
$DryRun = $args -contains '-DryRun'

function Log($m) { Write-Output ("  " + $m) }

# --- 1. Inventario: que HTML se mueven y que queda ---
$todos = Get-ChildItem "$root\*.html" -File
$mueven = @()
$quedan = @()
foreach ($f in $todos) {
  if ($f.Name -eq 'index.html') { $quedan += $f.Name } else { $mueven += $f.Name }
}
Write-Output "=== Plan ==="
Log ("a mover: " + $mueven.Count + "  |  queda en raiz: " + ($quedan -join ', '))
# 17 componentes + index.html = 18 html en total
if ($mueven.Count -ne 17) { Write-Output ("ABORTA: se esperaban 17, hay " + $mueven.Count); exit 1 }

# --- 2. Comprobar que views/ no existe todavia (idempotencia) ---
if (Test-Path "$root\views") {
  $previos = (Get-ChildItem "$root\views" -Filter *.html -File -ErrorAction SilentlyContinue).Count
  if ($previos -gt 0) { Write-Output ("ABORTA: views/ ya tiene " + $previos + " html"); exit 1 }
}

if ($DryRun) {
  Write-Output "=== DRY RUN: no se escribe nada ==="
} else {
  # --- 3. Mover ---
  New-Item -ItemType Directory -Path "$root\views" -Force | Out-Null
  foreach ($n in $mueven) {
    Move-Item "$root\$n" "$root\views\$n"
  }
  Log ("movidos: " + $mueven.Count)
}

# --- 4. Reescribir los movidos: todo href relativo baja un nivel ---
if (-not $DryRun) {
  $fix = 0
  foreach ($n in $mueven) {
    $f = "$root\views\$n"
    $t = [System.IO.File]::ReadAllText($f)
    $o = $t
    # css/ y cualquier ruta que salga de views/ hacia un nivel arriba
    $t = $t.Replace('href="css/', 'href="../css/')
    # el link de la barra sube a la raiz: index.html no se movio
    $t = $t.Replace('href="index.html"', 'href="../index.html"')
    # los enlaces entre componentes NO cambian: siguen siendo hermanos
    [System.IO.File]::WriteAllText($f, $t, $enc)
    if ($t -ne $o) { $fix++ }
  }
  Log ("HTML movidos con rutas ../: " + $fix)

  # --- 5. index.html: los href a componentes pasan a views/ ---
  $ix = "$root\index.html"
  $t = [System.IO.File]::ReadAllText($ix)
  $o = $t
  foreach ($n in $mueven) {
    $t = $t.Replace('href="' + $n + '"', 'href="views/' + $n + '"')
  }
  [System.IO.File]::WriteAllText($ix, $t, $enc)
  if ($t -ne $o) { Log ("index.html: enlaces a componentes -> views/") }
}

# --- 6. Actualizar globs en el script y en bundle-css ---
if (-not $DryRun) {
  $sp = "$root\tools\verify-tokens.ps1"
  $st = [System.IO.File]::ReadAllText($sp)
  $antes = ([regex]::Matches($st, [regex]::Escape('$root\*.html'))).Count
  $st = $st.Replace('$root\*.html', '$root\views\*.html')
  [System.IO.File]::WriteAllText($sp, $st, $enc)
  Log ("verify-tokens.ps1: " + $antes + " globs -> views/")

  $bp = "$root\tools\bundle-css.ps1"
  $bt = [System.IO.File]::ReadAllText($bp)
  $bt = $bt.Replace('$root\*.html', '$root\views\*.html')
  # bundle-css tambien debe seguir actualizando index.html (landing)
  $bt = $bt.Replace('foreach ($h in (Get-ChildItem "$root\views\*.html")) {', 'foreach ($h in (Get-ChildItem "$root\views\*.html", "$root\index.html")) {')
  [System.IO.File]::WriteAllText($bp, $bt, $enc)
  Log ("bundle-css.ps1: glob -> views/ (+ index.html)")
}

# --- 7. Verificar ---
Write-Output "=== Verificacion ==="
if ($DryRun) {
  Log ("html en raiz: " + (Get-ChildItem "$root\*.html" -File).Count + " (todavia sin mover)  |  en views/: aun no existe (dry run)")
  Write-Output "DRY RUN: nada escrito. Revisar el plan y ejecutar sin -DryRun."
  exit 0
}
$raiz = (Get-ChildItem "$root\*.html" -File).Count
$enViews = (Get-ChildItem "$root\views\*.html" -File).Count
Log ("html en raiz: " + $raiz + " (esperado 1)  |  en views/: " + $enViews + " (esperado 17)")
if ($raiz -ne 1 -or $enViews -ne 17) { Write-Output "ABORTA: recuento incorrecto"; exit 1 }

# rutas rotas: cada href="..." debe resolver a archivo
$rotas = 0
foreach ($f in (Get-ChildItem "$root\views\*.html", "$root\index.html")) {
  $t = [System.IO.File]::ReadAllText($f.FullName)
  $base = Split-Path $f.FullName -Parent
  foreach ($m in [regex]::Matches($t, 'href="([^"]+)"')) {
    $h = $m.Groups[1].Value
    if ($h -match '^(https?:|#)') { continue }
    # fuera el query string: ?v=0.90 no es parte de la ruta
    $limpio = ($h -split '\?')[0]
    $destino = [System.IO.Path]::GetFullPath((Join-Path $base $limpio))
    if (-not (Test-Path $destino)) { Log ("ROTA " + $f.Name + " -> " + $h); $rotas++ }
  }
}
if ($rotas -eq 0) { Log "0 rutas rotas" } else { Write-Output ("ABORTA: " + $rotas + " rutas rotas"); exit 1 }

Write-Output "OK: refactor views/ completo"
