# Style guide

## Audience
Write for people first and agents second. Use plain English and short sentences, and explain a term the first time it appears. Assume the reader knows 68k and the Amiga custom chips in general, but not our code.

## Each lesson uses this shape

```
### <short title of the lesson>

**Problem.** One or two sentences: what the user saw, on which machine/setting.

**Before** (`<file>`, <project> <version>):
    <short excerpt: the minimum lines that show the mistake>

**After** (`<file>`, commit <hash> / switch <NAME>):
    <the fixed lines>

**Why.** What the hardware actually does, and why the old code broke on the target.
**Evidence.** Measured: ms per frame, frames that differ, captures vs the reference emulator, dB, etc.
**Look up.** Commit, build switch, notes file.
```

- Keep excerpts short: reduce them to the essential lines rather than pasting whole functions. Mark omissions with `...`.
- Give numbers, not adjectives ("a fighter was missing in 7 of 12 frames", not "it flickered a lot").
- Say which machine or setting shows the problem (PiStorm, 68030/50, BigMig, WinUAE config).

## Licensing of excerpts
- Quote only our own projects' code: **AmiMSX** (freeware by Juan Antonio Gómez Gálvez; 4.x changes; quoted with his permission) and **Arnold for the Amiga** (GPL-2.0, derived from Kevin Thacker's Arnold).
- Put the source and licence under each excerpt, e.g. *Source: AmiMSX 4.1.2, AmiMSX_Main_v3.1.asm (freeware, used with permission)* or *Source: Arnold-m68k 0.6, cpc/crtc.c (GPL-2.0)*.
- Never quote third-party sources kept for reference (other emulators, ROM disassemblies, commercial game code). Describe what a game does in your own words.

## Privacy
No personal names of testers or owners, no local paths, IP addresses, tokens, or private collections. Write "a tester", "the reference emulator", "the share".
