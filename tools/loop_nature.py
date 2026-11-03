#!/usr/bin/env python3
# tools/loop_nature.py
# Purpose: Turns real nature recordings into the game's seamless background loops.
# The recordings are CC0 from BigSoundBank (bigsoundbank.com, by Joseph Sardin); no credit is needed.
# Run from the project root with the downloaded files in one folder:
#   python3 tools/loop_nature.py <folder with 2715.ogg 1020.ogg 1859.ogg 1290.ogg 0219.ogg>

import array
import math
import os
import subprocess
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/audio/nature")
RATE = 32000
FADE = 3.0
# name: source sound number, start second, length in seconds, loudness (average level in dB).
# The bird recordings are kept nearly whole: the game plays a different stretch of them each time.
LOOPS = {
    "birds_forest": ("2715", 1.0, 155.0, -26.0),
    "birds_evening": ("1859", 1.0, 230.0, -26.0),
    "cricket": ("1020", 1.0, 28.0, -33.0),
    "rain": ("1290", 4.0, 70.0, -27.0),
    "waterfall": ("0219", 2.0, 40.0, -31.0),
}


def read_mono(path, start, seconds):
    """Decodes a stretch of the recording to mono samples between -1 and 1."""
    raw = subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-ss", str(start), "-t", str(seconds), "-i", path,
         "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"],
        check=True, capture_output=True).stdout
    data = array.array("h")
    data.frombytes(raw)
    return [v / 32768.0 for v in data]


def make_loop(source_dir, name, number, start, length, loudness):
    samples = read_mono(os.path.join(source_dir, number + ".ogg"), start, length + FADE)
    count = int(length * RATE)
    fade = int(FADE * RATE)
    if len(samples) < count + fade:
        raise SystemExit("%s is shorter than its loop" % name)
    # The last few seconds fade into the first few, so the loop comes round with no jump.
    loop = samples[:count]
    for i in range(fade):
        mixed = i / fade
        loop[i] = loop[i] * math.sqrt(mixed) + samples[count + i] * math.sqrt(1.0 - mixed)
    rms = math.sqrt(sum(v * v for v in loop) / count)
    peak = max(1e-6, max(abs(v) for v in loop))
    gain = min(10.0 ** (loudness / 20.0) / max(rms, 1e-6), 0.95 / peak)
    data = array.array("h", (int(max(-1.0, min(1.0, v * gain)) * 32767) for v in loop))
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data.tobytes())
    print(name, "%.0fs" % length, "gain %.2f" % gain)


def main():
    if len(sys.argv) < 2:
        raise SystemExit("Give the folder that holds the downloaded recordings.")
    os.makedirs(OUT, exist_ok=True)
    for name, (number, start, length, loudness) in LOOPS.items():
        make_loop(sys.argv[1], name, number, start, length, loudness)


if __name__ == "__main__":
    main()
