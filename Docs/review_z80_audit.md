# Review R3: Task A, Z80 core audit fixes (15 Oct 2026)

Branch reviewed: `origin/claude/amimsx-4-0-beta-67rw54` (commit 84bcf3c, author A3): `Docs/z80_audit.md`, the core changes in `AmiMSX_Main_v3.1.asm`, `tools/make_zex.py`, `tools/vasm_wasm.mjs`, and the README/CHANGES/open_issues lines. This review branch, `review/z80-audit`, is that commit plus this document.

What was done here:

- every changed handler read against openMSX 21.0's `CPUCore.cc` and `Z80.hh` from the repository's `ref/openmsx` branch (the audit's own reference), including the timing constants, which in openMSX already include the MSX M1 wait (CC_NOP = 5);
- the branch assembled with the WebAssembly vasm 2.0e (no errors, the same 13 warnings as master, 563,828 bytes; the audit's 563,844 is the same code with a different build-id string);
- `tools/make_zex.py` run here with the `z80` PyPI package (1.2.0, binary wheel): the quick and the full ROMs generate and pass their self-test (`DONE 00 FAIL` in the reference core, 252,240 cases), and the reference core itself was spot-checked on 15 documented Z80 flag cases (DAA, CCF/SCF X/Y, BIT with X/Y from the operand, BIT n,(HL), LDI, CPI, RLD, IN r,(C), NEG, ADD overflow, SRL, CPL): all as documented;
- the flag translation tables (TAB_Flags: Flags_Par, Flags_Push, Flags_Pop) read, and the audit's description of them confirmed (push: 68k C, V, Z, N, X to Z80 C, P/V, Z, S, N; pop the reverse, bits 3-5 round-tripped).

Not done: no WinUAE or hardware run (none here); the regression tiers in the audit's test plan remain for the maintainer.

## Verdict

The branch is sound. Every behaviour change matches openMSX and the Z80, the expected results of the test ROM come from an independent ZEXALL-passing core and not from AmiMSX, and the hot-path cost is nil. Two one-cycle nits and one documentation point are listed below; none blocks a merge. Merge in the groups of section 4; the only changes with real reach into games are RETI, IM 0 and the interrupt cost, and those are the ones to watch in the full regression.

## 1. The handlers, one by one

| Change | openMSX / Z80 | Verdict |
|---|---|---|
| BIT n,r / (HL) / (IX+d): P/V = Z, S for bit 7 (OtraB, OtraB7) | Z80: Z = !bit, P/V = Z, S = bit 7 when n = 7, H = 1, N = 0 | Correct. The CCR Z used by the BEQ comes straight from the BTST in every MIns form (no CCR-changing instruction between). X/Y and H not modelled, as stated |
| IN r,(C), IN F,(C): S Z from the byte, P/V = parity, C kept (MINC) | `in_R_c`: `f = (F & C) \| ZSPXY[res]` | Correct. ED 70 (IINFC) goes through the same macro |
| RLD/RRD: S Z P from A, C kept; 18 cycles | `rld`: `(F & C) \| ZSPXY[A]`; CC_RLD = 20 incl. the wait | Correct: 18 + 1 (Otra) + 1 (ED prefix) = 20 |
| CPI/CPD: S Z from A - (HL), P/V = BC != 0, C kept | BLOCK_CP: ZS[res], V = BC != 0, C kept (plus H, N, X/Y) | Correct; 16 + 2 = 18 = CC_CPI |
| CPIR/CPDR rewrite: flags of the last compare, P/V = BC != 0, 23 cycles an iteration, last 17 + waits | BLOCK_CP: CC_CPIR = 23 while repeating, CC_CPI = 18 for the last | Flags and BC right (match at iteration k leaves BC - k; exhaustion leaves 0; BC = 0 searches 65536). **Nit:** the last iteration counts 17 + 1 + 1 = 19 against openMSX's 18, one cycle high per CPIR/CPDR. `Otra 16` would match (LDIR's `Otra 5` ends 23 BC - 5, exactly openMSX's). The $7000 cap copies LDIR's |
| DAA: S Z P/V from the result, C from ABCD/SBCD (OtraDAA) | `daa`: `f &= C \| N; f \|= ZSPXY[a]; C \|= A > 99h; H` | Correct for S, Z, P/V, C; ABCD's N and V are undefined on a 68020, so the old OtraT was wrong. Minor: the 68k X bit (pushed as the Z80 N) is now dropped after DAA; the Z80 keeps N. Neither state was right; nothing reads it |
| RETI: no longer sets IFF | `retn() // also reti`: IFF1 = IFF2 | Correct: with AmiMSX's single IFF, IFF1 = IFF2 is "unchanged". The old `ST IFF` could only help a program that would fail on hardware |
| IM 0: RST 38h instead of 0066h | `irq0`: `assert(readIRQVector() == 0xFF); PC = 0x0038` | Correct |
| Interrupt acceptance 13 (IM 0/1), 19 (IM 2) | CC_IRQ0 = CC_IRQ1 = 7+3+3 = 13, CC_IRQ2 = 19 (waits included) | Correct to the cycle (the path uses Otra2, which adds no wait) |
| EX (SP),HL 19 | CC_EX_SP_HL = 20 | Correct (19 + 1) |
| OUT (C),0 (ED 71) | `out_c_0` | Correct: D1 = 0 is the value register of the OUT port handlers (MOUTC loads D1), D2 the port |
| ED duplicates: NEG at 4C/54/5C/64/6C/74/7C, RETN at 55/5D/65/6D/75/7D, IM 0 at 4E/66/6E, IM 1 at 76, IM 2 at 7E | the same case lists | Correct |
| Undefined ED opcodes: 8-cycle NOP (EDNOP), ED 83/8B no longer OTIR/OTDR | openMSX: `nop()` = CC_NOP = 5 | Behaviour right (openMSX runs `nop()` for them too, and for the R800 MULUB/MULUW slots on a Z80). **Cycle count differs from openMSX:** AmiMSX now 8 + 2 waits = 10, openMSX 5. A real Z80 takes two M1 cycles (8 T) for an undefined ED, so the branch follows the hardware and openMSX simplifies. No program executes these in a loop; note it in the audit so that a future ZEX timing comparison is not misread |
| DD/FD before an opcode without IX/IY: 4-cycle NOP (NOCO) | `nop<T::CC_DD>()`: CC_DD = 5 then the opcode at full cost | Correct: 4 + the prefix's wait + the opcode's own count |
| IXH/IXL/IYH/IYL: LD 8, LD xH,n 11, INC/DEC 8, ALU 8 (were 9, 9, 9, 4) | CC_DD + the plain form: 5+5 = 10, 5+8 = 13 | Correct (8 + 2 = 10, 11 + 2 = 13). The ALU forms were 6 cycles short before |
| INSED table | | Checked entry by entry against the case lists; ED 10-1B stay AmiMSX's hooks, ED 00 its own, ED 17 is now an 8-cycle NOP (was a 0-cycle one; the "Usado" note refers to a marker, nothing depends on its cost) |

Register invariants: the new `Flags_PAR(A3,D7.W*4)` lookups (DAA, RLD/RRD) rely on bits 8-15 of D7 being zero, which OtraP (every AND/OR/XOR) already relies on; MINC masks D1 to a byte before indexing; `BlkBC` is a data word in the code section, written with the data path only (no self-modifying code, no cache issue); `SUB.W D1,(A3)` with up to $7000 is LDIR's own pattern. D1's high word is left as the core wants it in every changed handler.

Timing-sensitive consequences, for the regression: an interrupt costs 6 (IM 1) or 12 (IM 2) cycles more, so a line-interrupt handler's first write lands 6 cycles later in its line (a line is 228): a split can only move by a line in a game whose write already sat on a line boundary. CPIR/CPDR searches of n bytes cost 23 n - 4 instead of 16: MSX-DOS and BASIC use them on short strings. EX (SP),HL costs 15 more, RLD/RRD 6 more, the IXH forms 1 less or 4 more. The M1-wait model is untouched: Otra adds one wait per handler, the prefix dispatchers one each, as before.

## 2. The ZEX generator

- **Provenance of the expected results.** `reference()` computes every group's CRC by running the same vectors in `z80.Z80Machine` from the `z80` PyPI package (Ivan Kosarev's emulator; its README lists `zexall`, `zexdoc`'s cousins `cputest`, `8080exer`, `prelim` as passing). Nothing in the script reads AmiMSX's code or output. The 15 spot checks above agree with the documented Z80 on the hard cases (DAA after SUB keeps N and gives the parity of the result; CCF copies C to H and takes X/Y from A; BIT n,(HL) takes X/Y from MEMPTR; NEG's H from the low nibble; CPI's X/Y from A - (HL) - H).
- **The ROM.** A plain 32 KB cartridge (AB header, INIT at 4010h) that maps page 2 to its own slot, uses C000h-C2FFh and the BIOS CHPUT/INITXT, interrupts off; runs on C-BIOS and on AmiMSX (MSX1 or MSX2, slot 1). The engine mirrors the Python run exactly: the registers come off a 16-byte vector by POPs, SP is the vector's, the instruction is followed by a JP, the result record is memop, IY, IX, HL, DE, BC, F (masked), A, SP, CRC-32 reflected. The `--selftest` runs the ROM in the reference core and checks its CRCs against the Python ones: passes for `--quick` and the full ROM, `szpc` and `doc`.
- **Coverage notes.** `ednop` and `edim` have the same CRC by construction (an IM change is invisible with interrupts off: the group only shows that IM n leaves the registers alone), which the listing should say. The `r800` group fails on AmiMSX by design (MULUB executes), `daaop`, `rotz80` and `rotx` by the stated gaps; that is the expected `DONE 04 FAIL` on this branch, and the audit's claim that master also fails `bitz80`, `bitx`, `cpi1`, `cpd1` and `rld` follows from the fixes. Not covered, as the script says: I/O, block I/O, jumps and conditions, HALT, LD A,R/I, EX AF, EXX, interrupts and all timing.
- **Practicality.** Generation takes 8 s here; the ROM is 3 minutes of MSX time; `--quick` 20 s. `pip install z80` needs the binary wheel (the source build wants setuptools from the network); fine on the maintainer's PC.

## 3. Documents and tools

- `Docs/z80_audit.md`: accurate against the code and openMSX in every point checked; add the two notes above (undefined ED cost against openMSX; `edim` = `ednop`). The fix list and priorities are reasonable; fix 2 (lazy H/N) and fix 4 (EI latency) are the two with game-visible value, fix 3 (CB parity) is cheap but on a hot path and should be measured as it says.
- `tools/vasm_wasm.mjs`: a second WebAssembly-vasm wrapper (`Docs/sprite_ghosting.md` describes the one used on the cloud branches, kept out of the repository there). This one is in the tree, documented in the README and git-ignores its package directory: keep it, and the other branches can point at it.
- CHANGES, README and open_issues lines: correct.

## 4. Risk ranking and merge groups

Group A, flags only, no timing, no reach into working games (merge first, smoke tier):

1. BIT P/V and S.
2. IN r,(C) and IN F,(C) parity.
3. RLD/RRD parity (the cycle part belongs to group C; it can go with this one, 6 cycles on a rare instruction).
4. CPI/CPD S and P/V.
5. DAA S, Z, P/V from the result.
6. OUT (C),0; the ED NEG/RETN/IM duplicates; ED 83/8B no longer OTIR/OTDR; undefined ED as NOPs.

Group B, behaviour with reach, correct, could expose a game that only ran because of the old behaviour (merge second, full tier, watch the titles the audit names):

7. RETI leaves IFF alone: a title that returned from an interrupt through RETI without EI and relied on interrupts coming back would hang or lose music; such a title fails on hardware, none is known.
8. IM 0 goes to 38h: a game in IM 0 now gets its handler for the first time; games that set IM 0 are rare and their handlers never ran before, so new behaviour is possible (music starting, timing changing).

Group C, timing (merge third, full tier; baselines of the beam-timed titles may move by a line):

9. Interrupt acceptance 13/19 (the one with a per-frame effect: every interrupt).
10. EX (SP),HL 19; IXH/IXL forms; DD/FD NOP 4; ED NOP 8.
11. CPIR/CPDR per-iteration cycles (and the flag rewrite that comes with it, since it is one block of code): a cold path, but new; with the one-cycle nit fixed if the maintainer wants exact LDIR-style totals.

Group D, no runtime effect: `tools/make_zex.py`, `tools/vasm_wasm.mjs`, `.gitignore`, the documents.

If the branch is merged as one commit instead, the full tier once is enough; the grouping is for finding which change a changed capture belongs to.

## 5. Nits to fix (none blocking)

1. `CPIR`/`CPDR`: `Otra 17` to `Otra 16` for the last iteration (23 n - 5 as openMSX and as LDIR).
2. `Docs/z80_audit.md`: say that openMSX charges 5 cycles for an undefined ED opcode (`nop()`) while the branch charges 10 as the hardware does; and that `edim` and `ednop` share a CRC because IM n is invisible to the test.
3. Optional: `OtraDAA` could keep the 68k X bit (`AND.B #$11,D3`) so that a PUSH AF after DAA shows the same N as before the branch; irrelevant until H and N are modelled.

## 6. Test plan (as the audit's, with the order of section 4)

1. Group A alone on the smoke tier: identical captures expected (flag changes that no title's code path reads).
2. Groups A+B on the full tier: identical captures expected; a difference points at RETI or IM 0 in that title.
3. Groups A+B+C on the full tier: the beam-timed titles (Jailbreak, Zanac EX, Uridium, Uridium 2, Space Manbow, Lilly's Saga, Bun-Ga-Rua) may move a split by a line; MSX Unleashed, DEVA, Bit Logic and the disk demos (CPIR in DOS) are the ones to look at by eye.
4. `zex_szpc.rom` in openMSX (all OK) and in AmiMSX (`DONE 04 FAIL`: daaop, rotz80, rotx, r800); `zex_doc.rom` for the H/N picture.
