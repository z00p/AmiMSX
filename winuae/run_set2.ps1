# Full set-2 pass: every R2*/R2K* ROM and every disk in run\Disks, one build, shots per title -> build\set2\<title>\
param([string]$Exe = "AmiMSX_set2", [string]$Shots = "18,30,45,65", [string]$Config = "AmiMSX-030.uae")
$base = "C:\AMD\amimsx"
$titles = @(Get-ChildItem "$base\run\Roms" -File | Where-Object { $_.Name -match '^R2' } | ForEach-Object Name) + @(Get-ChildItem "$base\run\Disks" -File -Filter *.dsk | ForEach-Object Name)
foreach ($t in $titles) {
  $tag = "set2\" + [IO.Path]::GetFileNameWithoutExtension($t)
  & "$base\winuae\strips.ps1" -Exe $Exe -Rom $t -Shots $Shots -Tag $tag -Config $Config
}
"SET2 DONE"
