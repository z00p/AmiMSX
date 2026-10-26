# Z80 core audit (ZEXALL-style), 15 October 2026

The Z80 core in `AmiMSX_Main_v3.1.asm` (the `Otra`/`MIns` handlers, lines
3100-6400, the interrupt path at `MiraInter`/`SiInterRun`, and the opcode
tables `INS`, `INSCB`, `INSDD`, `INSFD`, `INSED`, `INSCBIX`, `INSCBIY`) was
read against openMSX 21.0's `CPUCore.cc`, `Z80.hh` and `CPURegs.hh` (branch
`ref/openmsx`). The cheap fixes are on this branch; the rest is a
prioritised list. A ZEXALL-style test ROM generator, `tools/make_zex.py`,
self-checks against a ZEXALL-verified Z80 and runs in AmiMSX and openMSX.

## How the core keeps the flags

- F lives in D3 as a 68020 CCR image: bit 0 = C, bit 1 = P/V (the 68k V),
  bit 2 = Z, bit 3 = S (the 68k N), bit 4 = the 68k X. `PUSH AF` translates
  it with the `Flags_Push` table (bit 4 becomes the Z80 N flag, bits 5-7
  become flag bits 3, 4 (H) and 5), and `POP AF` maps all eight bits back
  with `Flags_Pop`, so a flag byte survives a push/pop round trip.
- Every flag-setting handler ends in `MOVE.W CCR,D3` (or a table lookup).
  A CCR move clears bits 5-7, so after any such instruction H, X and Y
  read as 0, and N reads as the 68k X flag: the carry of the last ADD/SUB
  (so an `ADD` that carried shows N = 1), or a stale value after AND/OR/XOR
  (X is unchanged by logic operations). H and N are therefore not
  modelled, as `Docs/open_issues.md` says; X/Y (bits 3 and 5) neither.
- AND/OR/XOR take S, Z and parity from `Flags_Par` (a 256-entry table).
  ADD/SUB/CP take S, Z, V and C from the 68k; ADC/SBC/ADC HL use ADDX/SUBX
  with the Z trick (`OR #4,CCR` first). INC/DEC keep C with `PONS`.
- DAA does not use H and N. Each ADD/ADC/SUB/SBC/INC A/DEC A stores A
  before the operation in `DatDAA`; DAA recovers the operand from it and
  redoes the operation with ABCD/SBCD. `PUSH AF`/`POP AF` save and restore
  `DatDAA` per stack slot (`Flags_DAA`, indexed by the low byte of SP).

## Instruction groups

Status: **matches** = results and the documented flags (S, Z, P/V, C) as
openMSX; **differs** = a wrong result, flag or cycle count; **not
modelled** = H, N, X/Y, or a feature that is absent. "Fixed" means on this
branch. H, N, X and Y are not modelled by any group, so the table only
mentions them where it matters.

