#!/bin/sh
# Build AmiMSX at a given commit into build/AmiMSX_bis_<commit> (git worktree,
# the current vasm). Usage: sh tools/bisect_build.sh <commit>
set -e
cd "$(dirname "$0")/.."
c=$1
wt=build/wt_bisect
rm -rf "$wt" 2>/dev/null || true
git worktree prune
git worktree add -f "$wt" "$c" -q
cp tools/vasmm68k_mot.exe "$wt/tools/" 2>/dev/null || true
(cd "$wt" && ./tools/vasmm68k_mot.exe -devpac -nocase -m68020 -Fhunkexe -nosym -maxerrors=0 \
   -o "../AmiMSX_bis_$c" AmiMSX_Main_v3.1.asm > ../bis_$c.log 2>&1) || { echo "build failed $c"; exit 1; }
git worktree remove --force "$wt"
echo "build/AmiMSX_bis_$c"
