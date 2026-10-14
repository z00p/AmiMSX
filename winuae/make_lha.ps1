# Build the release LHA with the Amiga's own lha (winuae\wb\C\lha, Lha 40.57):
# copies release\AmiMSX4 to run\Release (AmiMSX:Release), boots the test
# Workbench (030 config) with the boot line replaced by the lha command, and
# waits for AmiMSX:Release/done. Output: release\AmiMSX4.lha
param([string]$Config = "AmiMSX-030.uae", [int]$MaxWait = 240)
$ErrorActionPreference = "Stop"
$base = Split-Path -Parent $PSScriptRoot
$src = Join-Path $base "release\AmiMSX4"
$rel = Join-Path $base "run\Release"
if (Test-Path $rel) { Remove-Item -Recurse -Force $rel }
New-Item -ItemType Directory $rel | Out-Null
Copy-Item -Recurse (Join-Path $src "AmiMSX") $rel
Copy-Item (Join-Path $src "AmiMSX.info") $rel
$seq = "$base\winuae\wb\S\Startup-Sequence"
$latin1 = [Text.Encoding]::GetEncoding(28591)
$orig = [IO.File]::ReadAllText($seq, $latin1)
$cmd = "CD AmiMSX:Release`nC:lha -r a AmiMSX4.lha AmiMSX AmiMSX.info >AmiMSX:Release/lha.log`nC:lha v AmiMSX4.lha >AmiMSX:Release/list.txt`nEcho >AmiMSX:Release/done ok"
$s = [regex]::Replace($orig, '(?m)^(; )?Run >NIL: AmiMSX:AmiMSX.*$', $cmd.Replace('$', '$$'))
[IO.File]::WriteAllText($seq, $s, $latin1)
try {
  Get-Process winuae64 -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 1
  Start-Process "C:\Program Files\WinUAE\winuae64.exe" -ArgumentList "-f `"$base\winuae\$Config`"" -WorkingDirectory "C:\Program Files\WinUAE"
  $t0 = Get-Date
  while (-not (Test-Path (Join-Path $rel "done")) -and ((Get-Date) - $t0).TotalSeconds -lt $MaxWait) { Start-Sleep 2 }
  Start-Sleep 2
} finally {
  Get-Process winuae64 -ErrorAction SilentlyContinue | Stop-Process -Force
  [IO.File]::WriteAllText($seq, $orig, $latin1)
}
if (-not (Test-Path (Join-Path $rel "done"))) { throw "lha did not finish" }
Copy-Item (Join-Path $rel "AmiMSX4.lha") (Join-Path $base "release\AmiMSX4.lha") -Force
Get-Content (Join-Path $rel "list.txt")
