#!/usr/bin/env python3
# tools/make_audio.py
# Purpose: Writes the game's sound effects, using only math. The nature sounds are real recordings; see tools/loop_nature.py.
# Run from the project root: python3 tools/make_audio.py

import array
import math
import os
import random
import subprocess
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/audio")
RATE = 22050


def write_wav(path, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = min(1.0, 0.85 / peak)
    data = array.array("h", (int(max(-1.0, min(1.0, s * gain)) * 32767) for s in samples))
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data.tobytes())


def pluck(freq, seconds, rng, bright=0.5, damping=0.996):
    """A plucked string, close to an oud, from the Karplus-Strong method."""
    period = max(2, int(RATE / freq))
    line = [rng.uniform(-1.0, 1.0) for _ in range(period)]
    for _ in range(3):
        line = [(line[i] + line[i - 1]) * 0.5 for i in range(period)]
    out = []
    index = 0
    for _ in range(int(seconds * RATE)):
        now = line[index]
        following = line[(index + 1) % period]
        line[index] = damping * (bright * now + (1.0 - bright) * following)
        out.append(now)
        index = (index + 1) % period
    return out


def mix(track, sound, at, level):
    start = int(at * RATE)
    for i, value in enumerate(sound):
        if start + i >= len(track):
            break
        track[start + i] += value * level


def drum(seconds, freq, rng, noise=0.25):
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        body = math.sin(2.0 * math.pi * freq * t * (1.0 - t * 0.6)) * math.exp(-t * 16.0)
        out.append(body + rng.uniform(-noise, noise) * math.exp(-t * 40.0))
    return out


def tone(freq, seconds, decay, level=1.0):
    return [math.sin(2.0 * math.pi * freq * i / RATE) * math.exp(-i / RATE * decay) * level for i in range(int(seconds * RATE))]


def thud(seconds, freq, decay, noise, rng):
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        out.append((math.sin(2.0 * math.pi * freq * t) + rng.uniform(-noise, noise)) * math.exp(-t * decay))
    return out


def splash(rng):
    out = []
    last = 0.0
    for i in range(int(0.5 * RATE)):
        t = i / RATE
        last = last * 0.72 + rng.uniform(-1.0, 1.0) * 0.28
        drip = math.sin(2.0 * math.pi * (900.0 + 1400.0 * t) * t) * 0.15 if int(t * 22) % 2 == 0 else 0.0
        out.append((last + drip) * min(1.0, t * 20.0) * math.exp(-t * 6.0))
    return out


def chord(freqs, seconds, gap, rng):
    out = [0.0] * int((seconds + gap * len(freqs)) * RATE)
    for i, freq in enumerate(freqs):
        mix(out, pluck(freq, seconds, rng, bright=0.6), gap * i, 0.6)
    return out


def quiet(samples, peak):
    """Scales a sound so its loudest point sits at the given level, to match the other effects."""
    top = max(1e-6, max(abs(s) for s in samples))
    return [s * peak / top for s in samples]


def refusal():
    """Two soft low notes going down: "not now"."""
    out = [0.0] * int(0.3 * RATE)
    mix(out, tone(220.0, 0.12, 24.0), 0.0, 1.0)
    mix(out, tone(165.0, 0.18, 18.0), 0.1, 1.0)
    return out


def door(rng):
    """A wooden door closing: a low knock and a small latch click after it."""
    out = [0.0] * int(0.3 * RATE)
    mix(out, thud(0.2, 120.0, 22.0, 0.35, rng), 0.0, 1.0)
    mix(out, thud(0.05, 900.0, 90.0, 0.6, rng), 0.11, 0.3)
    return out


def page(rng):
    """A page turning: a short rush of soft noise that swells and falls."""
    out = []
    last = 0.0
    count = int(0.16 * RATE)
    for i in range(count):
        t = i / count
        raw = rng.uniform(-1.0, 1.0)
        bright = raw - last * 0.85
        last = raw
        out.append(bright * math.sin(math.pi * t) ** 2 * (0.6 + 0.4 * t))
    return out


def cast(rng):
    """A float dropping into water: a falling plop and a small splash."""
    out = [0.0] * int(0.4 * RATE)
    plop = []
    phase = 0.0
    for i in range(int(0.12 * RATE)):
        t = i / RATE
        phase += 2.0 * math.pi * (620.0 - 3000.0 * t) / RATE
        plop.append(math.sin(phase) * math.exp(-t * 22.0))
    mix(out, plop, 0.0, 1.0)
    mix(out, splash(rng)[: int(0.3 * RATE)], 0.06, 0.5)
    return out


def hammer(rng):
    """Three hammer taps on wood."""
    out = [0.0] * int(0.5 * RATE)
    for i, level in enumerate([0.8, 1.0, 0.9]):
        mix(out, thud(0.1, 310.0, 42.0, 0.5, rng), 0.15 * i, level)
    return out


def main():
    rng = random.Random(5)
    write_wav(os.path.join(OUT, "hoe.wav"), thud(0.16, 95.0, 26.0, 0.8, rng))
    write_wav(os.path.join(OUT, "water.wav"), splash(rng))
    write_wav(os.path.join(OUT, "harvest.wav"), chord([392.0, 523.25, 659.25], 0.4, 0.07, rng))
    write_wav(os.path.join(OUT, "chop.wav"), thud(0.2, 170.0, 24.0, 1.0, rng))
    write_wav(os.path.join(OUT, "mine.wav"), [a + b for a, b in zip(tone(1250.0, 0.22, 26.0, 0.5), thud(0.22, 240.0, 30.0, 0.7, rng))])
    write_wav(os.path.join(OUT, "level.wav"), chord([293.66, 369.99, 440.0, 587.33, 739.99], 0.8, 0.11, rng))
    # Added after the first six so the earlier sounds come out the same as before.
    write_wav(os.path.join(OUT, "no.wav"), quiet(refusal(), 0.34))
    write_wav(os.path.join(OUT, "door.wav"), quiet(door(rng), 0.4))
    write_wav(os.path.join(OUT, "page.wav"), quiet(page(rng), 0.3))
    write_wav(os.path.join(OUT, "cast.wav"), quiet(cast(rng), 0.4))
    write_wav(os.path.join(OUT, "build.wav"), quiet(hammer(rng), 0.45))


if __name__ == "__main__":
    main()
