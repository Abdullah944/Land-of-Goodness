#!/usr/bin/env python3
# tools/make_audio.py
# Purpose: Writes the game's calm nature sounds for each season and its sound effects, using only math.
# Run from the project root: python3 tools/make_audio.py  (add "nature" to make only the season sounds)

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


AMBIENCE_RATE = 24000
LOOP_SECONDS = 60.0
# Each season's nature sounds, as a level for each layer. The game plays these in place of music.
# Only clean, tonal sounds: hiss built from noise sounds like an old television on a phone speaker.
SEASONS = {
    "village": {"seed": 21, "birds": 1.0, "brook": 0.35},
    "summer": {"seed": 34, "birds": 0.8, "cicadas": 0.18},
    "autumn": {"seed": 55, "crickets": 0.45, "birds": 0.6, "rain": 0.35},
    "winter": {"seed": 89, "rain": 0.8, "birds": 0.35},
}


def drops(count, rng, every, low, high):
    """Water drops landing one by one: each is a short round note that slides up, as a real drop sounds."""
    out = [0.0] * count
    at = rng.uniform(0.0, every)
    while at < LOOP_SECONDS + 2.0:
        start = int(at * AMBIENCE_RATE)
        freq = rng.uniform(low, high)
        level = rng.uniform(0.25, 1.0)
        phase = 0.0
        for k in range(int(0.07 * AMBIENCE_RATE)):
            if start + k >= count:
                break
            t = k / AMBIENCE_RATE
            phase += 2.0 * math.pi * freq * (1.0 + 2.5 * t) / AMBIENCE_RATE
            out[start + k] += math.sin(phase) * min(1.0, t * 800.0) * math.exp(-t * 55.0) * level
        at += rng.expovariate(1.0 / every)
    return out


def layer_rain(count, rng):
    """Light rain on leaves and puddles: many soft drops, some near and some far."""
    near = drops(count, rng, 0.09, 700.0, 1500.0)
    far = drops(count, rng, 0.035, 1200.0, 2400.0)
    return [near[i] + far[i] * 0.35 for i in range(count)]


def layer_brook(count, rng):
    """A small brook: a quiet run of little bubbling drops."""
    return drops(count, rng, 0.05, 500.0, 1100.0)


def bird_call(rng):
    """One small songbird phrase: a few quick whistles that slide in pitch."""
    out = []
    base = rng.uniform(2400.0, 4200.0)
    for _ in range(rng.randint(2, 6)):
        length = rng.uniform(0.05, 0.14)
        rise = rng.uniform(-0.35, 0.45)
        phase = 0.0
        for k in range(int(length * AMBIENCE_RATE)):
            t = k / AMBIENCE_RATE
            freq = base * (1.0 + rise * t / length) * (1.0 + 0.03 * math.sin(2.0 * math.pi * 38.0 * t))
            phase += 2.0 * math.pi * freq / AMBIENCE_RATE
            shape = math.sin(math.pi * t / length)
            out.append(math.sin(phase) * shape)
        out.extend([0.0] * int(rng.uniform(0.03, 0.12) * AMBIENCE_RATE))
    return out


def layer_birds(count, rng):
    out = [0.0] * count
    at = rng.uniform(0.5, 2.0)
    while at < LOOP_SECONDS - 2.0:
        call = bird_call(rng)
        level = rng.uniform(0.12, 0.35)
        start = int(at * AMBIENCE_RATE)
        for k, value in enumerate(call):
            if start + k < count:
                out[start + k] += value * level
        at += rng.uniform(2.0, 7.0)
    return out


def layer_cicadas(count, rng):
    """A hot afternoon buzz that swells and fades."""
    phase = rng.uniform(0.0, 6.0)
    out = []
    for i in range(count):
        t = i / AMBIENCE_RATE
        pulse = 0.5 + 0.5 * math.sin(2.0 * math.pi * 40.0 * t)
        rise = max(0.0, math.sin(2.0 * math.pi * t / 15.0 + phase)) ** 2
        out.append(math.sin(2.0 * math.pi * 3800.0 * t) * pulse * rise)
    return out


def layer_crickets(count, rng):
    """Crickets chirping in threes, far off in the grass."""
    out = [0.0] * count
    at = 0.3
    freq = rng.uniform(3900.0, 4500.0)
    while at < LOOP_SECONDS - 1.0:
        for n in range(3):
            start = int((at + n * 0.045) * AMBIENCE_RATE)
            for k in range(int(0.025 * AMBIENCE_RATE)):
                if start + k < count:
                    t = k / AMBIENCE_RATE
                    out[start + k] += math.sin(2.0 * math.pi * freq * t) * math.sin(math.pi * t / 0.025) * 0.3
        at += rng.uniform(0.55, 0.9)
    return out


LAYERS = {"rain": layer_rain, "brook": layer_brook, "birds": layer_birds, "cicadas": layer_cicadas, "crickets": layer_crickets}


def make_ambience(path, recipe):
    """A one-minute loop of calm nature sounds, with its end blended into its start so it never jumps."""
    rng = random.Random(recipe["seed"])
    fade = int(3.0 * AMBIENCE_RATE)
    count = int(LOOP_SECONDS * AMBIENCE_RATE)
    track = [0.0] * (count + fade)
    for name, level in recipe.items():
        if name == "seed":
            continue
        sound = LAYERS[name](count + fade, rng)
        peak = max(1e-6, max(abs(v) for v in sound))
        for i, value in enumerate(sound):
            track[i] += value / peak * level
    for i in range(fade):
        mixed = i / fade
        track[i] = track[i] * math.sqrt(mixed) + track[count + i] * math.sqrt(1.0 - mixed)
    track = track[:count]
    # One steady volume for the whole loop: calm but clearly heard on a phone, and never clipped.
    peak = max(1e-6, max(abs(v) for v in track))
    rms = math.sqrt(sum(v * v for v in track) / count)
    gain = min(0.09 / max(rms, 1e-6), 0.95 / peak)
    data = array.array("h", (int(max(-1.0, min(1.0, v * gain)) * 32767) for v in track))
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(AMBIENCE_RATE)
        out.writeframes(data.tobytes())


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


def main():
    rng = random.Random(5)
    write_wav(os.path.join(OUT, "hoe.wav"), thud(0.16, 95.0, 26.0, 0.8, rng))
    write_wav(os.path.join(OUT, "water.wav"), splash(rng))
    write_wav(os.path.join(OUT, "harvest.wav"), chord([392.0, 523.25, 659.25], 0.4, 0.07, rng))
    write_wav(os.path.join(OUT, "chop.wav"), thud(0.2, 170.0, 24.0, 1.0, rng))
    write_wav(os.path.join(OUT, "mine.wav"), [a + b for a, b in zip(tone(1250.0, 0.22, 26.0, 0.5), thud(0.22, 240.0, 30.0, 0.7, rng))])
    write_wav(os.path.join(OUT, "level.wav"), chord([293.66, 369.99, 440.0, 587.33, 739.99], 0.8, 0.11, rng))
    make_season_sounds()


def make_season_sounds():
    for name, recipe in SEASONS.items():
        make_ambience(os.path.join(OUT, "nature_%s.wav" % name), recipe)


if __name__ == "__main__":
    import sys
    if sys.argv[1:] == ["nature"]:
        make_season_sounds()
    else:
        main()
