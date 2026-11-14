#!/usr/bin/env python3
# tools/cut_sounds.py
# Purpose: Cuts footsteps and farm animal calls out of real recordings into short, quiet game clips.
# The recordings are CC0 from BigSoundBank (bigsoundbank.com, by Joseph Sardin); no credit is needed.
# Run from the project root with the downloaded files in one folder:
#   python3 tools/cut_sounds.py <folder with 0854.ogg 0510.ogg 0606.ogg 1515.ogg 0453.ogg 0976.ogg 1380.ogg ...>
# Footsteps land in assets/audio/steps/<ground>_<n>.wav and animals in assets/audio/animals/<animal>_<n>.wav.

import array
import math
import os
import subprocess
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RATE = 22050
# ground: source sound number. Each gives STEPS single steps.
STEPS_FROM = {"grass": "0854", "gravel": "0510", "stone": "0606", "wood": "1515"}
STEPS = 4
STEP_SECONDS = 0.28
# name: (source sound number, start second, longest length in seconds). Silence at both ends is trimmed.
ANIMALS = {
    "hen_1": ("0453", 0.0, 3.0),
    "hen_2": ("0976", 0.0, 2.5),
    "goat_1": ("1380", 0.0, 2.0),
    "goat_2": ("1381", 0.0, 2.0),
    "sheep_1": ("2343", 0.0, 1.5),
    "sheep_2": ("2344", 0.0, 1.5),
    "sheep_3": ("2345", 0.0, 1.5),
    "cow_1": ("2382", 0.0, 3.0),
    "cow_2": ("2383", 0.0, 3.0),
}


def read_mono(path, start=0.0, seconds=None):
    """Decodes a stretch of the recording to mono samples between -1 and 1."""
    command = ["ffmpeg", "-loglevel", "error", "-ss", str(start)]
    if seconds is not None:
        command += ["-t", str(seconds)]
    command += ["-i", path, "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"]
    raw = subprocess.run(command, check=True, capture_output=True).stdout
    data = array.array("h")
    data.frombytes(raw)
    return [v / 32768.0 for v in data]


def envelope(samples, window):
    """Loudness of each window of samples (root mean square)."""
    out = []
    for i in range(0, len(samples) - window, window):
        part = samples[i:i + window]
        out.append(math.sqrt(sum(v * v for v in part) / window))
    return out


def find_steps(samples, count):
    """Start sample of the clearest separate steps: loud jumps in the envelope, at least 0.25 s apart."""
    window = int(RATE * 0.01)
    env = envelope(samples, window)
    if not env:
        return []
    floor = sorted(env)[len(env) // 2]
    peaks = []
    for i in range(2, len(env) - 2):
        rise = env[i] - max(env[i - 2], env[i - 1])
        if env[i] >= env[i - 1] and env[i] >= env[i + 1] and env[i] > floor * 3.0 and rise > 0:
            peaks.append((env[i], i))
    peaks.sort(reverse=True)
    chosen = []
    for loud, i in peaks:
        if all(abs(i - j) * window > RATE * 0.25 for j in chosen):
            chosen.append(i)
        if len(chosen) >= count:
            break
    # Start a little before the peak, so the step's attack is kept.
    return sorted(max(0, i * window - int(RATE * 0.03)) for i in chosen)


def trim_silence(samples):
    window = int(RATE * 0.01)
    env = envelope(samples, window)
    if not env:
        return samples
    top = max(env)
    loud = [i for i, v in enumerate(env) if v > top * 0.06]
    if not loud:
        return samples
    first = max(0, loud[0] * window - int(RATE * 0.02))
    last = min(len(samples), (loud[-1] + 1) * window + int(RATE * 0.05))
    return samples[first:last]


def shape(samples, peak_db, fade_in, fade_out):
    """Brings the loudest sample to peak_db and fades both ends, so no clip clicks."""
    top = max((abs(v) for v in samples), default=0.0)
    gain = (10 ** (peak_db / 20.0)) / top if top > 0 else 1.0
    out = []
    n = len(samples)
    rise = max(1, int(RATE * fade_in))
    fall = max(1, int(RATE * fade_out))
    for i, v in enumerate(samples):
        k = 1.0
        if i < rise:
            k = i / rise
        if i > n - fall:
            k = min(k, (n - i) / fall)
        out.append(max(-1.0, min(1.0, v * gain * k)))
    return out


def write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = array.array("h", (int(v * 32767) for v in samples))
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data.tobytes())


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__ or "usage: cut_sounds.py <folder>")
    folder = sys.argv[1]
    for ground, number in STEPS_FROM.items():
        samples = read_mono(os.path.join(folder, number + ".ogg"))
        starts = find_steps(samples, STEPS)
        for n, start in enumerate(starts, 1):
            clip = samples[start:start + int(RATE * STEP_SECONDS)]
            write_wav(os.path.join(ROOT, "assets/audio/steps/%s_%d.wav" % (ground, n)), shape(clip, -3.0, 0.004, 0.12))
        print("%s: %d steps from %s" % (ground, len(starts), number))
    for name, (number, start, seconds) in ANIMALS.items():
        clip = trim_silence(read_mono(os.path.join(folder, number + ".ogg"), start, seconds))
        write_wav(os.path.join(ROOT, "assets/audio/animals/%s.wav" % name), shape(clip, -3.0, 0.02, 0.2))
        print("%s: %.2f s from %s" % (name, len(clip) / RATE, number))


if __name__ == "__main__":
    main()
