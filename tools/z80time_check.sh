#!/bin/sh
# Z80 instruction-cost check for a core change: builds a CYCLOG trace variant
# of the given source, runs the timing cartridge (tools/make_z80time.py,
# run/Roms/T_Z80Time.rom) in WinUAE 030, and writes every measured cost to
# build/z80t/costs_<tag>.txt. Compare two tags with diff: any difference is
# a change in what an instruction costs (or in its setup).
# Usage: [DEFS="-DX=1 ..."] sh tools/z80time_check.sh <tag> [source dir, default .]
# Takes the shared WinUAE lock for about a minute. Run from the main checkout
# (C:\AMD\amimsx: WinUAE's run/ is there); the source may be a worktree.
cd "$(dirname "$0")/.." || exit 1
TOOLS=$(pwd -W)/tools                # this checkout's reader (it has --costs)
MAIN=C:/AMD/amimsx                   # (Windows Python and vasm need the drive form)
TAG=${1:?tag}; SRC=${2:-.}
END=$(python -I -c "import json;print('%04X' % (json.load(open('$MAIN/build/z80t/z80time.json'))['end'] + 1))")
( cd "$SRC" && ./tools/vasmm68k_mot.exe -devpac -nocase -m68020 -Fhunkexe -nosym -maxerrors=0 \
    -DTRACE=1 -DCYCLOG=1 -DTRACEPC=\$$END $DEFS -o "$MAIN/build/AmiMSX_z80t_$TAG" AmiMSX_Main_v3.1.asm \
    > "$MAIN/build/z80t/build_$TAG.log" 2>&1 ) || { echo "build failed (build/z80t/build_$TAG.log)"; exit 1; }
cd "$MAIN" || exit 1
until ! tasklist | grep -qi -E "winuae|arnold-uae" && mkdir build/winuae.lock 2>/dev/null; do sleep 15; done
rm -f run/trace.bin
powershell -NoProfile -ExecutionPolicy Bypass -File winuae/batch_test.ps1 -Exe AmiMSX_z80t_$TAG -Config AmiMSX-030.uae \
  -Roms T_Z80Time.rom -Keys "$(pwd -W)/tests/keys/none.keys" -Shots 40 -WaitFile trace.bin -MaxWait 200 \
  > build/z80t/run_$TAG.log 2>&1
cp run/trace.bin build/z80t/trace_$TAG.bin 2>/dev/null
rmdir build/winuae.lock
[ -f build/z80t/trace_$TAG.bin ] || { echo "no trace.bin (build/z80t/run_$TAG.log)"; exit 1; }
python -I "$TOOLS/read_z80time.py" build/z80t/trace_$TAG.bin build/z80t/z80time.json \
  --costs build/z80t/costs_$TAG.txt | head -12
