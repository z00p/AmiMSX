# A/B shots: every ROM on build A, then on build B (same shots), into build\<OutA>, build\<OutB>.
# Usage: powershell -File winuae\regress_ab.ps1 -ExeA AmiMSX_rs2 -ExeB AmiMSX_rs3 -OutA ab_a -OutB ab_b [-Roms a,b] [-Shots 26,42] [-Config AmiMSX-test.uae]
param([string]$ExeA, [string]$ExeB, [string]$OutA = "ab_a", [string]$OutB = "ab_b", [string]$Roms = "",
      [string]$Shots = "26,42", [string]$Config = "")
$base = "C:\AMD\amimsx"
if (-not $Roms) { $Roms = (Get-ChildItem "$base\run\Roms" -File | Where-Object { $_.Name -notmatch '^(R2|T_)' } | ForEach-Object Name) -join "," }
$cfg = @(); if ($Config) { $cfg = @("-Config", $Config) }
foreach ($v in @(@($ExeA, $OutA), @($ExeB, $OutB))) {
  $dst = "$base\build\$($v[1])"; New-Item -ItemType Directory -Force $dst | Out-Null
  foreach ($r in ($Roms -split ",")) {
    $name = [IO.Path]::GetFileNameWithoutExtension($r)
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$base\winuae\batch_test.ps1" -Exe $v[0] -Roms $r -Shots $Shots @cfg | Out-File -Append "$dst\log.txt"
    foreach ($t in ($Shots -split ",")) { Copy-Item -LiteralPath "$base\build\shots\${name}_${t}s.png" $dst -Force -ErrorAction SilentlyContinue }
  }
}
"AB DONE"
