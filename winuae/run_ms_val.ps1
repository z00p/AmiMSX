# Mode-split validation: core set (default config, 26/42 s) and MSX2 set-2 titles (030, 18/30/45/65 s) on AmiMSX_msrs.
$base = "C:\AMD\amimsx"; $s = "$base\winuae\strips.ps1"
$core = Get-ChildItem "$base\run\Roms" -File | Where-Object { $_.Name -notmatch '^(R2|T_)' } | ForEach-Object Name
foreach ($r in $core) { & $s -Exe AmiMSX_msrs -Rom $r -Shots "26,42" -Tag ("msval_core\" + [IO.Path]::GetFileNameWithoutExtension($r)) | Out-Null }
$s2 = "R2K_GaliousEnh.rom","R2K_UsasEnh.rom","R2K_Nemesis3Enh.rom","R2K_SalamanderEnh.rom","R2K_SpaceManbow.rom","R2_Batman.rom","R2_DEVA.rom","R2_Delta[ASCII16].rom","R2_NeonRevMSX2[ASCII8].rom","R2_Popolon.rom"
foreach ($r in $s2) { & $s -Exe AmiMSX_msrs -Rom $r -Shots "18,30,45,65" -Config AmiMSX-030.uae -Tag ("msval_set2\" + [IO.Path]::GetFileNameWithoutExtension($r)) | Out-Null }
"MSVAL DONE"
