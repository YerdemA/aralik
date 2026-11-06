"""Synthesizes the app's sound effects into assets/sounds/ (WAV, mono, 16 bit).

Usage:  python tools/sounds/make_sounds.py

No samples, no licences: every sound is a few sine partials with an envelope,
so the files are small and reproducible. Each sound is short and soft; they
are mixed at about -6 dBFS and the app plays them at 70 % volume.

lib/data/sound.dart (enum Sfx) names the files; a test checks they exist.
"""

from __future__ import annotations

import math
import struct
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "sounds"
RATE = 16000
PEAK = 0.5  # about -6 dBFS


def note(name: str) -> float:
    """'A4' → 440 Hz."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[name[0]] + (1 if "#" in name else -1 if "b" in name[1:] else 0)
    octave = int(name[-1])
    return 440.0 * 2 ** ((semis + 12 * (octave - 4)) / 12)


def tone(freq: float, length: float, *, attack=0.005, decay=6.0, partials=((1, 1.0), (2, 0.3), (3, 0.1)),
         glide: float = 0.0) -> list[float]:
    """A plucked/bell-like tone: fast attack, exponential decay; [glide] bends
    the pitch by that ratio over the length (e.g. -0.3 falls)."""
    n = int(RATE * length)
    out = []
    phase = [0.0] * len(partials)
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        f = freq * (1 + glide * t / length)
        s = 0.0
        for k, (mult, amp) in enumerate(partials):
            phase[k] += 2 * math.pi * f * mult / RATE
            s += amp * math.sin(phase[k])
        out.append(env * s)
    # A short fade-out so no file ends with a click.
    fade = min(n, int(RATE * 0.01))
    for i in range(fade):
        out[n - fade + i] *= 1 - (i + 1) / fade
    return out


def mix(*parts: tuple[float, list[float]]) -> list[float]:
    """Places each (start seconds, samples) on one track."""
    end = max(int(start * RATE) + len(s) for start, s in parts)
    track = [0.0] * end
    for start, samples in parts:
        offset = int(start * RATE)
        for i, v in enumerate(samples):
            track[offset + i] += v
    return track


def noise_tick(length: float) -> list[float]:
    """A dry wooden tick: a high, very short tone with a click."""
    return [a + b for a, b in zip(
        tone(1900, length, attack=0.001, decay=90, partials=((1, 1.0), (2.7, 0.4))),
        tone(950, length, attack=0.001, decay=60, partials=((1, 0.6),)),
    )]


BELL = ((1, 1.0), (2, 0.35), (3, 0.12), (4.2, 0.05))
SOFT = ((1, 1.0), (2, 0.15))


def sounds() -> dict[str, list[float]]:
    return {
        # Locking an interval: a short, round pop.
        "lock": tone(note("A5"), 0.09, attack=0.002, decay=45, partials=SOFT, glide=-0.25),
        # A hit with ≥70 points: a quick rising arpeggio.
        "good": mix(
            (0.00, tone(note("C6"), 0.35, decay=9, partials=BELL)),
            (0.07, tone(note("E6"), 0.35, decay=9, partials=BELL)),
            (0.14, tone(note("G6"), 0.55, decay=6, partials=BELL)),
        ),
        # A hit with a wide interval: two notes up.
        "partial": mix(
            (0.00, tone(note("G5"), 0.30, decay=10, partials=BELL)),
            (0.08, tone(note("C6"), 0.40, decay=8, partials=BELL)),
        ),
        # A miss: two soft notes falling.
        "miss": mix(
            (0.00, tone(note("E4"), 0.25, decay=10, partials=SOFT)),
            (0.12, tone(note("B3"), 0.40, decay=7, partials=SOFT, glide=-0.04)),
        ),
        # Each of the last five seconds.
        "tick": noise_tick(0.05),
        # The end of a set or a free-play round: a small fanfare.
        "done": mix(
            (0.00, tone(note("C5"), 0.30, decay=7, partials=BELL)),
            (0.10, tone(note("E5"), 0.30, decay=7, partials=BELL)),
            (0.20, tone(note("G5"), 0.30, decay=7, partials=BELL)),
            (0.30, tone(note("C6"), 0.90, decay=3.5, partials=BELL)),
            (0.30, tone(note("E6"), 0.90, decay=3.5, partials=SOFT)),
        ),
        # A duel starts: two bright bells.
        "duel_start": mix(
            (0.00, tone(note("E6"), 0.30, decay=9, partials=BELL)),
            (0.15, tone(note("E6"), 0.45, decay=7, partials=BELL)),
        ),
        # Duel won: the fanfare a step higher, with a final chord.
        "duel_win": mix(
            (0.00, tone(note("D5"), 0.25, decay=7, partials=BELL)),
            (0.09, tone(note("F#5"), 0.25, decay=7, partials=BELL)),
            (0.18, tone(note("A5"), 0.25, decay=7, partials=BELL)),
            (0.27, tone(note("D6"), 1.10, decay=2.8, partials=BELL)),
            (0.27, tone(note("F#6"), 1.10, decay=2.8, partials=SOFT)),
            (0.27, tone(note("A5"), 1.10, decay=2.8, partials=SOFT)),
        ),
        # Duel lost: a gentle "aww", three falling notes.
        "duel_loss": mix(
            (0.00, tone(note("G4"), 0.35, decay=5, partials=SOFT)),
            (0.25, tone(note("F#4"), 0.35, decay=5, partials=SOFT)),
            (0.50, tone(note("F4"), 0.80, decay=3, partials=SOFT, glide=-0.03)),
        ),
        # Draw: two equal notes.
        "duel_draw": mix(
            (0.00, tone(note("C5"), 0.35, decay=7, partials=BELL)),
            (0.18, tone(note("C5"), 0.50, decay=6, partials=BELL)),
        ),
    }


def write(path: Path, samples: list[float]) -> None:
    top = max(abs(v) for v in samples) or 1.0
    frames = b"".join(struct.pack("<h", int(32767 * PEAK * v / top)) for v in samples)
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(frames)


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for name, samples in sounds().items():
        path = OUT / f"{name}.wav"
        write(path, samples)
        size = path.stat().st_size
        total += size
        print(f"  {path.relative_to(ROOT)}  {len(samples) / RATE:.2f} sn  {size // 1024} KB")
    print(f"Toplam {total // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
