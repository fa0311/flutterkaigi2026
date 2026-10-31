"""Synthesizes every sound effect of the game (standard library only, no
recordings).

    python3 app/tool/build_game_audio.py

Writes 44.1 kHz 16-bit mono WAVs to assets/audio/recruit_exam/:

- countdown_tick.wav, countdown_go.wav: "3, 2, 1" and "Start!".
- catch_1.wav .. catch_8.wav: a good catch. Each combo step climbs a
  pentatonic scale from C6 and stays on the top note from the eighth catch.
- catch_bad.wav: a bad catch; a falling, buzzing thud.
- combo_1.wav .. combo_4.wav: combo milestones (3, 5, 8, 10); a quick upward
  arpeggio whose key rises with the tier.
- result_pass.wav, result_fail.wav: the verdict on the result dialog; a
  fanfare, or a sad trombone.
- cheer.wav: a synthetic crowd swell layered under the pass fanfare.
- score_tick.wav: one blip per ten points while the result counts up.
- miss.wav: a good drop lands uncaught.
- hurry.wav: a double tick for each of the last five seconds.
- firework.wav: pop and crackle for the sky bursts at a milestone.
- fever_loop.wav: a two-second riff that loops while the combo is in fever.

The app reads them through relative symlinks in app/assets/audio/.
"""

import array
import math
import pathlib
import random
import wave

RATE = 44100
OUT = pathlib.Path(__file__).resolve().parents[2] / "assets/audio/recruit_exam"
BEEP = ((1, 1.0), (2, 0.28), (3, 0.12))
BRIGHT = ((1, 1.0), (2, 0.36), (3, 0.14), (4, 0.06))
SOFT = ((1, 1.0), (2, 0.14), (3, 0.04))


def tone(freqs, seconds, decay, attack=0.004, harmonics=BEEP):
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        # A few soft harmonics make a clear electronic beep, not a pure sine.
        v = sum(
            amp * math.sin(2 * math.pi * f * n * t)
            for f in freqs
            for n, amp in harmonics
        )
        env = min(t / attack, 1) * math.exp(-t / decay)
        tail = min(max((seconds - t) / 0.02, 0), 1)
        out.append(v * env * tail)
    return out


def mix(parts):
    """Sums (offset seconds, samples) pairs into one buffer."""
    length = max(int(RATE * at) + len(s) for at, s in parts)
    out = [0.0] * length
    for at, samples in parts:
        start = int(RATE * at)
        for i, v in enumerate(samples):
            out[start + i] += v
    return out


def arpeggio(notes, step, seconds, decay, harmonics=BRIGHT):
    return mix(
        [(i * step, tone([f], seconds, decay, harmonics=harmonics))
         for i, f in enumerate(notes)]
    )


def thud(seconds=0.38):
    """Falling buzz with a short noise crack: the bad catch."""
    rng = random.Random(1)
    out, phase = [], 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        f = 70 + 170 * math.exp(-t * 3.2)
        phase += 2 * math.pi * f / RATE
        # Odd harmonics make a square-ish buzz.
        v = sum(math.sin(n * phase) / n for n in (1, 3, 5, 7))
        v += rng.uniform(-1, 1) * 0.55 * math.exp(-t / 0.018)
        env = min(t / 0.002, 1) * math.exp(-t / 0.14)
        tail = min(max((seconds - t) / 0.02, 0), 1)
        out.append(v * env * tail)
    return out


def slide(f0, f1, seconds, decay, harmonics=SOFT, attack=0.003):
    """A tone gliding exponentially from f0 to f1."""
    out, phase = [], 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        f = f0 * (f1 / f0) ** (t / seconds)
        phase += 2 * math.pi * f / RATE
        v = sum(amp * math.sin(n * phase) for n, amp in harmonics)
        env = min(t / attack, 1) * math.exp(-t / decay)
        tail = min(max((seconds - t) / 0.02, 0), 1)
        out.append(v * env * tail)
    return out


def trombone(notes):
    """Sad trombone: brassy notes that each droop in, the last one wobbling
    and sagging away. notes = [(freq, seconds), ...]."""
    out, phase = [], 0.0
    total = sum(d for _, d in notes)
    start = 0.0
    for k, (f, seconds) in enumerate(notes):
        last = k == len(notes) - 1
        for i in range(int(RATE * seconds)):
            t = i / RATE
            freq = f * (1.04 - 0.04 * min(t / 0.08, 1))
            if last:
                freq *= 1 + 0.015 * math.sin(2 * math.pi * 5.5 * t)
                freq *= 0.82 ** max(0, (t - seconds * 0.45) / (seconds * 0.55))
            phase += 2 * math.pi * freq / RATE
            v = sum(math.sin(n * phase) / n for n in range(1, 8))
            env = min(t / 0.02, 1) * (
                math.exp(-t / 2.0) if last else min(max((seconds - t) / 0.04, 0), 1)
            )
            out.append(v * env)
        start += seconds
    return out


