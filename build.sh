#!/bin/sh
# Assemble AmiMSX with vasm (Devpac-compatible mode). Output: build/AmiMSX
cd "$(dirname "$0")" && mkdir -p build
# No hand-counted branches (B.. *+n): an instruction's size can change with
# the layout (a displacement past 16 bits), and the branch then lands
# mid-instruction (3 Oct 2026: BNE.S *+10 over a MOVE.L to DREGOUT98(A3)).
if grep -nE "^[^;]*B[A-Z]{1,3}(\.[SBWL])?[[:space:]]+\*[+-]" AmiMSX_Main_v3.1.asm AmiMSX_Menu_v3.1.asm; then
  echo "error: branch to *+n/*-n above: use a label"; exit 1
fi
./tools/vasmm68k_mot.exe -devpac -nocase -m68020 -Fhunkexe -nosym -maxerrors=0 \
  -o build/AmiMSX AmiMSX_Main_v3.1.asm > build/build.log 2>&1
rc=$?
grep -E "^(error|fatal)" build/build.log
echo "vasm exit $rc; $(grep -c '^warning' build/build.log) warnings (see build/build.log)"
exit $rc
