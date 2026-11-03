#!/usr/bin/env python3
# tools/make_audio.py
# Purpose: Writes the game's original music and sound effects, using only math.
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


HIJAZ = [146.83, 155.56, 185.00, 196.00, 220.00, 233.08, 261.63, 293.66, 311.13, 369.99, 392.00]
# D Bayati with the quarter tone rounded to the nearest note, for a softer winter tune.
BAYATI = [146.83, 160.0, 174.61, 196.00, 220.00, 233.08, 261.63, 293.66, 320.0, 349.23, 392.00]
# Each season's tune: seed, scale, beats per minute, pitch shift, drum level, and how long the strings ring.
SEASONS = {
    "summer": (34, HIJAZ, 78.0, 1.0, 1.3, 0.996),
    "autumn": (55, HIJAZ, 60.0, 0.75, 0.8, 0.997),
    "winter": (89, BAYATI, 54.0, 1.0, 0.4, 0.998),
}


def make_music(path, seed=21, scale=HIJAZ, bpm=66.0, shift=1.0, drums=1.0, ring=0.996):
    """Slow original melody on an Arabic scale: oud, low drone, and a soft frame drum."""
    rng = random.Random(seed)
    scale = [f * shift for f in scale]
    beat = 60.0 / bpm
    # Each pair is a scale step and a length in beats. None is a rest.
    phrases = [
        [(7, 1), (6, 0.5), (5, 0.5), (4, 2), (2, 1), (3, 1), (4, 2), (None, 2)],
        [(4, 1), (5, 1), (6, 1), (7, 1), (6, 0.5), (5, 0.5), (4, 1), (3, 2), (None, 2)],
        [(0, 1), (1, 0.5), (2, 0.5), (3, 1), (4, 1), (3, 0.5), (2, 0.5), (1, 1), (0, 2), (None, 2)],
        [(7, 1.5), (8, 0.5), (9, 1), (8, 1), (7, 1), (6, 1), (5, 2), (None, 2)],
        [(4, 1), (6, 1), (5, 1), (4, 1), (3, 0.5), (2, 0.5), (3, 1), (4, 2), (None, 2)],
        [(3, 1), (2, 1), (1, 1), (0, 3), (None, 2)],
    ]
    if seed != 21:
        # Other seasons play the same phrases in their own order, so each tune sounds new.
        rng.shuffle(phrases)
    bars = 16
    seconds = bars * 4 * beat + 2.0
    track = [0.0] * int(seconds * RATE)
    at = 0.0
    for phrase in phrases:
        for step, length in phrase:
            if step is not None:
                note = pluck(scale[step], 2.2, rng, bright=0.55, damping=ring)
                mix(track, note, at, 0.42)
                if rng.random() < 0.22:
                    mix(track, pluck(scale[step], 1.4, rng, bright=0.5), at + beat * 0.25, 0.18)
            at += length * beat
    for bar in range(bars):
        start = bar * 4 * beat
        mix(track, pluck(73.42 * shift, 4.0, rng, bright=0.5, damping=0.998), start, 0.34)
        if bar % 2 == 1:
            mix(track, pluck(110.0 * shift, 3.0, rng, bright=0.5, damping=0.998), start + 2 * beat, 0.2)
        mix(track, drum(0.4, 92.0, rng), start, 0.14 * drums)
        mix(track, drum(0.2, 210.0, rng, 0.4), start + 1.5 * beat, 0.05 * drums)
        mix(track, drum(0.4, 92.0, rng), start + 2 * beat, 0.09 * drums)
        mix(track, drum(0.2, 210.0, rng, 0.4), start + 3 * beat, 0.05 * drums)
    fade = int(1.5 * RATE)
    for i in range(fade):
        track[-1 - i] *= i / fade
    temp = path + ".wav"
    write_wav(temp, track)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", temp, "-codec:a", "libmp3lame", "-b:a", "56k", path], check=True)
    os.remove(temp)


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
    make_music(os.path.join(OUT, "music_village.mp3"))
    make_season_music()


def make_season_music():
    for name, (seed, scale, bpm, shift, drums, ring) in SEASONS.items():
        make_music(os.path.join(OUT, "music_%s.mp3" % name), seed, scale, bpm, shift, drums, ring)


if __name__ == "__main__":
    import sys
    if sys.argv[1:] == ["seasons"]:
        make_season_music()
    else:
        main()
