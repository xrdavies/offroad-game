"""Original engine and terrain loops; standard-library synthesis, no sampled audio."""
from array import array
import json
import math
from pathlib import Path
import random
import struct
import wave

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / "assets/audio"
PROFILES = json.loads((OUT / "profiles.json").read_text())


def save(name, values, target_rms):
    # Overlap beyond the retained loop, so its end flows into the first sample.
    n = int(RATE * 0.15)
    tail = values[-n:]
    for i in range(n):
        t = i / n
        values[i] = tail[i] * (1 - t) + values[i] * t
    values = values[:-n]
    dc = sum(values) / len(values)
    rms = math.sqrt(sum((v - dc) ** 2 for v in values) / len(values))
    peak = max(abs(v - dc) for v in values)
    gain = min(target_rms / rms, 0.78 / peak)
    samples = [round((v - dc) * gain * 32767) for v in values]
    step_rms = math.sqrt(sum((b - a) ** 2 for a, b in zip(samples, samples[1:])) / (len(samples) - 1))
    assert abs(samples[0] - samples[-1]) < max(150, step_rms * 6), (name, "loop seam")
    assert max(map(abs, samples)) < 26000 and rms > 0.0001
    with wave.open(str(OUT / (name + ".wav")), "wb") as out:
        out.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        out.writeframes(struct.pack("<%dh" % len(samples), *samples))
    print(f"{name}: {len(samples)/RATE:.2f}s, RMS {rms*gain:.3f}, peak {peak*gain:.3f}")


def engine(profile, loaded, seed):
    rng = random.Random(seed)
    rpm = profile["run_rpm" if loaded else "idle_rpm"]
    firing = rpm * profile["cylinders"] / 120
    phase = 0.0
    envelope = 0.0
    exhaust = 0.0
    low = 0.0
    cycle = 0
    strength = 1.0
    values = array("f")
    # Each firing excites a damped exhaust resonance and a separate mechanical tick.
    decay = math.exp(-1 / (RATE * (0.008 if loaded else 0.012)))
    smooth = 1 - math.exp(-math.tau * (1800 if loaded else 1100) / RATE)
    for i in range(int(RATE * 6.15)):
        t = i / RATE
        phase += firing / RATE * (1 + 0.009 * math.sin(math.tau * 1.7 * t))
        if phase >= 1:
            phase -= 1
            cycle += 1
            strength = 1 + profile["roughness"] * rng.uniform(-1, 1)
            if profile["cylinders"] == 8:
                strength *= [1.0, 0.72, 1.1, 0.85, 0.78, 1.05, 0.86, 1.12][cycle % 8]
            envelope = strength
        age = phase / firing
        envelope *= decay
        white = rng.uniform(-1, 1)
        low += 0.06 * (white - low)
        pulse = envelope * (math.sin(math.tau * profile["resonance"] * age)
                            + 0.35 * math.sin(math.tau * profile["resonance"] * 2.1 * age))
        exhaust += smooth * (pulse - exhaust)
        knock = white * math.exp(-age * 1100) * profile["diesel"] * 0.9
        intake = low * (0.7 if loaded else 0.15)
        turbo = profile["turbo"] * (0.05 if loaded else 0.003) * (
            math.sin(math.tau * 1250 * t + 0.7 * math.sin(math.tau * 3 * t)) + white * 0.7)
        values.append(math.tanh(exhaust * (2.1 if loaded else 1.35)) * 0.6 + knock + intake + turbo)
    return values


# Noise colour, pulse density, transient duration, resonance, transient mix.
SURFACES = {
    "road": (0.09, 8, 0.015, 85, 0.08),
    "dirt": (0.20, 42, 0.026, 170, 0.55),
    "grass": (0.14, 23, 0.045, 350, 0.30),
    "forest": (0.33, 30, 0.035, 620, 0.65),
    "rock": (0.07, 11, 0.060, 105, 1.40),
    "sand": (0.40, 70, 0.010, 900, 0.10),
    "mud": (0.035, 9, 0.110, 140, 1.40),
    "swamp": (0.025, 6, 0.170, 220, 1.60),
    "water": (0.22, 13, 0.130, 480, 0.85),
    "gobi": (0.40, 48, 0.020, 1300, 1.00),
    "snow": (0.48, 19, 0.075, 600, 0.75),
    "ice": (0.06, 5, 0.070, 1900, 0.22),
}


def terrain(kind, seed):
    smooth, density, duration, resonance, amount = SURFACES[kind]
    rng = random.Random(seed)
    values = array("f")
    low = 0.0
    slow = 0.0
    envelope = 0.0
    age = 1.0
    frequency = resonance
    decay = math.exp(-1 / (RATE * duration * 0.3))
    for i in range(int(RATE * 8.15)):
        t = i / RATE
        white = rng.uniform(-1, 1)
        low += smooth * (white - low)
        slow += 0.004 * (white - slow)
        if rng.random() < density / RATE:
            envelope = rng.uniform(0.35, 1.0)
            age = 0.0
            frequency = resonance * rng.uniform(0.65, 1.5)
        envelope *= decay
        age += 1 / RATE
        texture = low * 0.32 + slow * 0.8
        transient = envelope * (white * 0.3 + math.sin(math.tau * frequency * age) * 0.35)
        if kind in ("mud", "swamp"):
            transient = envelope * math.sin(math.tau * frequency * (age + age * age * 5))
        elif kind == "water":
            transient = envelope * low * 2.5
            texture *= 1 + 0.5 * math.sin(math.tau * 1.2 * t)
        elif kind in ("grass", "forest", "snow", "sand"):
            transient = envelope * (white - slow)
        elif kind == "road":
            texture += 0.04 * math.sin(math.tau * 86 * t) * (0.8 + 0.2 * math.sin(math.tau * 3 * t))
        elif kind == "ice":
            texture += 0.018 * math.sin(math.tau * 720 * t + math.sin(math.tau * 4 * t))
        values.append(texture + transient * amount)
    return values


if __name__ == "__main__":
    for i, (name, profile) in enumerate(PROFILES.items()):
        for loaded in (False, True):
            save(f"engine_{name}_{'load' if loaded else 'idle'}",
                 engine(profile, loaded, 100 + i), 0.22)
    for i, kind in enumerate(SURFACES):
        save("tire_" + kind, terrain(kind, 200 + i), 0.16)
