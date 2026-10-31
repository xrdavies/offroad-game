"""Original, reproducible driving Foley. Standard library only; no sampled recordings."""
from array import array
import math
from pathlib import Path
import random
import struct
import wave

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)


def save(name, samples, loop=False):
    values = array('f', samples)
    if loop:
        # Overlap the tail into the head; retain a continuous boundary at the wrap.
        n = 2205
        tail = values[-n:]
        for i in range(n):
            t = i / n
            values[i] = tail[i] * (1-t) + values[i] * t
        values = values[:-n]
    dc = sum(values) / len(values)
    peak = max(abs(v-dc) for v in values)
    gain = min(1.0, 0.8 / max(peak, 0.0001))
    frames = b''.join(struct.pack('<h', round((v-dc)*gain*32767)) for v in values)
    with wave.open(str(OUT / (name + '.wav')), 'wb') as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(frames)
    assert peak > 0.001 and len(frames) > 1000
    if loop:
        assert abs(values[0]-values[-1]) < 0.08, (name, 'loop click')
    print(f'{name}: {len(values)/RATE:.2f}s, peak {peak*gain:.3f}')


def noise(duration, smooth, seed):
    rng = random.Random(seed)
    low = 0.0
    result = []
    for _ in range(int(duration * RATE)):
        low += smooth * (rng.uniform(-1,1)-low)
        result.append(low)
    return result


motor = noise(3.05, 0.18, 17)
for i in range(len(motor)):
    t = i / RATE
    pulse = sum(math.sin(math.tau * 48 * h * t + h*0.2) / h for h in range(1,10))
    motor[i] = math.tanh(pulse*1.3)*0.29 + motor[i]*0.11
save('engine', motor, True)

gravel = noise(4.05,0.5,23)
for i in range(len(gravel)):
    t = i / RATE
    gravel[i] *= 0.4 * (0.55 + 0.25 * math.sin(math.tau*19*t) + 0.2*math.sin(math.tau*7*t))
save('gravel', gravel, True)
water = noise(4.05,0.12,29)
for i in range(len(water)):
    water[i] *= 0.8 * (0.7+0.3*math.sin(math.tau*i/RATE*1.5))
save('water',water,True)
wind = noise(8.05,0.018,31)
for i in range(len(wind)):
    wind[i] *= 1.5*(0.7+0.3*math.sin(math.tau*i/RATE/8))
save('wind',wind,True)
impact = noise(0.48,0.25,47)
for i in range(len(impact)):
    t = i/RATE
    impact[i] = (impact[i]*0.6+math.sin(math.tau*72*t)*0.35)*math.exp(-t*14)*min(1,t*700)
save('impact',impact)
save('discovery', ((math.sin(math.tau*523.25*i/RATE)+math.sin(math.tau*783.99*i/RATE)*0.35)*0.17*math.exp(-i/RATE*4)*min(1,i/600) for i in range(RATE)))
