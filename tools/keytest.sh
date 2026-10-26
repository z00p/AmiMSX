#!/bin/sh
# Keyboard mapping test (Amiga raw keys -> AmiMSX's table -> MSX matrix, read by a cartridge).
# Usage: sh tools/keytest.sh     (takes the WinUAE lock for about a minute)
cd "$(dirname "$0")/.." || exit 1
mkdir -p build/keytest
python -I tools/make_keytest.py build/keytest | tee build/keytest/gen.txt
PC=$(sed -n 's/.*TRACEPC=\$\([0-9A-F]*\).*/\1/p' build/keytest/gen.txt)
cp build/keytest/T_KeyTest.rom run/Roms/
sh tools/buildid.sh >/dev/null
./tools/vasmm68k_mot.exe -devpac -nocase -m68020 -Fhunkexe -nosym -maxerrors=0 -DTRACE=1 -DTRACEPC=\$$PC \
  -o build/AmiMSX_keytest AmiMSX_Main_v3.1.asm > build/keytest/build.log 2>&1 || { echo "build failed"; exit 1; }
until ! tasklist | grep -qi -E "winuae|arnold-uae" && mkdir build/winuae.lock 2>/dev/null; do sleep 15; done
rm -f run/trace.bin
powershell -NoProfile -ExecutionPolicy Bypass -File winuae/batch_test.ps1 -Exe AmiMSX_keytest -Config AmiMSX-030.uae \
  -Roms T_KeyTest.rom -Keys "$(pwd -W)/build/keytest/keytest.keys" -Shots 50 -WaitFile trace.bin -MaxWait 200 > build/keytest/run.log 2>&1
cp run/trace.bin build/keytest/trace_keytest.bin 2>/dev/null
rmdir build/winuae.lock
python -I tools/read_keytest.py build/keytest/trace_keytest.bin build/keytest/keytest.json