def noise(seconds, decay, rng, gate=1.0, attack=0.001):
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        on = 1.0 if rng.random() < gate else 0.0
        env = min(t / attack, 1) * math.exp(-t / decay)
        out.append(rng.uniform(-1, 1) * on * env)
    return out


def cheer(seconds=1.8, voices=28):
    """A crowd swell: many detuned partials with their own slow wobble."""
    rng = random.Random(4)
    parts = [
        (rng.uniform(220, 2400), rng.uniform(2, 9), rng.uniform(0, 6.28))
        for _ in range(voices)
    ]
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        v = sum(
            math.sin(2 * math.pi * f * t + ph) * (0.6 + 0.4 * math.sin(2 * math.pi * am * t))
            for f, am, ph in parts
        ) / voices
        v += rng.uniform(-1, 1) * 0.08
        env = min(t / 0.3, 1) * (1 if t < 1.0 else math.exp(-(t - 1.0) / 0.35))
        out.append(v * env)
    return out


def fever_loop(seconds=2.0):
    """Sixteenth-note riff over a square bass, cut so it loops cleanly."""
    step = seconds / 16
    melody = [C6, E6, G6, C7, E7, C7, G6, E6, D6, G6, B6, D7, G7, D7, B6, G6]
    parts = [
        (k * step, tone([f], step * 0.9, 0.045, harmonics=BRIGHT))
        for k, f in enumerate(melody)
    ]
    for beat in range(4):
        bass = 130.81 if beat % 2 == 0 else 196.0
        parts.append(
            (beat * step * 4, tone([bass], step * 1.6, 0.09, harmonics=((1, 1), (3, 0.33), (5, 0.2))))
        )
    rng = random.Random(9)
    for k in range(16):
        if k % 2 == 1:
            parts.append((k * step, noise(0.03, 0.01, rng)))
    out = mix(parts)
    return out[: int(RATE * seconds)]


def write(name, samples, peak):
    scale = peak / max(abs(s) for s in samples)
    OUT.mkdir(parents=True, exist_ok=True)
    data = array.array("h", (round(s * scale * 32767) for s in samples))
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


C4, E4 = 261.63, 329.63
C5, E5, G5 = 523.25, 659.25, 783.99
C6, D6, E6, FS6, G6, GS6, A6, B6 = (
    1046.50, 1174.66, 1318.51, 1479.98, 1567.98, 1661.22, 1760.00, 1975.53,
)
C7, D7, E7, G7 = 2093.00, 2349.32, 2637.02, 3135.96

# G5 for each count, then an octave-up G6 + D7 chord that rings longer. The
# rounded frequencies keep these two files byte-identical to the 2026-10-27
# originals.
write("countdown_tick.wav", tone([784], 0.22, 0.07), peak=0.7)
write("countdown_go.wav", tone([1568, 2349], 0.75, 0.22), peak=0.8)

# Good catches climb C6 pentatonic; a little brighter on each step.
for i, f in enumerate([C6, D6, E6, G6, A6, C7, D7, E7], start=1):
    write(f"catch_{i}.wav", tone([f], 0.24, 0.075, harmonics=BRIGHT), peak=0.62)

write("catch_bad.wav", thud(), peak=0.78)

# Milestone chimes: three or four notes upward, each tier in a higher key.
for i, notes in enumerate(
    [[C6, E6, G6], [D6, FS6, A6, D7], [E6, GS6, B6, E7], [G6, B6, D7, G7]],
    start=1,
):
    chime = arpeggio(notes, 0.06, 0.42, 0.13)
    if i == 4:
        chime = mix([(0, chime), (0.18, tone(notes[1:], 0.7, 0.26))])
    write(f"combo_{i}.wav", chime, peak=0.72)

# Pass: a rising run into a held major chord. Fail: two soft falling notes.
write(
    "result_pass.wav",
    mix(
        [
            (0, arpeggio([C5, E5, G5, C6], 0.09, 0.3, 0.1)),
            (0.36, tone([C6, E6, G6], 1.1, 0.34)),
        ]
    ),
    peak=0.8,
)
# Fail: the sad trombone, Bb3 A3 Ab3 then a sagging G3.
write(
    "result_fail.wav",
    trombone([(233.08, 0.36), (220.0, 0.36), (207.65, 0.36), (196.0, 1.3)]),
    peak=0.6,
)
write("cheer.wav", cheer(), peak=0.5)
write("score_tick.wav", tone([2500], 0.05, 0.015), peak=0.5)
write("miss.wav", slide(520, 170, 0.3, 0.12), peak=0.5)
write(
    "hurry.wav",
    mix([(0, tone([880], 0.08, 0.03)), (0.1, tone([880], 0.08, 0.03))]),
    peak=0.7,
)
_rng = random.Random(2)
write(
    "firework.wav",
    mix(
        [
            (0, slide(420, 110, 0.1, 0.05, harmonics=BEEP)),
            (0.05, noise(0.7, 0.25, _rng, gate=0.35)),
        ]
    ),
    peak=0.6,
)
write("fever_loop.wav", fever_loop(), peak=0.55)
