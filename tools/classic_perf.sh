#!/bin/sh
# Classic MSX2 speed on the A1200 and 030 configs (PERF builds build/AmiMSX_perf_<name>).
# Usage: EXES="base head" sh tools/classic_perf.sh ; python tools/classic_cmp.py base head
cd "$(dirname "$0")/.."
ROMS="R2K_VampireKiller.rom R2K_Usas.rom R2K_MetalGear.rom R2K_ZanacEx.rom R2K_KingsValley2.rom R2K_Nemesis3Enh.rom R2K_GaliousEnh.rom"
for exe in ${EXES:-base head}; do for cfg in a1200 030; do for r in $ROMS; do
  rm -f run/perf.bin
  powershell -NoProfile -ExecutionPolicy Bypass -File winuae/batch_test.ps1 -Exe AmiMSX_perf_$exe -Config AmiMSX-$cfg.uae \
    -Roms $r -Shots 30 -Keys tests/keys/play.keys -WaitFile perf.bin -MaxWait 400 -Tag tmp >/dev/null 2>&1
  n=${r%.rom}; [ -f build/perf/${n}_tmp.bin ] && mv build/perf/${n}_tmp.bin build/perf/classic/${n}_${cfg}_${exe}.bin
done; done; done
echo done > build/perf/classic/done_${EXES:-all}
