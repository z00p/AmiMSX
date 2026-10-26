# Sound

## Paula output paths and the AUD0 interrupt storm on NTSC

*Reading notes (Arnold).* Arnold's sound is the Amstrad's AY-3-8912 sound chip (the PSG) mixed in the core, then converted to Paula samples. The core makes one block of 444 samples per CPC frame (22.24 kHz at 50 frames a second), so the frame rate and the sound rate are locked together.

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

