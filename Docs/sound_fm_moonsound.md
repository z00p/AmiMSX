# MSX-Music (FM-PAC) and Moonsound: groundwork (11 Oct 2026)

Notes for deciding how far AmiMSX can go with FM sound on each target (A1200, 68030/50, PiStorm / BigMig).

## What AmiMSX has today

- **FM-PAC ROM:** included in the source (`MSX_Amiga/FMPak.0-3`). It is put in Slot 1 only when the sound chip setting is 3, which the menu doesn't offer (PSG, SCC, SCC+). So games never see MSX-Music, and they play their PSG music, or nothing when their music is FM only.
- **"FM-Pack v0.1"** (`TocaFMPak`, Juan's): plays four of the nine FM channels as a fixed waveform on the four Paula channels, with volume and pitch from the YM2413 registers. No instruments, no envelopes.
- **Licensing:** the FM-PAC ROM is Panasonic's. Shipping it needs the same care as the MSX system ROMs. C-BIOS has its own MSX-Music ROM (`cbios_music.rom`, BSD-style), which would do for detection.

## What a game asks of the chip: Lilly's Saga

From openMSX (C-BIOS MSX2+ with MSX-Music), 20 s of play, ports 7Ch/7Dh:

- **Writes:** 4,215 in total, 5.6 a frame on average, 26 at most.
- **Correction (full 70 s log from power-on, `build/omsx/fm/lilly_full5.txt`):** the game *does* use the custom instrument. It writes registers 00h-07h (six times, each time it changes tune) and puts channels 0-2 on instrument 0, with built-in instruments on the others. So the 68k side must build the custom instrument's tables when a game writes them, not just carry pre-made tables.
- **Registers (20 s window):**
  - 1xh: frequency (low bits), 1,906 writes.
  - 2xh: key on/off, block and frequency (high bit), 2,303 writes.
  - 3xh: instrument and volume, 6 writes (set once, then left alone).
- **Instruments:** built-in ones (3 piano, 15 electric guitar and others) plus the custom one (see the correction above).
- **No rhythm mode** (register 0Eh unused).
- **All 9 channels**, with up to 9 notes on at once.

So the work is pitch and key events at frame rate, on nine voices, with the chip's fixed instrument set. That is the common case for MSX-Music games.

## Options

1. **Paula voices, no mixing:** each FM channel on its own Paula channel, as in v0.1.
   - **Cost:** almost nothing.
   - **Limit:** four channels, shared with the PSG. Lilly's Saga needs nine, so most of the music would be missing.
2. **Wavetable mixing:** a software mixer at a modest rate (about 11 kHz) into one or two Paula channels.
   - **The tables:** one-cycle waveforms per built-in instrument, made offline from the YM2413 patch data with an FM model (emu2413 is MIT-licensed). They play at the note's pitch, with a simple per-instrument envelope (attack, decay, sustain, release) stepped once a frame.
   - **Cost:** roughly 8 instructions per voice per sample, so 9 voices × 11,025 Hz × 8 is about 0.8 M instructions a second. That's under 10% of a 68030/50. On the A1200, fewer voices or a lower rate.
   - **Sound:** close to the right timbres. It misses the modulation that changes over time (attack transients, vibrato, the AM/PM flags).
3. **Full YM2413 emulation:** a port of emu2413-style synthesis, mixed with the PSG and SCC into Paula (14-bit if possible).
   - **Cost:** too slow for a 68030, but realistic on Emu68 (PiStorm, BigMig).
   - **Sound:** close to openMSX.

Options 2 and 3 can share the register handling (ports 7Ch/7Dh, the channel state) and the mixer, so option 2 on 68030/A1200 builds and option 3 on PiStorm builds fit the per-target plan.

## Moonsound (OPL4)

- **Chip:** YMF278B, made of an OPL3 FM part (18 channels, 4-operator modes) and a sample-based wave part (24 voices, ADPCM/PCM from a 2 MB sample ROM, YRW801, plus the cartridge's SRAM).
- **On a 68030:** not realistic.
- **On a PiStorm or BigMig:** possible, but a big job. It needs the YRW801 ROM image, which can't be shipped.
- **Test game:** Neon Horizon (in the top list).
- **Neon Horizon, measured (11 Oct, openMSX C-BIOS MSX2+, no Moonsound present, 40 s):**
  - It writes only the wave part (ports 7Eh/7Fh, about 1,760 writes each) and the PSG (about 2,350 data writes). No FM ports (C4h-C7h).
  - Without a Moonsound it plays its PSG sound.
  - 1,760 wave writes is far too few for uploading its own samples, so its music most likely uses the YRW801 sample ROM (the General MIDI style instrument set). Emulating that needs the ROM image, which isn't available here and can't be shipped. That makes Moonsound a 'bring your own ROM' feature, PiStorm/BigMig only.

## Option 2 prototype on the PC (11 Oct, `tools/fm_synth.py`)

A Python model of the wavetable approach, written the way the 68k code will work:

- **Tables:** each instrument becomes 8 one-cycle tables of 256 signed bytes, one per modulator level. Each is the carrier's steady-state output, made with the chip's own log-sine/exp method (feedback and half-sine waveforms included). Built-in instrument data from emu2413 (MIT, by Mitsutaka Okazaki; reference copy in `emu2413`, v1.6.4). 15 built-in instruments × 8 × 256 = 30 KB; the custom instrument's 2 KB are rebuilt when a game writes registers 00h-07h.
- **Envelopes:** once a frame, from the chip's rate rules (key scaling included): decay/release as a per-rate step per frame, attack as a per-rate curve.
- **Voices:** a 32-bit phase accumulator per voice; the gain (carrier envelope + volume + key-scale level) picks one of 64 steps of 0.75 dB. The gain moves in 4 steps across a frame, and a change of modulator level cross-fades over the frame, both against clicks.
- **Not modelled:** the AM/PM LFOs (tremolo/vibrato flags), rhythm mode, the modulator's envelope within a frame.

**Checked against openMSX** (`tools/fm_compare.py`; Lilly's Saga, 55 s from 15 s; openMSX MSX-Music only, PSG muted):

| | 22,050 Hz | 11,025 Hz |
|---|---|---|
| Notes (chroma correlation, median / 10th percentile) | 0.97 / 0.81 | 0.97 / 0.82 |
| Loudness envelope correlation | 0.88 | 0.88 |
| Brightness, render / reference | 1.00 | 0.77 (the 5.5 kHz ceiling) |

So the right notes, at the right times, with close to the right timbre. Listening files in `build/fm/`: `lilly_AB_openmsx_then_tables.wav` (6 s of openMSX, then 6 s of the tables, alternating), `lilly_tables_11025.wav`, `lilly_tables_22050.wav`, `instruments_demo.wav` (a scale on each built-in instrument, 1-15).

## Next steps

1. Run Lilly's Saga with the FM-PAC enabled in AmiMSX (sound chip 3 through a key-script option) to confirm the game finds MSX-Music, and see what v0.1 sounds like.
2. Measure the free CPU time per frame in Lilly's Saga on the 030 and A1200 configs (perf build), to size option 2.
3. Option 2 on the 68k: the PC model is done (above). Next, the 68k mixer and table builder, first as a PERF build, measured. Paula plan: PSG tones stay on channels 0-2; the FM mix plays on channel 3 from a double buffer filled once a frame.
4. Moonsound: decide whether a 'bring your own YRW801' wave-part emulation on PiStorm/BigMig is worth it. FM (MSX-Music) is used by many more games.
