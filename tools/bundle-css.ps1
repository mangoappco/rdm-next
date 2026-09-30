# RDM Next - Genera css/rdm-next.bundle.css desde el manifiesto
# css/rdm-next.css (fuente) + version ?v= en los HTML de raiz.
#
# Uso: powershell -ExecutionPolicy Bypass -File tools/bundle-css.ps1
# Sale con codigo 1 si un @import no resuelve (misma promesa del check 7,
# pero sobre lo que realmente se sirve). UTF-8 sin BOM, PowerShell 5.1.

$root = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
$enc = New-Object System.Text.UTF8Encoding($false)
$visitados = @{}

function Get-RelativePath($from, $to) {
  $u1 = [System.Uri]$from
  $u2 = [System.Uri]$to
  return [System.Uri]::UnescapeDataString($u1.MakeRelativeUri($u2).ToString()).Replace('/', '\')
}

function Expand-Css($file) {
  $full = [System.IO.Path]::GetFullPath($file)
  if ($visitados.ContainsKey($full)) { return '' }
  $visitados[$full] = $true
  if (-not (Test-Path $full)) {
    Write-Output ("BUNDLE-ERROR: no resuelve " + $full)
    exit 1
  }
  $dir = Split-Path $full -Parent
  $rel = Get-RelativePath ($root + '\css\') $full
  $out = '/* ===== ' + $rel + ' ===== */' + "`n"
  $lines = [System.IO.File]::ReadAllLines($full)
  foreach ($l in $lines) {
    $m = [regex]::Match($l, '@import\s+url\(\s*[''"]?([^''")]+)[''"]?\s*\)\s*([^;]*);')
    if ($m.Success) {
      $target = $m.Groups[1].Value.Trim()
      if ($target -match '^https?://') { continue }
      $media = $m.Groups[2].Value.Trim()
      $inner = Expand-Css (Join-Path $dir $target)
      if ($media -ne '') {
        $out += '@media ' + $media + " {`n" + $inner + "}`n"
      } else {
        $out += $inner
      }
    } else {
      $out += $l + "`n"
    }
  }
  return $out
}

$bundle = Expand-Css (Join-Path $root 'css\rdm-next.css')
[System.IO.File]::WriteAllText((Join-Path $root 'css\rdm-next.bundle.css'), $bundle, $enc)

$sk = [System.IO.File]::ReadAllText((Join-Path $root 'SKILL.md'))
$max = 0
foreach ($m in [regex]::Matches($sk, '- \*\*v(\d+)\.(\d+)\*\*')) {
  $v = [int]$m.Groups[1].Value * 1000 + [int]$m.Groups[2].Value
  if ($v -gt $max) { $max = $v; $vers = $m.Groups[1].Value + '.' + $m.Groups[2].Value }
}
if (-not $vers) { Write-Output 'BUNDLE-ERROR: sin version en SKILL.md'; exit 1 }

$n = 0
# index.html queda en la raiz (href="css/..."), los de componente en
# views/ (href="../css/..."). El regex acepta ambos prefijos.
$htmls = @(Get-ChildItem "$root\views\*.html") + @(Get-ChildItem "$root\index.html")
foreach ($h in $htmls) {
  $t = [System.IO.File]::ReadAllText($h.FullName)
  $nuevo = 'href="../css/rdm-next.bundle.css?v=' + $vers + '"'
  $t2 = [regex]::Replace($t, 'href="(\.\./)?css/rdm-next(\.bundle)?\.css(\?v=[\d.]+)?"', $nuevo)
  # index.html no sube un nivel
  if ($h.Name -eq 'index.html') { $t2 = $t2.Replace('href="../css/', 'href="css/') }
  if ($t2 -ne $t) {
    [System.IO.File]::WriteAllText($h.FullName, $t2, $enc)
    $n++
  }
}
Write-Output ("OK: bundle con " + $visitados.Count + " archivos, ?v=" + $vers + " en " + $n + " HTML")
