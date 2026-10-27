#!/bin/sh
# Cartridge SRAM test (tools/make_sramtest.py): each of the four SRAM cartridges twice in
# openMSX (reference) and twice in a TRACE build of AmiMSX (the second run reads what the
# first one saved), then the logs compared. Usage: sh tools/sramtest.sh [EXTRA_VASM_FLAGS]
# (takes the WinUAE lock for about 5 minutes; puts the test ROMs in run/Roms and a romdb
# that knows them in run/, and puts the repository's romdb back at the end)
cd "$(dirname "$0")/.." || exit 1
D=build/sramtest; mkdir -p $D
python -I tools/make_sramtest.py run/Roms | tee $D/gen.txt
python -I tools/make_romdb.py --tests --out $D/AmiMSX4.romdb --copy run > $D/romdb.txt || exit 1
W="$(pwd -W)/$D"
P="$(cd tools/openmsx && pwd)"
# openMSX keeps cartridge SRAM in its user folder: a fresh one for the test (OPENMSX_HOME),
# so the first run starts blank (the usual one may sit in OneDrive, which can refuse deletes).
export OPENMSX_HOME="$W/omsxhome"
rm -rf $D/omsxhome; mkdir -p $D/omsxhome
grep "^T_" $D/gen.txt | while read -r rom type; do
  n=${rom%%\[*}
  for r in 1 2; do
    printf 'set ::out {%s/omsx_%s_r%s.bin}\nset ::endpc 0x4080\nsource {%s/tools/omsx_maptest.tcl}\n' "$W" "$n" "$r" "$(pwd -W)" > $D/run.tcl
    (cd tools/openmsx && timeout 120 ./openmsx.exe -machine AmiMSX_MSX2_Disk -cart "$(pwd -W)/../../run/Roms/$rom" -romtype $type -script "$W/run.tcl" > "$W/omsx_${n}_r$r.log" 2>&1)
  done
done
echo "option sprites 1" > $D/sramtest.keys
sh tools/buildid.sh >/dev/null
./tools/vasmm68k_mot.exe -devpac -nocase -m68020 -Fhunkexe -nosym -maxerrors=0 -DTRACE=1 -DTRACEPC=\$4081 "$@" \
  -o build/AmiMSX_sramtest AmiMSX_Main_v3.1.asm > $D/build.log 2>&1 || { echo "build failed"; grep -E "^(error|fatal)" $D/build.log; exit 1; }
LOCK="$(git rev-parse --path-format=absolute --git-common-dir)/../build/winuae.lock"   # the shared lock (worktrees too)
until ! tasklist | grep -qi -E "winuae|arnold-uae" && mkdir "$LOCK" 2>/dev/null; do sleep 15; done
grep "^T_" $D/gen.txt | while read -r rom type; do
  n=${rom%%\[*}
  rm -f "run/Roms/$rom.sram"
  for r in 1 2; do
    rm -f run/trace.bin
    powershell -NoProfile -ExecutionPolicy Bypass -File winuae/batch_test.ps1 -Exe AmiMSX_sramtest -Config AmiMSX-030.uae \
      -Roms "$rom" -Keys "$W/sramtest.keys" -Shots 20 -WaitFile trace.bin -MaxWait 90 > $D/run_${n}_r$r.log 2>&1
    cp run/trace.bin $D/trace_${n}_r$r.bin 2>/dev/null
  done
  cp "run/Roms/$rom.sram" "$D/$n.sram" 2>/dev/null
done
rmdir "$LOCK"
cp AmiMSX4.romdb run/AmiMSX4.romdb
fail=0
grep "^T_" $D/gen.txt | while read -r rom type; do
  n=${rom%%\[*}
  for r in 1 2; do
    echo "== $n run $r"
    python -I tools/read_sramtest.py $D/trace_${n}_r$r.bin $D/omsx_${n}_r$r.bin || echo "FAIL $n run $r"
  done
done | tee $D/result.txt
grep -q "FAIL" $D/result.txt && echo "RESULT: FAIL" || echo "RESULT: PASS"