| Group | Status | Detail | Game impact | Fixed |
|---|---|---|---|---|
| LD r,r' / r,n / r,(HL) / (HL),r / A,(BC)/(DE)/(nn) / (nn),A | matches | Page crossings of immediates handled (`CheckB`/`CheckW`). | none | - |
| LD rr,nn / rr,(nn) / (nn),rr / SP,HL / IX,IY forms | matches | `LD SP,x` rebuilds A6 with `CogePagS` (ROM pages use the read pointer so `LD SP,table / POP` works). | none | - |
| LD r,(IX+d) / (IX+d),r / (IX+d),n | matches | | none | - |
| IXH/IXL/IYH/IYL (undocumented LD, INC, DEC, ALU) | differs (cycles) | Results right. Cost was 9 cycles everywhere; the ALU forms 4. Z80: 8, `LD IXH,n` 11. | none | yes |
| 8-bit ADD/ADC/SUB/SBC/CP (r, n, (HL), (IX+d)) | matches (S Z V C) | H and N not modelled; N reads as the last carry. | DAA and PUSH AF readers only | - |
| AND/XOR/OR | matches (S Z P C) | H (1 after AND) and N not modelled. | low | - |
| INC/DEC r, (HL), (IX+d) | matches (S Z V, C kept) | Bit 4 of D3 takes the INC carry, so `INC A` from FFh then `PUSH AF` shows N = 1. | low | - |
| INC/DEC rr, IX, IY, SP | matches | | none | - |
| ADD HL,rr / ADD IX,rr / ADC,SBC HL,rr | matches (S Z V C; ADD: C only) | H not modelled. | none | - |
| RLCA RRCA RLA RRA | matches (C) | H and N are left as they were (should clear). | none | - |
| CB RLC RRC RL RR SLA SRA SLL SRL (r, (HL), (IX+d)) | **differs** | S, Z, C right; **P/V = 0 instead of the parity** of the result (the 68k clears V). SLL right (shifts a 1 in). | `SRL A / JP PE`-style code: rare | no (see fix 3) |
| BIT n,r / (HL) / (IX+d) | differs | Only Z was set. Z80: P/V = Z, S = bit 7 for BIT 7, H = 1. | `BIT 7,r / JP M` or `JP PE` after BIT: rare | yes (P/V, S) |
| SET/RES | matches | The undocumented DD CB "op (IX+d),r" forms are NOPs (no memory write). | none | - |
| DAA | **differs** | Right after a tracked ADD/ADC/SUB/SBC/INC A/DEC A. Wrong after NEG, AND/OR/XOR or anything else (stale `DatDAA`), and when the operand was 0 and A is not BCD. Its S and P/V came from ABCD (undefined on a 68020+): now from the result. H not modelled. | BCD scores and `AND 0Fh / ADD A,90h / DAA / ADC A,40h / DAA` work. No known failure; `MSX Unleashed` is a suspect (open_issues). | flags yes; see fix 2 |
| CPL, NEG | matches | NEG: H not modelled (set when A & 0Fh != 0). | none | - |
| SCF, CCF | matches (C) | SCF should clear H, CCF should copy C to H: not modelled. | none | - |
| EX DE,HL / EX AF,AF' / EXX | matches | | none | - |
| EX (SP),HL / (SP),IX / (SP),IY | differs (cycles) | `EX (SP),HL` cost 4 cycles (Z80: 19). Reads 2 bytes straight across an 8 KB page end when SP = x1FFFh etc.; PUSH/POP handle that. | timing only | yes (cycles) |
| PUSH/POP/CALL/RET/RST, JP/JR/DJNZ, conditions | matches | Page crossings handled; conditions read D3 straight into the CCR. With SP in ROM a push writes into the ROM image (the read pointer is used so POP/RET can read tables); on hardware the write is ignored. No game pushes with SP in ROM. | none | - |
| LDI/LDD/LDIR/LDDR | matches (results, P/V) | A repeat runs to completion in one go (no interrupt in the middle); cycles 23 per byte as the MSX, but **capped at 7000h** (1247 bytes): a 64 KB LDIR costs 28672 cycles instead of 1.5 million, so raster-timed code after a long LDIR runs early. Writes go through the page write pointers only: an LDIR into mapper or SCC registers is not seen. | demos with long LDIRs; mapper writes by LDIR (none known) | no (fix 6) |
| CPI/CPD/CPIR/CPDR | **differs** | CPI/CPD set only Z (S missing). CPIR/CPDR cost 16 cycles for the whole search and set P/V on every match (should be BC != 0). | timing of string searches; `JP M` after CPI: rare | yes |
| INI/IND/OUTI/OUTD and repeats | matches (Z) | N (=1), H and C (the undocumented formula) and S not modelled. Repeats are atomic: an OTIR to the VDP lands at one instant, its cycles counted. | none | - |
| IN r,(C), IN F,(C) | differs | S, Z right; P/V was 0 (should be the parity). | `IN A,(C) / JP PE`: rare | yes |
| IN A,(n), OUT (n),A, OUT (C),r | matches | | none | - |
| OUT (C),0 (ED 71) | not modelled | Was a free NOP. | none known | yes |
| LD A,I / LD A,R / LD I,A / LD R,A | matches (MSX) | P/V = IFF. There is one IFF (IFF2 = IFF1 is right on an MSX: no NMI). R is synthesised from the emulated time (line, cycles, frame) plus bit 7 from `LD R,A`: random enough, repeatable, but not the M1 count. | code that times with R: none known | - |
| RLD/RRD | differs | Result right (ROM operand fixed earlier in 4.0). P/V was 0 (parity). Cost 12 (Z80: 18). | low | yes |
| DI/EI/HALT | matches | EI delays the check by one instruction (`OtraEI`). HALT leaves PC after the HALT and waits line by line. | none | - |
| IM 0/1/2 | **differs** | IM 1 and IM 2 (vector I:FFh) right. **IM 0 jumped to 0066h** (the NMI vector) instead of RST 38h: on an MSX the bus reads FFh during the acknowledge, so IM 0 behaves as IM 1 (openMSX `irq0`). A game in IM 0 never got its interrupt handler. | games that set IM 0 (rare): hang/no music | yes |
| RETI / RETN | **differs** | **RETI set IFF** (interrupts back on); a Z80's RETI leaves IFF alone. RETN = RET (right with one IFF). | code running with DI that returns through RETI: interrupts came on | yes |
| Interrupt acceptance | differs | Cost 7 cycles (Z80: 13 in IM 0/1, 19 in IM 2). Pushes PC, clears IFF, leaves HALT. Interrupts are only checked at line ends (`MiraInter`): latency up to 228 cycles, and an `EI / NOP / DI` window shorter than the rest of the line misses a pending interrupt (the Snake and Rhino race in open_issues is the other side of this). | timing-sensitive handlers; EI/DI windows | cycles yes; latency no (fix 4) |
| DD/FD before an opcode without IX/IY | matches | Re-executed as the plain opcode (`NOCO`). The prefix cost 1 cycle (Z80: 4). | none | yes (cycles) |
| Undefined ED opcodes | differs | NOPs (`NADA`) at 0 cycles (Z80: 8). ED 83/8B ran OTIR/OTDR. The NEG, RETN and IM duplicates (ED 4C, 54..7C, 55..7D, 4E, 66..7E) were NOPs. | none | yes |
| ED 10-1B | AmiMSX hooks | The disk (DSKIO...) and mouse hooks patched into the disk ROM. A program executing them gets the hook, not a NOP. | none (ROM patch convention, like openMSX's ED FE) | - |
| ED C1/C9/D1/D9/C3/F3 (and C4/CD/D5/DD) | differs | Execute the R800 MULUB/MULUW. A Z80 treats them as NOPs. Software probing for a turbo R this way would think it found one. | rare | no (fix 8) |
| Memory refresh / MEMPTR (WZ) | not modelled | MEMPTR only shows in the X/Y bits of BIT n,(HL). | none | - |
| Timing (see below) | mostly matches | Per-instruction counts checked against `Z80.hh`; the M1 wait and the prefix wait are counted; a line is 228 cycles. Errors found: EX (SP),HL, RLD/RRD, CPIR, the IXH forms, interrupt acceptance, prefix and ED NOPs, all fixed. | | yes |

### Timing checked (Z80 T-states, before the M1 waits)

LD r,r' 4; LD r,n 7; LD r,(HL) 7; LD (HL),n 10; LD r,(IX+d) 19; LD A,(nn)
13; LD HL,(nn) 16; LD rr,(nn) 20; LD rr,nn 10; LD IX,nn 14; LD SP,HL 6; LD
SP,IX 10; PUSH 11; POP 10; PUSH IX 15; POP IX 14; EX (SP),IX 23; ALU r 4,
n 7, (HL) 7, (IX+d) 19; INC r 4, (HL) 11, (IX+d) 23, rr 6, IX 10; ADD HL
11; ADC/SBC HL 15; ADD IX 15; CB r 8, (HL) 15, (IX+d) 23; BIT (HL) 12,
(IX+d) 20; JP 10; JP (HL) 4; JP (IX) 8; JR 12/7; DJNZ 13/8; CALL 17/10; RET
10; RET cc 11/5; RST 11; IN A,(n) 11; IN r,(C) 12; OUT 11/12; LDI/CPI/INI
16; repeats 21/16; NEG 8; IM 8; LD A,I 9; RETI/RETN 14; DAA/CPL/SCF/CCF/
RLCA 4; DI/EI 4. The prefix handlers subtract the second M1 wait.

## 4.3: every opcode against grauw's Z80+M1 column (24 Oct 2026, GitHub issue #2)

`tools/make_z80time.py` builds a test cartridge from the instruction table at
map.grauw.nl/resources/z80instr.php (959 cases: every documented instruction
with each register, bit and condition, taken and not taken; block
instructions with one repeat). A CYCLOG trace build (`-DTRACE=1 -DCYCLOG=1
-DTRACEPC=<end+1>`) logs each instruction's address with the line's cycles
left, and `tools/read_z80time.py` turns the drops into costs and compares
them with the Z80+M1 column.

- First run: 906 of 959 matched. Fixed: **DAA** cost only the M1 wait
  (`OtraDAA` was used without its count: 1 cycle, now 5); **DD/FD + a plain
  LD r,r'** (50 opcodes, e.g. DD 41) went straight to the unprefixed handler
  (6 cycles, now 10 through NOCO, as the other plain opcodes already did).
- After the fixes: **957 of 959 match.** The two left are **CPIR/CPDR**, a
  flat 18 for the whole search (grauw: 23 per repeat, 18 for the last). That
  is deliberate since 4.0: a per-iteration charge drove the line counter
  deep negative in the DOS directory search (disk boot hang). A capped
  per-iteration charge as LDIR's is possible but needs a disk-boot test.
- LDIR/LDDR/INIR/OTIR and the rest of the block instructions match with one
  repeat, as do the interrupt-free conditional jumps, calls and returns.
- Not covered by the table: interrupt acceptance (13/19, checked in 4.0),
  HALT, RST (they jump into the BIOS) and the undocumented opcodes.
- Line ends: an instruction that ends a line is charged correctly (+228
  per line); the trace showed no exceptions once interrupts were kept off.

## Impact on real games

- The documented S, Z, P/V and C of every common instruction match, which is
  why the library runs. The regression suite (66 titles) did not show a
  flag-related failure before this audit.
- H and N only reach a program through DAA and `PUSH AF`. DAA is covered
  by the `DatDAA` reconstruction in the common BCD cases (scores, the
  hex-digit trick); the holes are DAA after NEG or a logic operation and a
  zero operand with a non-BCD A.
- The three behaviour bugs with real reach were IM 0 (handler never ran),
  RETI (interrupts enabled behind the program's back) and the P/V after
  shifts/rotates (rarely tested by code). All are fixed or listed.
- The line-granular interrupt check is the one architectural limit a
  careful program can hit (EI/DI windows, split-timed handlers); it is
  also why the Snake and Rhino VRAM race lands differently from openMSX.
- `tools/make_zex.py --flags szpc` exercises exactly the modelled flags: on
  this branch every group should pass except `daaop` (DAA with explicit
  H/N inputs), `rotz80`/`rotx` (parity after shifts) and `r800` (MULUB).
  With `--flags doc` every group whose instructions touch H or N fails,
  which is the price of not modelling them.

## Fix list, in priority order

1. **Done on this branch** (all cheap, no hot-path cost beyond one
   instruction): BIT P/V and S; IN r,(C) parity; RLD/RRD parity and cycles;
   CPI/CPD S; CPIR/CPDR flags and cycles; DAA S/Z/P/V from the result;
   RETI; IM 0; interrupt acceptance 13/19 cycles; EX (SP),HL 19 cycles;
   OUT (C),0; the ED duplicates; ED NOP cost; ED 83/8B; DD/FD NOP cost;
   IXH/IXL cycle counts. The build is 563,844 bytes (master 563,368).
2. **H and N flags, lazily.** Every ADD/ADC/SUB/SBC/INC/DEC/CP/NEG/logic
   handler stores a kind byte (and the ones that do not already store A
   before, the operand) next to `DatDAA`; `PUSH AF` and DAA compute H and
   N from kind, A before, result and C (`H = (A ^ operand ^ result) & 10h`;
   `N` from the kind). Cost: one `MOVE.B #kind,Kind(A3)` per ALU handler,
   about 2-3 cycles on a 68030 (ALU handlers are 20-30 cycles with their
   dispatch, so under 10% on ALU-bound code, nil elsewhere); nothing extra
   until a program reads F. Then DAA can be done from H, N and C as a real
   Z80 and `DatDAA`/`Flags_DAA` go away. Gets `daaop` and the ALU groups of
   `--flags doc` passing. Medium size: about 60 handler sites through the
   `MIns` macro (`PARDAAS`/`PARDAAR` already mark them).
3. **P/V after CB shifts and rotates.** After `\1 #1,\2` in `MROT`, take
   the flags from `Flags_Par` of the result and keep C: four instructions
   (`MOVEQ #0,D1` / `MOVE.B res,D1` / `MOVE.B Flags_PAR(A3,D1.W*4),D3` /
   C insert), about 12-16 cycles on a 68030 on top of a 25-cycle handler.
   CB shifts are hot in scrolling and bit-plane code, so measure with the
   PERF build (Konami scrollers, Lilly's Saga). Rare in real code; after
   the lazy flags it could be lazy too (store the result, parity on read).
4. **Interrupt latency after EI.** In `EI`, when `PetInt38` is pending,
   save the cycle counter and clear it; the next instruction's `Otra` then
   runs into `MiraInter`, where one `TST.B` at entry detects the case,
   restores the cycles and goes to the acceptance path without advancing
   `CurLine`. One test per line in the hot path (negligible). Exact for
   `EI / NOP / DI` windows and `EI / RET`. Needs the HALT and band-split
   paths of `MiraInter` checked on WinUAE.
5. **Block I/O flags** (N = 1, H and C from the undocumented formula, S
   from B): only visible through PUSH AF; do with the lazy flags.
6. **Long LDIR/LDDR cycles.** Remove the 7000h cap by splitting a long
   copy into per-line chunks (run `MiraInter` between them, keeping the
   copy atomic per chunk), or at least raise the cap: a word counter
   limits one subtraction to 32767 cycles (143 lines). Matters for
   raster-synchronised code after big copies (demos).
7. **SCF/CCF H, X/Y flags, MEMPTR.** Only for ZEXALL purity: after the
   lazy flags, X/Y need the result byte stored per handler (1 more MOVE.B)
   and are read on PUSH AF; MEMPTR only for BIT n,(HL).
8. **R800 MULUB/MULUW as Z80 NOPs** (table entries): decide whether the
   R800 instructions are wanted; a Z80 core should not have them.
9. **R register per M1.** Not worth an ADDQ per instruction; the synthesis
   from time is random, repeatable and cheap. Leave.
10. **PUSH with SP in ROM** writes into the ROM copy; **EX (SP),HL** at an
    8 KB page end. No known game; fix only if a title shows it.

## Test ROMs: `tools/make_zex.py`

```
pip install z80                       # ZEXALL-verified reference core
python tools/make_zex.py build/zex/zex_szpc.rom --flags szpc --list build/zex/zex_szpc.txt
python tools/make_zex.py build/zex/zex_doc.rom  --flags doc  --list build/zex/zex_doc.txt
python tools/make_zex.py build/zex/zex_all.rom  --flags all
python tools/make_zex.py build/zex/zex_quick.rom --flags szpc --quick   # 29,000 cases
```

- The ROM (32 KB, plain mapper, MSX1 or MSX2, no disk) runs 45 groups and
  252,240 cases (about 3 minutes of MSX time; `--quick` drops the shifter
  vectors: 29,000 cases, 20 s) and prints, two groups per SCREEN 0 line,
  `name CRC OK` or `name CRC !!`, then `DONE nn FAIL` (nn in hex).
- The reference CRCs come from the `z80` package, so **openMSX should print
  OK everywhere** (checked here by running the ROM inside that core with a
  BIOS stub: `--selftest`). Every `!!` on AmiMSX is a core difference; the
  `--list` file names the instructions and case counts of each group.
- Flag masks: `szpc` (S Z P/V C, what AmiMSX models) is the one to keep
  green; `doc` (ZEXDOC, no X/Y) shows the H/N gap; `all` is ZEXALL.
- Not covered (interrupts are off, the BIOS prints): I/O and block I/O,
  jumps and conditions (`tools/make_z80ops.py`), HALT, LD A,R/I, EX AF and
  EXX, DAA after a specific operation (`tools/make_z80flags.py` has those
  sequences as readable single results).
- Expected on this branch with `szpc`: all OK except `daaop`, `rotz80`,
  `rotx` and `r800`. On master also `bitz80`, `bitx`, `cpi1`, `cpd1`,
  `rld` fail (fixed here).

## What to test on WinUAE and hardware

1. **Build:** `sh build.sh` (563,844 bytes). On Linux without a native
   vasm: `node tools/vasm_wasm.mjs ...` with the npm `romdev-toolchain-vasm`
   package unpacked in `tools/vasm-wasm/` (see the script header).
2. **ZEX ROMs:** `zex_szpc.rom` in AmiMSX (030 config, slot 1, MSX2) and in
   openMSX (`openmsx -cart build/zex/zex_szpc.rom`, C-BIOS is enough):
   openMSX all OK; AmiMSX `DONE 04 FAIL` with the four groups above. Then
   `zex_doc.rom` for the H/N picture (expect many `!!`).
3. **Regression:** the full tier (`python tools/regress.py full`), as
   `Docs/regression.md` asks for Z80-core changes. Watch:
   - **interrupt-timed titles**: Zanac, Zanac EX (+Enhanced), Jailbreak,
     Uridium, Uridium 2, Space Manbow, Lilly's Saga, Bun-Ga-Rua: every
     interrupt now costs 6 more cycles (12 in IM 2), so a beam-timed split
     may move by a few cycles; a one-line shift in a known-unstable
     baseline (Jailbreak, Zanac EX status bar) is the expected form;
   - **Konami SCC and MSX-Music titles** (OTIR to the PSG/VDP unchanged;
     `IN r,(C)` parity change is flag-only): Nemesis 2/3, Metal Gear,
     Salamander, Space Manbow;
   - **MSX Unleashed** (a DAA/flags suspect: see open_issues) and the
     disk demos (bold, invasion, io, akin2: MSX-DOS uses CPIR/CPI);
   - **anything that uses RETI** with interrupts off: no title is known;
     a hang at a point where music or input stops would be the symptom;
   - **DEVA and Bit Logic** (BASIC-based, DAA/BCD heavy).
4. **Hardware (PiStorm/BigMig, 030/50):** a smoke run of the same titles;
   the hot-path cost of the fixes is one extra instruction in the
   bit-clear case of BIT and in `IN r,(C)`, nothing measurable.

## Risks

- Cycle changes are small (under 20 cycles per instance, 6 per interrupt)
  but Z80-visible: beam-timed splits in the unstable titles may move by a
  line, so baselines need a look rather than a blind accept.
- RETI no longer enables interrupts: correct, but a title that only ran on
  AmiMSX because of it would stop; none is expected (such a title would
  fail on hardware).
- `IM 0` now equals IM 1; a program that relied on the old jump to 0066h
  cannot exist (the BIOS NMI stub returns without doing anything).
- The CPIR/CPDR cycle count is new code on a cold path; a BC = 0 search
  costs the capped 7000h cycles, as LDIR.
- Nothing in this branch touches the VDP, mappers or sound.

Affected regression titles: the whole suite executes the changed handlers
(BIT, IN r,(C), interrupts), so `tests/titles.csv` as a whole; the titles
named above are where a difference would show first.
