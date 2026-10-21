# Agent workflow

*Reading notes.* AmiMSX 4.1.2 was largely made by AI coding agents, each given one fault to investigate, with a human owner who tests on the real machines, decides what ships and does every publishing step. These sections record what worked and what went wrong. Commit references name the AmiMSX development repository; the public repository carries squashed commits.

## Briefing an agent: one track, evidence, WIP commits

### One track per agent, with the evidence and the rules in the brief

**Problem.** An agent starts with no memory of the project. A vague task ("fix the display bugs") produces a long, unreviewable change; a task without the rules produces fixes that break conventions the code depends on (chapter 03: no stack in handlers) or touch things the agent must never touch (publishing).

**Before.** A broad request with the source tree.

**After.** A brief with the same parts every time (the shape used for AmiMSX; names are examples):

```
Track:     barbarian  (branch agents412/barbarian)
Symptom:   fighters flicker on the PiStorm; not seen in WinUAE captures.
           Seen on build <date and commit from the menu title>.
Evidence:  tester's photos <path>; reference-emulator logs <path>;
           earlier notes: Docs/open_issues.md (Barbarian row)
Read first: README.md, Docs/CHANGES_4.x.md, Docs/open_issues.md, Docs/regression.md
Rules:     branch only: never push the master, never open pull requests,
           never publish anything.
           Handlers must not use BSR/JSR or the stack: A7 points at the Restas
           tables, not a stack.  D1 and A4 are scratch; D1's high word stays zero.
           Sources are Latin-1: keep that encoding.
           Reference emulator with the free C-BIOS ROMs only; never download
           commercial ROMs.
           WinUAE only under the lock (next section).
Deliver:   Docs/agent_notes/<track>.md: Step 1..n with evidence paths, Status,
           Next.  Commit after every step.
```

