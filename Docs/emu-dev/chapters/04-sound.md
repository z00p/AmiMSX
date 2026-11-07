# Sound

## Paula output paths and the AUD0 interrupt storm on NTSC

*Reading notes (Arnold).* Arnold's sound is the Amstrad's AY-3-8912 sound chip (the PSG) mixed in the core, then converted to Paula samples. The core makes one block of 444 samples per CPC frame (about 22.2 kHz at 50 frames a second), so the frame rate and the sound rate are locked together.

### Two ways of feeding Paula, and what the display decides

Arnold feeds Paula in one of two ways, chosen when the display opens:

- **50 Hz display (PAL).** The emulation runs one CPC frame per vertical blank. A VBlank server feeds Paula with period 160 (a PAL crystal makes 444 samples last 20.03 ms).
- **Any other display (NTSC, forced 60 Hz).** The game speed "50 Hz (correct)" is paced by `timer.device` instead: each frame is due one sound block after the last, and `ChangeScreenBuffer` shows it at the next VBlank, so one frame in five is shown twice. Paula is fed by channel 0's own block interrupt (`INTB_AUD0`, set with `SetIntVector` and restored on close). The period comes from the machine's real clock, 5 x `ex_EClockFrequency`: 160 on a PAL machine (20029 microseconds a frame), 161 on an NTSC crystal (19970 microseconds). The frame time is set to exactly one block, so sound and emulation never drift apart. A "display speed" setting keeps one frame per VBlank (59.8 frames a second on NTSC) for people who prefer smooth scrolling to correct speed.

### With the audio DMA off, an enabled AUD0 interrupt does not stop

**Problem.** After playing a game on an NTSC display, pressing Help to open the menu gave a sheared, half-drawn menu, and in WinUAE the program dropped to 15.9 frames a second. PAL was never affected, because on 50 Hz Paula is fed from the VBlank, not from the AUD0 interrupt.

**Before** (`amiga_sys.c`, `Sys_AudioPause`, before commit eed6af8): switch the audio DMA off and leave `INTENA` for AUD0 on.

**After** (commit eed6af8):

    /* Sys_AudioPause: the interrupt goes off with the DMA */
    if (aud_mode) custom.intena = INTF_AUD0;     /* disable */
    if (aud_mode) custom.intreq = INTF_AUD0;     /* clear a pending request */
    ...
    /* Sys_AudioQueue, when the DMA starts again */
    if (aud_mode) custom.intreq = INTF_AUD0;
    if (aud_mode) custom.intena = INTF_SETCLR | INTF_AUD0;

