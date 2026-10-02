# Film strips: one ROM, one build, many shots -> build\strips\<tag>\
param([string]$Exe, [string]$Rom, [string]$Shots, [string]$Tag, [string]$Config = "", [string]$Keys = "")
$base = "C:\AMD\amimsx"; $dst = "$base\build\strips\$Tag"; New-Item -ItemType Directory -Force $dst | Out-Null
$cfg = @(); if ($Config) { $cfg = @("-Config", $Config) }
if ($Keys) { $cfg += @("-Keys", $Keys) }
$name = [IO.Path]::GetFileNameWithoutExtension($Rom)
& powershell -NoProfile -ExecutionPolicy Bypass -File "$base\winuae\batch_test.ps1" -Exe $Exe -Roms $Rom -Shots $Shots @cfg | Out-Null
foreach ($t in ($Shots -split ",")) { Copy-Item -LiteralPath "$base\build\shots\${name}_${t}s.png" $dst -Force -ErrorAction SilentlyContinue }
"$Tag done"
