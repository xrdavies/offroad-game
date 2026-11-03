"""Compose the original 96-second exploration loop 'Open Tracks'. No samples."""
from array import array
import math
from pathlib import Path
import random
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
BEAT = 0.75  # 80 BPM, 32 bars in 4/4.
FRAMES = RATE * 96
LEFT = array("f", [0]) * FRAMES
RIGHT = array("f", [0]) * FRAMES
RNG = random.Random(1943)


def mix(sound, beat, level, pan=0.0, echo=False):
    start = round(beat * BEAT * RATE)
    gains = (math.sqrt((1 - pan) / 2) * level, math.sqrt((1 + pan) / 2) * level)
    for delay, gain, swap in [(0, 1.0, False)] + ([(int(BEAT * RATE * .75), .18, True), (int(BEAT * RATE * 1.5), .08, False)] if echo else []):
        for i, sample in enumerate(sound):
            index = (start + i + delay) % FRAMES
            LEFT[index] += sample * gains[1 if swap else 0] * gain
            RIGHT[index] += sample * gains[0 if swap else 1] * gain


def note(midi, seconds, voice):
    frequency = 440 * 2 ** ((midi - 69) / 12)
    count = int(seconds * RATE)
    out = array("f")
    if voice == "pluck":
        size = round(RATE / frequency)
        string = [RNG.uniform(-1, 1) for _ in range(size)]
        for i in range(count):
            j = i % size
            sample = string[j]
            string[j] = (sample + string[(j + 1) % size]) * .496
            out.append(sample * min(1, i / 180) * min(1, (count - i) / 2200))
        return out
    for i in range(count):
        t = i / RATE
        phase = math.tau * frequency * t
        release = min(1, (count - i) / (RATE * .25))
        if voice == "keys":
            envelope = (1 - math.exp(-t * 60)) * math.exp(-t * 1.3) * release
            value = math.sin(phase + .65 * math.exp(-t * 3) * math.sin(phase * 2))
        elif voice == "bass":
            envelope = (1 - math.exp(-t * 90)) * math.exp(-t * 2.5) * release
            value = math.sin(phase) + .22 * math.sin(phase * 2) + .07 * math.sin(phase * 3)
        else:
            envelope = min(1, t / .6) * min(1, (seconds - t) / .9)
            value = (math.sin(phase) + .35 * math.sin(phase * 1.002) + .14 * math.sin(phase * 2)) * .6
        out.append(value * envelope)
    return out


def drum(kind):
    seconds = .35 if kind == "kick" else .18 if kind == "brush" else .07
    out = array("f")
    low = 0.0
    for i in range(int(seconds * RATE)):
        t = i / RATE
        noise = RNG.uniform(-1, 1)
        low += .20 * (noise - low)
        if kind == "kick":
            value = math.sin(math.tau * (47*t + 1.9*(1-math.exp(-t*25)))) * math.exp(-t*16)
        elif kind == "brush":
            value = (noise - low) * math.exp(-t * 28) * .6 + math.sin(math.tau*180*t)*math.exp(-t*45)*.16
        else:
            value = (noise - low) * math.exp(-t * 70)
        out.append(value * min(1, i / 70))
    return out


def main():
    # Dm9 / Bbmaj7 / Fmaj9 / Cadd9; sparse original motif with four evolving sections.
    chords = [[50, 57, 60, 64], [46, 53, 57, 62], [41, 48, 55, 57], [48, 55, 62, 64]]
    melodies = [[69, 72, 76, 74], [69, 65, 62, 65], [67, 69, 72, 69], [67, 64, 62, 60]]
    drums = {name: drum(name) for name in ["kick", "brush", "hat"]}
    for bar in range(32):
        section = bar // 8
        chord_index = (bar // 2) % 4
        chord = chords[chord_index]
        beat = bar * 4
        for j, pitch in enumerate(chord):
            mix(note(pitch + 12, 3.8, "pad"), beat, .032, (j - 1.5) * .35)
            mix(note(pitch + 12, 2.2, "keys"), beat + j*.045, .095, (j - 1.5) * .22, True)
        for tick in [0, 1.5, 2.5]:
            mix(note(chord[0] - 12, .8, "bass"), beat + tick, .19 if tick == 0 else .12, -.05)
        for j, tick in enumerate([.5, 1.25, 2.5, 3.25]):
            pitch = chord[[0, 2, 1, 3][j]] + 12
            mix(note(pitch, 1.4, "pluck"), beat + tick, .18, -.4 if j % 2 == 0 else .4, True)
        if section in [1, 2] or bar % 4 == 3:
            for j, tick in enumerate([.0, 1.5, 2.25, 3.0]):
                pitch = melodies[chord_index][(j + (2 if section == 2 else 0)) % 4]
                mix(note(pitch, 1.4, "keys"), beat + tick, .12, .12, True)
        if bar >= 4:
            for tick in [0, 2]:
                mix(drums["kick"], beat + tick, .14)
            for tick in [1, 3]:
                mix(drums["brush"], beat + tick, .075, .15)
            for tick in range(8):
                mix(drums["hat"], beat + tick*.5 + (.045 if tick % 2 else 0), .024 if tick % 2 else .036, -.35)
    # A short circular room tail also makes the loop return continuous.
    for channel in [LEFT, RIGHT]:
        original = channel[:]
        for delay, gain in [(int(RATE*.071), .12), (int(RATE*.137), .07)]:
            for i in range(FRAMES):
                channel[i] += original[(i - delay) % FRAMES] * gain
        dc = sum(channel) / FRAMES
        for i in range(FRAMES):
            channel[i] -= dc
    peak = max(max(map(abs, LEFT)), max(map(abs, RIGHT)))
    gain = .72 / peak
    pcm = array("h")
    for a, b in zip(LEFT, RIGHT):
        pcm.extend((round(a*gain*32767), round(b*gain*32767)))
    rms = math.sqrt(sum(x*x for x in pcm) / len(pcm)) / 32768
    assert .06 < rms < .25 and abs(LEFT[0]-LEFT[-1])*gain < .015
    assert abs(RIGHT[0]-RIGHT[-1])*gain < .015
    (ROOT / "build").mkdir(exist_ok=True)
    wav = ROOT / "build/open_tracks.wav"
    with wave.open(str(wav), "wb") as out:
        out.setparams((2, 2, RATE, 0, "NONE", "not compressed"))
        out.writeframes(pcm.tobytes())
    target = ROOT / "assets/audio/open_tracks.ogg"
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav), "-c:a", "vorbis", "-strict", "-2", "-b:a", "160k", str(target)], check=True)
    print(f"MUSIC: {target.name}, 96.0s stereo, 80 BPM; peak -2.85 dBFS, RMS {20*math.log10(rms):.2f} dBFS")


if __name__ == "__main__":
    main()
