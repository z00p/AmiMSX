#!/bin/sh
# SCREEN 7/8 planar VRAM mapping test (tools/make_maptest.py): the cartridge in openMSX
# (reference VRAM) and in a TRACE build of AmiMSX frozen at its end loop, then compared.
# Usage: sh tools/maptest.sh [EXTRA_VASM_FLAGS]   (takes the WinUAE lock for about a minute)
cd "$(dirname "$0")/.." || exit 1
D=build/maptest; mkdir -p $D
python -I tools/make_maptest.py $D | tee $D/gen.txt
PC=$(sed -n 's/.*TRACEPC=\$\([0-9A-F]*\).*/\1/p' $D/gen.txt)
END=$(sed -n 's/ROM end \([0-9A-F]*\).*/\1/p' $D/gen.txt)
cp $D/T_MapTest.rom run/Roms/
W="$(pwd -W)/$D"
printf 'set ::out {%s/omsx_vram.bin}\nset ::endpc 0x%s\nsource {%s/tools/omsx_maptest.tcl}\n' "$W" "$END" "$(pwd -W)" > $D/run.tcl
rm -f $D/omsx_vram.bin
(cd tools/openmsx && timeout 120 ./openmsx.exe -machine C-BIOS_MSX2_EU -cart "$W/T_MapTest.rom" -script "$W/run.tcl" > "$W/omsx.log" 2>&1)
[ -f $D/omsx_vram.bin ] || { echo "openMSX gave no dump"; exit 1; }
echo "option sprites 1" > $D/maptest.keys
sh tools/buildid.sh >/dev/null
./tools/vasmm68k_mot.exe -devpac -nocase -m68020 -Fhunkexe -nosym -maxerrors=0 -DTRACE=1 -DTRACEPC=\$$PC "$@" \
  -o build/AmiMSX_maptest AmiMSX_Main_v3.1.asm > $D/build.log 2>&1 || { echo "build failed"; grep -E "^(error|fatal)" $D/build.log; exit 1; }
LOCK="$(git rev-parse --path-format=absolute --git-common-dir)/../build/winuae.lock"   # the shared lock (worktrees too)
until ! tasklist | grep -qi -E "winuae|arnold-uae" && mkdir "$LOCK" 2>/dev/null; do sleep 15; done
rm -f run/trace.bin
powershell -NoProfile -ExecutionPolicy Bypass -File winuae/batch_test.ps1 -Exe AmiMSX_maptest -Config AmiMSX-030.uae \
  -Roms T_MapTest.rom -Keys "$W/maptest.keys" -Shots 30 -WaitFile trace.bin -MaxWait 120 > $D/run.log 2>&1
cp run/trace.bin $D/trace_maptest.bin 2>/dev/null
rmdir "$LOCK"
python -I tools/read_maptest.py $D/trace_maptest.bin $D/omsx_vram.bin | tee $D/result.txt