*Source: AmiMSX development brief and common rules, October 2026 (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** One fault is a size an agent can finish, and a reviewer can read, in one go. The evidence (a photo, a log, the build reference from chapter 06) means the agent starts from the symptom and not from a guess. The rules are the project's hard-won conventions; every one of them is there because breaking it once cost a day. Keeping agents off commercial ROMs and off publishing is a rule, not a hope: agents work only with the free C-BIOS ROMs and the project's own test ROMs, so nothing that cannot be shared ends up in a repository or a report, and publishing is a human decision (chapter 07). In practice agents that could not run the emulator (a cloud session with no Amiga emulator) were told to build, to leave test instructions, and to say what regression titles a change touches.

**Evidence.** Between 14 and 21 Oct 2026 the project accumulated 24 agent branches: about a dozen tracks (Barbarian, Uridium 2, Gradius III's scroll and its power meter, colours, the edge mask, Manbow 2, the MSX2+ display, Bit Logic's magnified sprites, the CD32 pad, Lilly's Saga) and, for most, a review branch (below). Each ended with a notes file, and the notes of the 4.1.2 tracks are the source of most lessons in chapters 02 and 03. The lead merged the branches into the 4.1.2 line after the regression.

**Look up.** `Docs/agent_notes/` (notes per track; private copy), `Docs/open_issues.md`, the brief and rules in the project's task prompts.

### Commit after every step, with the notes, so a cut-off loses one step

**Problem.** On 19 Oct 2026 a wave of agents hit the plan's usage limit mid-work. Anything uncommitted would have been lost.

**Before.** An agent works for an hour on the working tree and commits at the end.

**After.** The rule for every agent: commit work in progress, plus its notes, after every step. Notes are written as dated steps, each with its evidence, and they end with the state and the next action:

```
## Step 2 (19 Oct): root cause found (two layers)
- Experiment B (full SCREEN 5 reconversion at every entry): identical to experiment A.
  So SCR0 is a faithful conversion of VRAM: VRAM itself lacks START.
- Layer 1 (general bug): ...  Fixed in ModoGfx6/8 ...  Build MB2c.
...
Next: the planar mapping for SCREEN 7/8 is a design-size change; not started.
```

When an agent was cut off anyway, the lead committed what was on disk with a message that says so, instead of cleaning it up:

```
WIP (agent cut off by the session limit, 19 Oct 2026): uncommitted work saved as-is, not reviewed or tested
```

*Source: AmiMSX development repository, commit messages and Docs/agent_notes (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The notes are the handover: a new agent (or the owner) can start from "Next". The honest label on the WIP commits keeps unreviewed code from being mistaken for reviewed code, and the next agent can judge it (one of them did: "WIP 53cb3ef judged: builds; pair-split regression noted").

**Evidence.** Two WIP commits (53cb3ef, d3b9c13) were saved from the cut-off of 19 Oct. One was judged later in the MSX2+ notes ("builds; pair-split regression noted"). The later waves (below) finished without a cut-off.

**Look up.** Commits 53cb3ef, d3b9c13; coordination rule 4 ("Agents commit work-in-progress plus notes after every step").

## Sharing WinUAE and the A1200: the lock and the coordination file

### A lock made with `mkdir`, and the one-character mistake that deleted another session's lock

**Problem.** Several sessions (two emulators and an FPGA core project) shared one WinUAE installation and one physical A1200. Two WinUAE runs at once corrupt each other's captures and configurations.

**Design.** The lock is a directory. `mkdir` is atomic: it succeeds for exactly one taker. Rules: check that no emulator process is running; `mkdir` the lock; if it fails, do not run and retry every 60 s, giving up after 20 min; hold it at most 15 min (split a long tier into several holds); take it right before a run and remove it right after, never while reading or thinking; a lock older than 30 min with no emulator process is stale and may be removed first.

**Before** (what an agent wrote, twice on 19 Oct 2026, in the Uridium 2 track):

```
mkdir build/winuae.lock && <run> ; rmdir build/winuae.lock
```

**After** (`Docs/agent_notes/winuae_lock.md`):

```
mkdir build/winuae.lock && { <run>; rmdir build/winuae.lock; }
```

*Source: AmiMSX development repository, Docs/agent_notes/winuae_lock.md (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** With `;`, the `rmdir` runs after a failed `mkdir` too, and removes the lock that another session holds. This happened twice in one track; it was harmless both times, but it defeats the lock. Chain the run and the removal behind the `mkdir`, so only the taker removes. In a script, take the lock first and then set `trap 'rmdir build/winuae.lock' EXIT`, so an error or an interrupt releases it. The 15-minute limit follows from the cost of the tiers: the smoke tier takes about 50 minutes, so it is run in three chunks of five titles, each under its own lock, and the regression tool does not take the lock itself (the caller does).

**Evidence.** A lock directory created by an agent vanished before the agent removed it, so another session may have run in parallel and its captures were treated as suspect. A lock stayed held by a force-ended session for 40 minutes with no WinUAE running, which is why the stale rule exists. After the rules were written, the overnight queue of 21 Oct ran five agents in turn with the lock released after each (coordination file, "Done").

**Look up.** `Docs/agent_notes/winuae_lock.md`; `winuae/` (the configurations); the coordination rules below.

### The coordination file

**Problem.** Sessions on different projects use the same plan allowance, the same WinUAE and the same A1200, and cannot see each other.

**After.** One plain file, read by every session before starting and edited after: a **Running** table and a **Done** table.

```
## Running
| Session | Job | Agents | Started | Expected end |
| core project | FPGA core build (CPU-heavy, no agents) | 0 | 21 Oct ~08:30 | ~10:00 |

## Done
| Session | Job | Ended | Notes |
| MSX project | 4.1.2 beta release (full regression, LHA in WinUAE, upload, GitHub) | 21 Oct 08:20 | lock released |
```

with these rules:
1. Before an agent wave or any long job, check the usage; launch only if the 5-hour window is under about 50%, and check the file for other sessions' running jobs.
2. Announce heavy jobs: add a line under Running when you start, move it to Done when it ends; message the other sessions if you start a wave.
3. At most 2 agents at a time across all sessions if possible; prefer one session's wave at a time.
4. Agents commit work in progress plus notes after every step.
5. WinUAE: the lock directory.
6. Real hardware (the A1200, a FPGA board): one session at a time; announce long jobs; tell the owner before anything runs on the screen.

*Source: AmiMSX / Arnold shared coordination file, October 2026 (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The coordination file costs nothing and replaces a meeting. Its Done table also records what each job left behind (branches, test builds, whether the lock was released), which is what the next session needs.

**Evidence.** Over 20 and 21 Oct three sessions (two emulators and an FPGA core) used one WinUAE, one plan allowance and one A1200. The Done table records no clash, apart from one lock removed by mistake for a few seconds and restored at once.

**Look up.** The coordination file itself (outside the repositories); chapter 06, "Real hardware over the network".

## Usage budgets and cut-offs

### Check the plan's usage before launching, and run agents in turn

**Problem.** All sessions share one plan allowance with a 5-hour window and a weekly limit. On 19 Oct 2026 a wave of three agents working in parallel used a whole 5-hour window in under an hour and was cut off mid-work.

**Before.** Three agents started at once on three tracks.

**After.** The rules in the previous section: check the usage first and launch only under about 50%; no more than two agents at once; announce the wave; and a fixed order of work, one agent at a time, for the long queues.

**Why.** Parallel agents multiply the token rate, but the window is fixed. A window that runs out stops every session, including the human's. Running in turn costs wall-clock time but not work, and with the commit rule a cut-off loses at most one step.

**Evidence.**

| Wave | Shape | Result |
|---|---|---|
| 19 Oct, morning | 3 tracks in parallel | cut off by the 5-hour limit; work saved as WIP commits on branches |
| 19 Oct, afternoon | 5 agents, sequential, 2 at most at once | both tracks fixed and reviewed by about 13:30 |
| 20 to 21 Oct, night | 5 agents, one at a time | finished about 03:10; five branches, nothing merged, lock released |

**Look up.** The coordination rules (previous section). The standing instruction to every session: check plan usage before and during long sessions, stay within the allowance, and pause at natural stopping points.

## Peer review rounds

### Investigate, review, revise: a second agent that sees only the code

**Problem.** An agent that has found a cause and written a fix is convinced by its own account. The first version of a fix can be wrong in ways the author's tests cannot show.

**Process.** Each track has two phases on two branches. The first agent investigates and fixes (`agents412/bitlogic`). A second agent is given the diff and the notes, not the first agent's conclusion, and reviews it by reading and by building (`agents412/bitlogic-r2`). A review states what it checked (every changed handler against the reference core's source, the assembly warnings against master, a re-run of the test generator), a verdict, and numbered required changes. The reviser applies them with their own commits and notes.

**Before** (commit 36ab7bc, magnified sprites; `AmiMSX_Main_v3.1.asm`). The toggle that says which of two sprite copies was written last lived in the byte just before the slot, which is inside the previous slot's DMA data:

```
	NOT.B	-3(A1)			; The other copy (SPRCOPIA).
```

**After** (commit 5454189, the review's change):

```
MagCopy:	DS.B	256		; Per 16x16 slot or 8x8 pattern: the copy written last
...
	LEA	MagCopy,A6		; The slots' copy bytes (4 apart).
...
	NOT.B	(A6)			; The other copy (SPRCOPIA).
	ADDQ.W	#4,A6
```

*Source: AmiMSX 4.1.2, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The sprite hardware reads the toggle byte as part of the previous slot's end control words, so whenever slot n's alternate copy was current, slot n-1 ended with a position of `$00FF` or a control word of 0. The first agent's captures did not show it, because the visible effect depended on sprite engine corner cases (a sprite starting and stopping on one line). The reviewer found it by reading the layout and moved the byte into a separate table of its own. The same review padded the sprite table so that a sprite at line 241 reads and marks its own padding and not the next slot.

**Evidence.** Reviews in this project changed the code every time they were asked: the magnified-sprite review (3 changes), the interrupt review (one required change, the order of line and vertical-blank interrupts, chapter 03), the CD32 review (pin 6 driven high first, chapter 05), the bitmap-split review (pointers before colours, chapter 02) and the Z80 audit review (a verdict of sound, with two one-cycle nits). The reorder in the interrupt review changed none of 21 captures on 7 titles (pixel-identical to the first version), which is what a correct review of a correct fix should show.

**Look up.** Branches `agents412/*-r2`; commits 5454189, cd0d46b, f56a81b, 22b4fbb; review documents `Docs/review_*.md`.

## Driving the real A1200 (see chapter 06)

*To be written (Arnold).*