*Source: Arnold-m68k 1.0, `arnold/src/amiga/amiga_sys.c` (GPL-2.0, derived from Kevin Thacker's Arnold).*

**Why.** With the DMA off, Paula drops to manual mode and raises AUD0 every sample period once the handler has cleared the request. That is about 22,000 level-4 interrupts a second for as long as the menu is up, and they hold off the level-3 VBlank work of graphics.library and Intuition.

**Evidence.** A counter in the handler (`Sys_AudioIrqs`, logged when the menu opens and when an item is chosen): before, 880 on entering the menu and 70,096 when Continue was pressed. After: 251 and 251. The menu then draws completely at 59 frames a second. WinUAE never showed the shear itself; the storm is the NTSC-only difference that it did show. On the A1200 the storm also goes through Emu68's interrupt handling.

**Look up.** Commit eed6af8; `Sys_AudioPause`, `Sys_AudioQueue`; `DISPLAY-UI.md`; the `HELPAFTER=n` test argument presses Help after n frames. AmiMSX restores INTENA, INTREQ, DMACON and the vectors before its menu runs, which avoids the same trap (chapter 02, "Leaving the machine as you found it").

## AY band-limited rendering: averaging vs point sampling

### Square waves must be averaged over each output sample, not sampled at one point

**Problem.** Players found Arnold's sound harsh, most on the Plus games with bright music (Sonic GX, Burnin' Rubber, Ghouls'n Ghosts GX, Puzzle Bobble), less on a plain 6128 game (Pinball Dreams). There was a fizz between the notes.

**Before** (`psgplay.c`, Arnold-m68k 0.8): the PSG was evaluated once per 22.24 kHz output sample, at a single instant, so every square wave was point-sampled. Harmonics above 11 kHz folded back into the audible band.

**After** (`psgplay.c`, `audioevent.c`, commit 3756b22, switch `NO_SNDAA`): each output sample is the time-weighted average of the PSG over its 45 microseconds. Each tone tracks the share of the span it is high; a register write splits the sample at its own time:

    /* AudioEvent_TraverseAudioEventsAndBuildSampleData */
    if (Fe > SpanPos) {                       /* an event inside this sample */
        Sp = Fe - SpanPos;
        L = PSG_RenderSpan(Sp, &R);           /* render up to the event ... */
        AccL += L * Sp;  AccR += R * Sp;      /* ... weighted by its length */
        SpanPos = Fe;
    }
    /* PSG_ToneSpan: high time over a span = whole half-periods plus the
       partial first and last ones, as a fraction 0..32768 */

*Source: Arnold-m68k 1.0, `arnold/src/cpc/audioevent.c`, `psgplay.c` (GPL-2.0, derived from Kevin Thacker's Arnold).*

**Why.** A square wave has harmonics without limit. Taking one point per sample aliases them; averaging over the sample is a box filter, the most a 22 kHz sample can do without changing the rate. Register writes must land at their own time inside the sample, or a volume register written at the line rate (Puzzle Bobble writes R9 every scan line, 15.6 kHz) jitters. None of this was "lost writes": we checked, and every write is applied in its own 45 microsecond sample.

**Evidence** (headless WAV through the Amiga conversion; level of the 8 to 11 kHz band relative to the 200 to 2000 Hz band, dB; the reference is a box-averaged render of the same register writes):

| title | 0.8 | after | reference |
|---|---|---|---|
| Sonic GX title | -16.1 | -21.7 | -21.7 |
| Pinball Dreams | -13.4 | -17.4 | -17.7 |
| Ghouls'n Ghosts GX | -14.1 | -18.0 | -18.2 |
| Burnin' Rubber | -10.1 | -12.5 | -12.6 |
| Puzzle Bobble | -14.1 | -15.8 | -15.7 |

Every band of every title is within about 0.3 dB of the reference. The spectral floor (the 10th percentile of the 3 to 10 kHz bins, "noise between the notes") of the Sonic title fell from -45.6 to -51.8 dB. Cost: on x86 the sound code went from 0.03 to 0.05 s of a 1.0 s run; on the A1200 the core time was 12.60 and 12.42 ms against 12.69 and 12.34 ms, within noise.

**Look up.** Commit 3756b22; `SOUNDQ.md`; `NO_SNDAA`. The 8-bit Paula output and the 16-bit values before conversion agree within 0.1 dB in every band, so 14-bit output was not needed.

## Envelopes, noise rate, volume tables and 16-to-8 clipping

### A lookup table indexed past its end read another variable (crackle)

**Problem.** Loud chords crackled on the Amiga (Ghouls'n Ghosts GX, Puzzle Bobble and Pinball Dreams), and the recordings made with the headless test host did not show the same data.

**Before** (`audioevent.c`, `AudioEvent_ConvertToOutputFormat_16BitStereo`, Arnold-m68k 0.8):

    pDestAudioPtr[0] = VolumeLookup16Bit[PSG_LeftVolume];   /* 32 entries */

but `PSG_LeftVolume` is the mixed byte, 4 to 252.

**After** (commit 3756b22, switch `NO_SNDLUT_FIX`):

    /* linear for every value: byte << 7, plus the 7-bit fraction left by the
       sub-sample render in the spare bytes 2 and 3 (0..32383) */
    pDestAudioPtr[0] = (unsigned short)((PSG_LeftVolume << 7) | (pSrcAudioPtr[-2] & 0x7f));

*Source: Arnold-m68k 1.0, `arnold/src/cpc/audioevent.c` (GPL-2.0, derived from Kevin Thacker's Arnold).*

**Why.** On the Amiga build the next table in memory (`Digiblaster_Lookup16Bit`, which is linear) happened to follow, so indices of 32 and above played correctly by luck. Indices below 32 (two loud channels on one side, both low at the same moment) gave `i << 10`, so the loudest negative peaks became large positive spikes. On x86 the same read hit other variables, so the earlier headless recordings were not what the Amiga played.

**Evidence.** Share of samples hit: Ghouls'n Ghosts 2.30%, Puzzle Bobble 0.29%, Pinball Dreams 0.24%, Sonic GX and Burnin' Rubber 0. Signal to error of the Amiga mapping against the intended linear one: 4.7, 9.7 and 11.1 dB for the first three.

**Look up.** Commit 3756b22; an indexed table needs a bounds check or an assertion in the test host. A related find from the Paula dump: the first audio block was uninitialised memory (`SamplesToGenerate` still 0 at the first conversion; WinUAE showed 0xDEDE), a click at start (commit 2d2e90c).

### The hardware envelope: wrong patterns, wrong rate

**Problem.** Ghouls'n Ghosts GX uses envelope shapes 8 and 15 with envelope periods 2 to 53 for buzz bass and drums. The bass was an octave high, and the drums did not decay.

**Before** (`psgplay.c`, 0.8):

    pEnvelope = &EnvelopePatterns[EnvelopeTimes16 + (EnvelopeTimes16<<1)];   /* shape x 48 */
    EnvelopeUpdate.FixedPoint.L = Update.FixedPoint.L/Period;                /* tone rate */

The table has 32-byte patterns, so shapes 8 to 15 used the wrong pattern and 11 to 15 read past its end. The decay table was overwritten with the attack values, so a falling ramp played as a rising one. One-shot and hold shapes restarted every 32 steps. The steps ran at the tone toggle rate, 125000/EP.

**After** (commit 3756b22, switch `NO_SNDENV_FIX`):

    pEnvelope = (char *)&EnvelopePatterns[EnvelopeTimes16<<1];   /* 32 bytes a shape */
    EnvelopeUpdate.FixedPoint.L = Update.FixedPoint.L/(Period<<1);   /* 1 MHz / (16 EP) */
    if (PositionInEnvelope > 31 && !EnvelopeRepeats) PositionInEnvelope = 31;

Patterns are rebuilt from the datasheet: 16 steps of the first ramp, then 16 steps of "level 0", the hold level, the same ramp or the reverse ramp, by the continue, attack, alternate and hold bits.

**Why.** The AY steps its envelope at 1 MHz / (16 x EP), half the rate at which a tone toggles (1 MHz / (8 x TP)). Using the toggle rate made every envelope sound an octave high.

**Evidence.** The envelope and noise were checked by the band comparison (next section), not by ear: after the fixes every band of the Ghouls'n Ghosts GX recording is within 0.2 dB of the reference render (-18.0 against -18.2 dB at 8 to 11 kHz).

### Noise rate, levels and the DC offset

- **Noise ran twice as fast.** It advanced at 125000/NP, and only when an odd number of periods fell in a sample. The AY clocks it at 1 MHz / (16 NP). Fix: `Update/(Period<<1)`, one shift per period, averaged over the sample (switch `NO_SNDNOISE_FIX`). The noise average also had a 32-bit overflow at a noise period of 1 (`High << 15` with values up to 2^18); x86's 64-bit `long` hid it, and the Paula dump found it (commit 953d09e).
- **Levels.** The 16 volume levels were the AY curve times 31, rounded to integers, so levels 0 to 2 and 3 to 5 were equal. Burnin' Rubber writes volume values 3, 5, 12, 13 at the line rate: 22 dB signal to quantisation noise with that table, 44 dB with amplitudes 0 to 124 (`NO_SNDLEVELS`).
- **Bipolar output.** A tone swung plus and minus its level around the middle, which made tones 6 dB louder than volume-register ("digi") sound compared with the real chip. The AY output is 0 or the level; the host removes the DC offset with a one-pole filter at about 14 Hz, like the CPC's output capacitor (`NO_SNDUNIPOLAR`).

**Look up.** Commits 3756b22, 953d09e, 2d2e90c; `SOUNDQ.md`; switches `NO_SNDENV_FIX`, `NO_SNDNOISE_FIX`, `NO_SNDLEVELS`, `NO_SNDUNIPOLAR`.

## Comparing WAV output with the reference emulator

**Problem.** "It sounds harsh" is not a measurement. We needed numbers that say which fault, and a way to know when it was fixed.

**Method.**
1. The headless host (chapter 06) records each title three ways from the same run: a WAV through the Amiga's own conversion, the core's raw mixed bytes before the 16-bit conversion, and a trace of every PSG register write with its time (`SOUNDQ_TRACE`, analysis only).
2. A small C program renders the trace as a reference AY: at the chip's own 125 kHz clock, with the datasheet's envelope and noise rates and a published AY DAC curve, then band-limited and resampled to the output rate in Python.
3. The reference render was itself checked against the reference emulator on the same passages with no input (Sonic title, bands 2 to 5, 5 to 8 and 8 to 11 kHz: -11.1, -17.2, -22.0 dB against -11.6, -18.4, -22.6; Puzzle Bobble -2.5, -10.3, -11.8 against -3.0, -9.4, -10.4). A reference you have not validated only moves the argument.
4. Compare band levels relative to the 200 to 2000 Hz band, plus the spectral floor (10th percentile of the 3 to 10 kHz bins). Differences of 0.3 dB or less per band are noise; the faults above were 1.5 to 6 dB.
5. Run the same register trace through the old and the new code and compare. With all the sound switches defined the core's mixed output was byte-identical to the previous version on two games, so the old behaviour stays reproducible.

**Closing the loop on the real output path.** A WinUAE build with a Paula dump (`SOUNDQ_DUMP`, off in normal builds) recorded what the Amiga build really sent to Paula and compared it with the headless WAV. First run: 95% equal, which found two Amiga-only bugs (the 32-bit overflow and the uninitialised first block, above). After the fixes the 8-bit Paula data and the 16-bit core data were **100.0% identical** to the headless recording. After that the headless WAV is a trustworthy stand-in for the Amiga's output, and listening on the A1200 is only a final check.

**Traps.** (1) Compare rendering paths, not just data: the headless host's `long` is 64 bits and the Amiga's is 32. (2) Use no-input passages for comparisons against another emulator, because game state diverges as soon as input differs. (3) The reference emulator applies register writes in 8 microsecond steps, coarser than ours; that explained a 2.8 dB difference in one band of one fast passage, so know your reference's own limits before chasing the last decibel.

**Look up.** `SOUNDQ.md`; the `tools/soundq` scripts (trace, reference render, band analysis) in the development repository.

## FM synthesis on a fast CPU (MSX-Music)

### Wavetables locked to the video frame, and only where the CPU has room

**Problem.** Many MSX games play their music on the MSX-Music chip (the YM2413 FM synthesizer, nine voices). AmiMSX 3.1 let a game find the chip only if the user chose a sound-chip setting the menu did not offer, and its "FM-Pack v0.1" played four of the nine voices as a fixed waveform on the four Paula channels, with no instruments and no envelopes. Games that use FM for their music were silent or played a thin PSG fallback.

**What a game asks of the chip** (a reference-emulator log of Lilly's Saga, 20 s of play): 5.6 register writes a frame on average and 26 at most. Mostly frequency and key-on/off writes (about 1,900 and 2,300 in 20 s), instrument and volume set rarely. It uses all nine voices and the custom instrument (registers 0 to 7), so the 68k side must be able to rebuild an instrument when a game writes them. No rhythm mode.

**Before** (design option 1 in `Docs/sound_fm_moonsound.md`, and the 3.1 routine `TocaFMPak`). One Paula channel per FM voice, with pitch and volume from the chip's registers. It costs almost nothing, but Paula has four channels and the PSG drives three of them, so nine voices cannot fit and the PSG would have to give up channels mid-game.

**After** (`AmiMSX_FM_v4.asm`, AmiMSX 4.0):

```
; Each instrument is 8 one-cycle tables (256 signed bytes, one per modulator
; level), made with the chip's log-sine/exp method; envelopes run once a
; frame; the 9 voices are mixed into words and written as bytes to Paula
; channel 3. The PSG keeps channels 0-2 (its noise channel is given up).
...
; Paula output is locked to the frame (313 lines x 227 colour clocks PAL):
; N = 227 samples a frame at period 313, or 313 at period 227 (FMXFast);
; a 60 Hz (NTSC) display has 262 lines and N follows (FMXSetN). The
; DMA loops over a 2N-byte buffer; FMXFrame (from Emula1Frame, just after the
; wait for the Amiga frame) fills the half that plays in the next frame.
...
FMXInit:
	MOVE.L	$4.W,A0			; 68040/68060 (PiStorm's Emu68 says so)
	MOVE.W	$128(A0),D0		; or 'Smooth display (fast CPUs)' on (the
	AND.W	#$88,D0			; PiStorm preset; a BigMig's TG68K core
	SNE	FMXFast			; reports a 68020): 15.6 kHz.
	TST.B	PrefDbuf
	BEQ.S	FMXInFs
	ST	FMXFast
```

*Source: AmiMSX 4.0, AmiMSX_FM_v4.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why this design.**
- **Wavetables, not operator-by-operator FM.** The chip's two-operator voice is reduced to a table lookup per sample: eight pre-made one-cycle tables per instrument (one per modulator level), a 32-bit phase accumulator per voice, and a gain from a 64-step table of 0.75 dB. About 8 instructions per voice per sample. Envelopes run once per video frame. The model leaves out the vibrato and tremolo flags, rhythm mode and the modulator's envelope inside a frame. The custom instrument is rebuilt on the 68k when a game writes registers 0 to 7.
- **Output locked to the frame.** The number of samples per frame, N, is chosen so that N samples last exactly one display frame (227 or 313 at 50 Hz; the code measures the line count at a resync, so a 60 Hz display gets 262 lines). If N drifts from the frame length, the half of the buffer being written drifts into the half playing and clicks every few frames; this happened in Lilly's Saga at 60 Hz on BigMig before N followed the display.
- **A ring, not a double buffer.** Paula's channel 3 interrupt takes the next block from a ring of 8, which the emulation keeps two frames ahead. A late frame or two no longer runs the ring dry (a block repeats instead of a jump).
- **The rate follows the CPU.** 15.6 kHz on a 68040/060 or with Smooth display on, about 11 kHz otherwise.
- **A lite mode** mixes only the four loudest voices (a key-on counts as loudest), for roughly half the cost.

**Policy: where it runs.** FM is on only in the PiStorm preset (`tools/make_presets.py`: sound chip "PSG+FM", frequency "From VDP", audio filter on, Smooth display on). The 68030 preset keeps the PSG, because the 68030 has no time to spare. Smooth display (a double-buffered SCREEN 4 display) switches itself off for a game that writes the FM ports, until the next Power ON or Reset:

```
OUT7D:
	ST	FmUsed			; (4.0) The game plays MSX-Music: Smooth
					; display off (its late frames slowed
					; the music: Lilly's Saga, Bombaman).
```

*Source: AmiMSX 4.0, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

With Smooth display, a late render cost a whole Amiga frame of emulated time, so the game's vertical-blank music ticked once in two Amiga frames and slowed down. Without it, a late frame is made up at once and the tempo holds. (A later change made Smooth display drop a late picture instead of repeating it, which removed the cost for PSG and SCC games too.)

**Evidence.**
- The 68k engine matches its PC model (`tools/fm_synth.py`, which is the spec): Lilly's Saga, 60 s on the 060 configuration, 2,953 frames, identical except 3 frames in which a few samples differ by 1 (the custom instrument was rebuilt in place while an old note faded; the model keeps a copy).
- Against the reference emulator (MSX-Music only, PSG muted): chroma correlation of the notes 0.94 to 0.97 (median), loudness-envelope correlation 0.88. At 11 kHz the highs are 23% duller (brightness 0.77), the 5.5 kHz ceiling. The FM to PSG balance is within 1.4 dB. The PSG itself was changed from linear to 3 dB a step to match the YM2149.
- Cost in Lilly's Saga gameplay (profiling build):

| CPU | FM time per frame | Game speed without FM / with FM |
|---|---|---|
| 68060 | 17 to 18 lines (about 6%) | 100% / 100% |
| 68030/50 | 23 to 25 lines (about 8%) | 86 to 89% / 80 to 83% |

Lilly's Saga already ran below full speed on a 68020 A1200 (42 to 50%) and 68030 (86 to 89%) without FM, which is why FM is a fast-CPU feature.

**Look up.** `AmiMSX_FM_v4.asm` (`FMXInit`, `FMXFrame`, `FMXSetN`, `FMXAud`); `Docs/sound_fm_moonsound.md` (options and measurements); `tools/fm_synth.py`, `tools/fmx_check.py` (replays logged register writes through the model), `tools/fm_compare.py`; build switch `FMXREC` (logs every register write and output byte).

## Six channels on four Paula voices (AmiPCEngine)

*AmiPCEngine.* The PC Engine's sound chip has six channels. Each plays a 32-sample wave of the game's own, channels 5 and 6 can play noise, and any channel can be driven sample by sample (DDA), which is how games play voices and drums. The design here does almost nothing per sample: once per Amiga vblank each Paula voice gets its pointer, length, period and volume, and the game's waves play from chip RAM. Paula voices are hard left or right. Commits and `docs/agent_notes/` in this section belong to the AmiPCEngine development repository.

Nothing here could be heard on the PC: WinUAE's WAV output is a GUI feature, and the reference emulator's scripting has no WAV recording. So the proof is in logs and renders, and the verdict on sound still comes from a tester's ears.

### Pick the four loudest channels each vblank instead of mixing

**Problem.** The original `PSG.asm` was a stub: four voices for channels 0-3, one fixed square wave, frequency and volume only. Games use all six channels.

**After** (`src/PSG.asm`, `PSGAllocate`, commit 378a9f9, switch `NO_PSG6`): score each channel by its Paula volume, and give a voice's current owner a bonus, so that near-equal channels do not swap every frame.

	.score:	BSR	PSGChScore
		MOVE.W	D1,(PSGScore.L,D6.W*2)
		MOVE.B	D2,(PSGPan.L,D6.W)
		...
		MOVEQ	#3,D0			; voice owners get the bonus
	.bonus:	MOVEQ	#0,D1
		MOVE.B	(PSGVoiceOwner.L,D0.W),D1
		BMI.S	.nob
		TST.W	(PSGScore.L,D1.W*2)
		BEQ.S	.nob
		ADDQ.W	#6,(PSGScore.L,D1.W*2)
	.nob:	DBF	D0,.bonus

*Source: AmiPCEngine 1.1, src/PSG.asm (freeware by Juan Antonio Gómez Gálvez and z00p; used with permission).*

**Why.** Mixing two channels into one voice is per-sample work on the 68k (about 300 samples x 2 voices a frame), with a buffer locked to real time. It adds aliasing and latency to every channel. Selection is about 1500 cycles a vblank on a 68030 and keeps each played channel at its exact pitch from its own 32-byte loop, and what gets dropped is the games' quietest channels. A channel that gains a voice takes a free one on its side when its balance leans one way. Loops are at most about a frame long, so a voice changes channel within a frame without restarting DMA.

**Evidence.** R-Type (Run at 600, 1500 frames), by a log with one line per frame from the emulator and the same line from a script on the reference emulator: all six channels' registers and wave checksums equal for frames 601-1250 at a steady lag, and a checker that recomputes each voice from the registers passes 1499 of 1499 frames. Tone pitch against the registers: median error 0.09%. Six channels were playable in 425 of the 1500 frames, and voices changed owner only 23 times. Cost: within the run-to-run spread on the 68030 config, so below about 2%.

**The limit.** Bonk's Revenge plays 5 or 6 channels, and its chord (amplitude 21-25) outranks its bass (20), so the bass mostly drops out. A tester called the sound "off". A switch that lifts low tones in the score exists (`NO_PSGBASS=0`, off by default). The log can show who gets a voice, not which sounds better, so that is left to ears. Tried by ear on the real machine, it was liked less than the default, so it stays off.

**Look up.** Commit 378a9f9; `tools/mesen_psg.lua`, `psgcmp.py`, `psglag.py`, `psgcheck.py`; test switch `PSGLog`; notes `docs/agent_notes/psg.md`.

### Drums 100 ms late: a voice that was never given a period

**Problem.** A tester on the A1200: sound good apart from the sampled parts, and Soldier Blade's drums "off". Up to then samples had only been checked by counting writes against the reference.

**Before** (`src/PSG.asm`, `InitPSG`): pointer, length and volume are set; the period is left as it was.

**After** (commit 3ddc3f9, switch `NO_DDAQUEUE`):

	MOVE.W	#124,$A6(A6)	; period: the 2-byte silent loop ends at once (left unset, WinUAE took 47 frames)
	MOVE.W	#124,$B6(A6)
	MOVE.W	#124,$C6(A6)
	MOVE.W	#124,$D6(A6)

and a busy stream outranks any tone for its voice:

	BSR	PSGDdaBusy
	BEQ.S	.nobusy
	MOVEQ	#100,D1			; a DDA stream with samples to play: above any tone

*Source: AmiPCEngine 1.1, src/PSG.asm (freeware by Juan Antonio Gómez Gálvez and z00p; used with permission).*

**Why.** A dump of every queued and played buffer showed the chain. Voice 0 had never played, so the first buffer waited 47 frames in WinUAE for the old loop to end, 42 frames were dropped with the queue full, and the queue then stayed 4 to 6 deep. Each drum chunk ended with the game turning the channel into a tone. The voice was stopped at once with 3 buffers still queued, and those stale buffers played first at the next chunk. So the end of each drum pattern was replayed at the start of the next, about 100 ms behind the music. The fix sets the period at start-up, lets a stream play out its queue, keeps only the newest 2 buffers at a start, carries the volume with each buffer, and drops the oldest when 4 or more wait.

**The listening loop.** To hear this without a WAV from the reference, a script logs every sound write there with its master clock, and a Python model renders that log by zero-order hold. A test switch (`DdaDump`) writes every buffer event from our side, and the model replays them through a simple Paula at their periods. Both come out as WAV files, also as a stereo file with the reference on the left and ours on the right.

**Evidence.** Soldier Blade: latency from buffer queued to buffer played 5-7 frames (up to 12 and 49) down to 2-3 frames, no dropped frames, first start 3 lines instead of 47 frames. Against the reference in 0.25 s windows: delay 120 ms to 52 ms, correlation median 0.52 to 0.80, best windows 0.99. A tester on the A1200 then called the drums right.

**Look up.** Commit 3ddc3f9; test switches `DdaDump`, `DdaStat` (a health line in the result file); `tools/mesen_dda.lua`, `pcmcmp.py`, `pcmwin.py`; notes `docs/agent_notes/pcm.md`.

### Samples written by a timer belong on the timer's grid, not the line grid

**Problem.** Sampled sound was noisy at 1-3 kHz. Parodius and Soldier Blade write one sample per timer interrupt, every 4.5 and 2.25 lines, but the capture held one sample per line. Our timer interrupt is taken at a line end, so the spacing came out as 4 and 5 lines, or 2, 2, 2 and 3, which adds a pattern tone (1748 Hz in Soldier Blade).

**After** (`src/PSG.asm`, commit eb68d5a, switch `NO_DDATICK`): each sample is filed by timer tick as well as by line. A frame is played from the tick buffer if no tick had two writes and at least 7/8 of the ticks have one, at a period worked out from the timer:

	MOVE.W	#610,PSGTkPer		; PAL screen: 313 x 227.5 / 116.9 ticks = 609.3
	...
	MOVE.W	#513,PSGTkPer		; 512 per tick = a 263-line frame per 116.9 ticks; 0.2% long

*Source: AmiPCEngine 1.1, src/PSG.asm (freeware by Juan Antonio Gómez Gálvez and z00p; used with permission).*

**Why.** The written values were already right. The error was when they played, and a simulation of only the line grid on the reference's own writes gave the same figures, which proved it. The period is meant to be 0.2% long, so the queue fills rather than runs dry; on a PAL screen it is in fact 0.36% long, because the comment's 227.5 colour clocks a line is NTSC's average and a PAL line is 227 (313 x 227 / 116.9 = 607.8, so 609 would be 0.2% long). The queue still fills, and only the drops come a little more often; with 3 or more buffers waiting, 2 samples are left off. Streams that are not timer-driven (Moto Roader II's bursts) stay on the line grid.

**Evidence.** Parodius "1 PLAYER" against the reference, signal-to-noise ratio in dB:

| capture | under 1 kHz | 1-3 kHz | 3-8 kHz | overall |
|---|---|---|---|---|
| by line | 35.3 | 10.5 | 6.8 | 22.4 |
| by tick | 37.5 | 18.8 | 10.9 | 26.6 |
| model: the reference's writes on a line grid | 34.1 | 10.1 | 5.8 | 21.9 |

The tick buffers hold the reference's write sequence, identical apart from the frame edge. Of the buffers queued, 1143 of 1288 went by tick in Soldier Blade and 241 of 246 in Parodius. Cost on the heaviest DDA title, 68030/50: 1135 to 1148 vblanks for 600 frames (+1.1%).

**Look up.** Commit eb68d5a; `PSGTickPut`; `tools/pcmseq.py`; notes `docs/agent_notes/pcm.md`, step 3.

### A software mix that measured well and sounded worse

**Problem.** With six channels on four voices, the quietest two are dropped each frame. The obvious answer on a fast machine is to mix all six in software and play the result through Paula.

**Tried.** On the RTG path of a PiStorm A1200, with the OS frozen: all six channels, noise and DDA samples mixed once a frame at 22 kHz, nearest sample from the 32-sample waves, 16-bit inside and 14-bit out on all four voices, with a ring and rate feedback.

**Evidence.** It was cheap: +1.7% of a frame on average across eight titles, +3.3% at worst, against an estimate of +7 to 11%. No underruns in 22 runs. Pitch and level matched a model of the chip. PC renders of the mix sounded, if anything, slightly more detailed.

**Result.** On the real machine, played A/B against the four hardware voices through the same amp, it sounded worse, so it was left out of the build. We did not establish why. Hardware voices play each wave at its own rate and don't resample it; a mix at a fixed rate does, but that is a guess, not a finding.

**Why it's here.** Good figures only say a thing is affordable. The numbers, the model and the PC render all agreed, and none of them was the test that counted. Build the smallest version behind a switch, and put it in front of someone's ears on the real output chain before deciding anything that depends on it.

**Look up.** AmiPCEngine branch `mix`, tag `mix-rtg`, not in any release; notes `docs/agent_notes/mix.md`.

## One software mix for PSG and FM, chosen at power on (AmiMSX)

AmiMSX 4.7 can play the PSG in software and mix it with the FM synthesis into one 14-bit stream per side (two Paula voices each), instead of giving the PSG channels and the FM their own voices. The player picks Classic (the old voice layout), Mono or Stereo. It costs CPU time, so it is a choice, with the default set by the CPU: Mono on a fast machine, Classic otherwise.

**Evidence for the mix.** The software PSG follows a Python model of the chip; a check build records the 68k output, which matches the model bit for bit (Lilly's Saga mono and stereo, R-Type with FM). Both were compared with captures from openMSX. Cost in Lilly's Saga gameplay, beam lines a frame for the sound: 68030 24 lines before, 86 with the mix (speed 87% to 72%); 68060 27 before, 68 mono, 89 stereo (speed 100%, 99.6%, 95%). The player's ear test on the PiStorm was good in both modes, with no loss of speed there. So the 68030 preset keeps Classic.

### A sound path switched mid-game left a channel on the old path

**Problem.** Changing the mix in the menu and pressing Continue broke the sound: the PSG was moved to the other path while it was playing.

**Before** (`AmiMSX_FM_v4.asm`, the first mix build): every return from the menu read the choice again.

    FMXInit:
        ...
        MOVE.B  PrefMix,D0      ; 0 automatic, 1 Classic, 2 Mono, 3 Stereo
        BNE.S   FMXInX1
        ...
    FMXInX1:
        SUBQ.B  #1,D0
        MOVE.B  D0,FMXMixOn

**After** (commit bbeb7ce): the choice is taken at Power ON or Reset only; Continue keeps the mix the game started with.

        MOVE.B  FMXMixRun,D0    ; the mix since Power ON / Reset
        TST.B   FMXMixNew       ; set by Power ON / Reset
        BEQ.S   FMXInX3         ; Continue: keep it
        SF      FMXMixNew
        MOVE.B  PrefMix,D0
        ...
        MOVE.B  D0,FMXMixRun
    FMXInX3:
        MOVE.B  D0,FMXMixOn

*Source: AmiMSX 4.7 (in development), AmiMSX_FM_v4.asm (freeware, used with permission).*

**Why.** The PSG's state lives in different places on the two paths (the hardware voices' registers or the software chip's counters), and the game does not write every register again after the menu, so a switch mid-game leaves notes and envelopes stranded on the path no longer played. Switching only when the machine starts again avoids converting live state. The user guide says the change takes effect at the next Power ON or Reset.

**Evidence.** The player's report of the broken sound after a mid-game switch. The fix removes the mid-game switch rather than converting live state; the player's retest was still to come when this was written.

**Look up.** Commits f915fb2 (the mix), bbeb7ce (the latch); `tools/psg_synth.py`, `tools/psx_check.py`; option `mix` in key scripts.

## HDMI sound through AHI, and one tone for both outputs (Arnold)

*Arnold.* On the PiStorm, Emu68 has an AHI driver that plays sound over the Pi's HDMI output. Arnold 1.6 added it as a second sound path on the RTG screen, next to Paula. Arnold uses the driver only through AHI, as any program would, so its own code needs no driver-specific part beyond a mode ID.

### Ask for the driver's low-latency mode, and queue whole frames

**Problem.** In the driver's plain mode, a click test wandered by about 85 ms against the picture.

**Before.** The driver's plain mode.

**After** (`amiga_audio.c`, Arnold 1.6). The mode is fixed at the driver's 16-bit low-latency mode. The core's frame block (444 samples) goes into a ring of 8 slots in fast RAM, played as one dynamic sound. A sound hook queues the next slot each time one starts, as Paula latches its next pointer:

    /* AHI back end: the frame's block in 16 bits, after the same DC filter as Paula's, in a
     * ring of slots in fast RAM played as one dynamic sound. SoundFunc runs when a slot
     * starts and queues the next, as Paula latches its pointer: no block ready, the slot
     * repeats. AHI's clock isn't the frame's, so the rate moves 0.2% to hold the queue. */
    #define AHI_HDMI_MODE 0x001f0012
    #define AHI_SLOTS 8
    #define AHI_START 2                   /* blocks queued before the sound starts */
    #define AHI_QMAX  4
    ...
    ahi_ctrl = AHI_AllocAudio(AHIA_AudioID, mode, AHIA_MixFreq, 48000, AHIA_Channels, 1, AHIA_Sounds, 1, ...

*Source: Arnold-m68k 1.7, `arnold/src/amiga/amiga_audio.c` (GPL-2.0).*

**Why.** The default mode mixes 96 ms at a time, so a program that wants the sound in step with the picture would have to keep about 5 frames queued, and the delay then drifts. The low-latency mode takes one frame at a time. A queue of whole frames, in the same shape as the Paula path, means the emulator's sound code is the same for both outputs up to the last step. If the frames are locked to the HDMI refresh ([chapter 12](12-rtg.md#with-hdmi-sound-time-the-frames-to-the-hdmi-refresh)), the rate is set to exactly one block per frame, and the queue stays at 1 to 2 blocks.

**Evidence.** Tester: no buzz, and the sound in step with the action, locked and unlocked. A film test at 120 frames a second used a BASIC program in the emulated CPC that flashed the border and beeped every 800 ms, so both went through Arnold's real path. Paula, by cable to the amplifier, was 94 ms before the picture. HDMI sound, from the TV's own speakers, was 28 ms after it. Neither run went through Bluetooth. The solid figure is the difference between the two paths, about 122 ms: BASIC's timing and the camera's own offset are in both absolute figures. Paula beats the picture because the picture goes through the hub and the TV, which an earlier direct click test (a flash and click with no emulator) put at about 131 ms. In that direct test, Paula was 131 ms and the HDMI low-latency mode 19 ms before the picture. Against those figures, Arnold's path made the sound about 37 ms later on Paula and 47 ms later on HDMI. Arnold's queue holds 1 to 2 frames, and the driver's low-latency ring is 30 to 50 ms by its own documentation. Speed cost on the A1200: none measurable.

**Look up.** `AHI_HDMI_MODE`, `Sys_AudioAhi`, `Sys_AudioLock`; `SetEnv ArnoldAHI <mode id in hex>` tries another mode; notes `Docs/agent_notes/hdmiahi.md`.

### Take the A1200's own filter out, then apply one tone to both outputs

**Problem.** The tester found raw 16-bit sound over HDMI a little harsh. On Paula the tone was not the program's to choose: the A1200's low-pass filter follows the power LED, so it depended on the machine's state.

**Before** (Arnold 1.6). Paula played through whatever filter state the machine was in. HDMI played the core's output as made.

**After** (Arnold 1.7, Options > Sound tone, `TONE=BRIGHT|SOFT|WARM`, preference `tone=`). One low-pass filter runs in software before either output: Bright (none), Soft (6 dB per octave at 4.5 kHz, about the A500's fixed filter; the default) or Warm (12 dB per octave at 3.3 kHz, about the A1200's LED filter). While Paula plays, the A1200's filter is switched off, and it is put back as it was when the sound stops:

    static int led_saved = -1;            /* CIA-A PRA bit 1 (0: LED bright, filter on) as it was; -1: not switched */

    static void led_filter_off(void)
    {
        Disable();
        if (led_saved < 0) { led_saved = ciaa.ciapra & CIAF_LED; ciaa.ciapra |= CIAF_LED; }
        Enable();
    }

    static void led_filter_back(void)
    {
        Disable();
        if (led_saved >= 0) { if (led_saved) ciaa.ciapra |= CIAF_LED; else ciaa.ciapra &= ~CIAF_LED; led_saved = -1; }
        Enable();
    }

*Source: Arnold-m68k 1.7, `arnold/src/amiga/amiga_audio.c` (GPL-2.0).*

**Why.** A filter the user cannot see makes two outputs sound different and makes A/B listening meaningless. Turning it off and doing the filtering in software gives the same sound on both outputs, and the choice becomes a menu item. The filter is a bilinear transform at the core's 22168 Hz rate, so it costs a few multiplies per sample. Put the LED bit back on every exit path, including the menu, or the user's Workbench sound changes after the emulator quits.

**Evidence.** The settings copy the Amiga's own filters; they were not measured against a real CPC or GX4000, whose output stage is still to be looked up. Bright on Paula is the 1.6 conversion, unchanged.

**Look up.** `Sys_AudioTone`, `audio_tone`, `led_filter_off`, `led_filter_back`; notes `Docs/agent_notes/release-1.7.md`.
