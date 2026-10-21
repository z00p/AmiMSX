# Sound

## Paula output paths and the AUD0 interrupt storm on NTSC

*To be written (Arnold).*

## AY band-limited rendering: averaging vs point sampling

*To be written (Arnold).*

## Envelopes, noise rate, volume tables and 16-to-8 clipping

*To be written (Arnold).*

## Comparing WAV output with the reference emulator

*To be written (Arnold).*

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

