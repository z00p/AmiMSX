#!/bin/sh
# Assemble AmiMSX with vasm (Devpac-compatible mode). Output: build/AmiMSX
cd "$(dirname "$0")" && mkdir -p build
./tools/vasmm68k_mot.exe -devpac -nocase -m68020 -Fhunkexe -nosym -maxerrors=0 \
  -o build/AmiMSX AmiMSX_Main_v3.1.asm > build/build.log 2>&1
rc=$?
grep -E "^(error|fatal)" build/build.log
echo "vasm exit $rc; $(grep -c '^warning' build/build.log) warnings (see build/build.log)"
exit $rc
