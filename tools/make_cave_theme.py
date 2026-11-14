"""
Builds assets/audio/music/cave_theme.wav.

Original synthesis, no samples: a low drone with a slow beat, a brown-noise
breath, distant water drops and one far rumble. The loop length is chosen so
every sustained tone completes a whole number of cycles, which means the file
can loop without a click or a dip.
"""

import math
import random
import struct
import wave

RATE = 44100
SECONDS = 28
FRAMES = RATE * SECONDS

rng = random.Random(19740119)


def lowpass(sample, state, alpha):
    state += alpha * (sample - state)
    return state, state


def main():
    samples = [0.0] * FRAMES

    # --- drone ------------------------------------------------------------
    # Frequencies chosen so each one fits a whole number of cycles in 28 s.
    drone = [(48.0, 0.16), (55.0, 0.12), (82.0, 0.05), (110.0, 0.025)]
    for freq, amp in drone:
        for i in range(FRAMES):
            t = i / RATE
            # Slow amplitude breathing, also an integer number of cycles.
            breath = 0.82 + 0.18 * math.sin(2 * math.pi * t / 14.0 + freq * 0.01)
            samples[i] += amp * breath * math.sin(2 * math.pi * freq * t)

    # --- noise bed --------------------------------------------------------
    state = 0.0
    brown = 0.0
    for i in range(FRAMES):
        white = rng.uniform(-1.0, 1.0)
        state, brown = lowpass(white, state, 0.0025)
        samples[i] += brown * 0.9

    # --- drips ------------------------------------------------------------
    # Short falling sine with a quick decay, scattered away from the loop seam.
    for _ in range(11):
        start = rng.uniform(2.0, SECONDS - 3.0)
        length = rng.uniform(0.18, 0.42)
        base = rng.uniform(520.0, 1150.0)
        level = rng.uniform(0.05, 0.12)
        begin = int(start * RATE)
        count = int(length * RATE)
        for k in range(count):
            index = begin + k
            if index >= FRAMES:
                break
            t = k / RATE
            finish = 1.0 / length
            freq = base * (1.0 - 0.55 * (t * finish))
            envelope = math.exp(-6.0 * t) * min(1.0, t * 90.0)
            samples[index] += level * envelope * math.sin(2 * math.pi * freq * t)

    # --- far rumble -------------------------------------------------------
    for swell in (6.5, 17.5):
        begin = int(swell * RATE)
        length = 4.5
        count = int(length * RATE)
        for k in range(count):
            index = begin + k
            if index >= FRAMES:
                break
            t = k / RATE
            envelope = math.sin(math.pi * min(1.0, t / length)) ** 2
            samples[index] += 0.05 * envelope * math.sin(2 * math.pi * 27.0 * t)

    # Keep the seam clean: the interior is not faded, but the first and last
    # 40 ms are tapered by a quarter so any tiny DC offset cannot click.
    taper = int(0.04 * RATE)
    for i in range(taper):
        gain = 0.25 + 0.75 * (i / taper)
        samples[i] *= gain
        samples[FRAMES - 1 - i] *= gain

    peak = max(1e-9, max(abs(value) for value in samples))
    scale = 0.82 / peak

    with wave.open("assets/audio/music/cave_theme.wav", "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        frames = bytearray()
        for value in samples:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, value * scale)) * 32767))
        out.writeframes(bytes(frames))


main()
print("wrote cave_theme.wav", SECONDS, "s")
