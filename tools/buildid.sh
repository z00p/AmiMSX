#!/bin/sh
# Writes buildid.i (git-ignored), included by the menu title and $VER string:
#   DC.B "13.10.2026 86e893d+"   (date, short commit, '+' = uncommitted changes)
cd "$(dirname "$0")/.." || exit 1
h=$(git rev-parse --short HEAD 2>/dev/null || echo nogit)
git diff --quiet HEAD -- '*.asm' '*.s' 2>/dev/null || h="$h+"
printf '\tDC.B\t"%s %s"\n' "$(date +%d.%m.%Y)" "$h" > buildid.i
