# Before/after shots for the KonamiSCC ("SCC 1") decode change.
$roms = "M_Uridium2_SCC.rom,R2K_GaliousEnh.rom,R2K_Gradius2VC.rom,R2K_KingsValley2.rom,R2K_Nemesis2.rom,R2K_Nemesis3.rom,R2K_Nemesis3Enh.rom,R2K_Salamander.rom,R2K_SalamanderEnh.rom,R2K_SpaceManbow.rom,R2K_UsasEnh.rom,R2K_VampireKillerSCC.rom,R2K_ZanacEx.rom,R2_Batman.rom,R2_BunGaRua.rom,R2_DEVA.rom,R2_LotusF3.rom,034_GodzillaBalls.rom"
$base = "C:\AMD\amimsx"
foreach ($v in @(@("AmiMSX_rs", "scc_before"), @("AmiMSX_rs2", "scc_after"))) {
  $dst = "$base\build\$($v[1])"; New-Item -ItemType Directory -Force $dst | Out-Null
  Remove-Item "$base\build\shots\*" -Include *_26s.png, *_42s.png -ErrorAction SilentlyContinue
  & powershell -NoProfile -ExecutionPolicy Bypass -File "$base\winuae\batch_test.ps1" -Exe $v[0] -Roms $roms -Shots "26,42" | Out-File "$dst\log.txt"
  Get-ChildItem "$base\build\shots" -Include *_26s.png, *_42s.png -Recurse | Copy-Item -Destination $dst -Force
}
"SCC REGRESS DONE"
