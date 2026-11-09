"""Synthesizes the app's sound effects into assets/sounds/ (Ogg Vorbis, mono)
and assets/sounds/ios/ (IMA4 in CAF, for iOS).

Usage:  python tools/sounds/make_sounds.py

Needs ffmpeg on PATH (winget install Gyan.FFmpeg): each sound is rendered
to a 16-bit WAV in a temporary folder and encoded to Ogg Vorbis, about a
sixth of the WAV's size; Android's SoundPool plays Ogg natively. iOS cannot
play Ogg, so each sound is also encoded to IMA4 ADPCM in a CAF file (a
quarter of the WAV, no encoder delay, so a tap sounds at once; AVAudioPlayer
plays it natively).

No samples, no licences: every sound is a few sine partials with an envelope,
so the files are small and reproducible. Each sound is short and soft; they
are mixed at about -6 dBFS and the app plays them at 70 % volume.

lib/data/sound.dart (enum Sfx) names the files; a test checks they exist.
"""

from __future__ import annotations

import math
import shutil
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "sounds"
IOS_OUT = OUT / "ios"
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


def whoosh(length: float, *, start_hz: float, end_hz: float, seed: int) -> list[float]:
    """Soft air: noise through a one-pole low-pass whose cutoff sweeps from
    [start_hz] to [end_hz], with a rise-and-fall envelope."""
    import random

    rng = random.Random(seed)
    n = int(RATE * length)
    out = []
    y = 0.0
    for i in range(n):
        p = i / n
        cutoff = start_hz * (end_hz / start_hz) ** p
        a = 1 - math.exp(-2 * math.pi * cutoff / RATE)
        y += a * (rng.uniform(-1, 1) - y)
        env = math.sin(math.pi * p) ** 1.5
        out.append(env * y)
    return out


BELL = ((1, 1.0), (2, 0.35), (3, 0.12), (4.2, 0.05))
SOFT = ((1, 1.0), (2, 0.15))


# Loudness of each sound relative to the others (1 = PEAK). The sounds
# that come with every tap or page stay well below the game's own.
GAIN = {"tap": 0.35, "page": 0.4, "back": 0.35, "intro": 0.8}


def sounds() -> dict[str, list[float]]:
    return {
        # App opening: the name in three soft notes (ka-ba-ca), rising.
        "intro": mix(
            (0.00, tone(note("G5"), 0.30, decay=8, partials=BELL)),
            (0.11, tone(note("C6"), 0.30, decay=8, partials=BELL)),
            (0.22, tone(note("E6"), 0.70, decay=4.5, partials=BELL)),
            (0.22, tone(note("C5"), 0.70, decay=4.5, partials=SOFT)),
        ),
        # Any button, card or key: a tiny, dry click.
        "tap": tone(1400, 0.035, attack=0.001, decay=140, partials=((1, 1.0), (2.3, 0.3))),
        # A page opens: air rising.
        "page": whoosh(0.20, start_hz=500, end_hz=3500, seed=1),
        # Back to the previous page: air falling.
        "back": whoosh(0.18, start_hz=3000, end_hz=450, seed=2),
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


def write(path: Path, samples: list[float], gain: float = 1.0) -> None:
    top = max(abs(v) for v in samples) or 1.0
    frames = b"".join(struct.pack("<h", int(32767 * PEAK * gain * v / top)) for v in samples)
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(frames)


# Vorbis quality (-1…10); 4 is transparent for these short, soft tones.
OGG_QUALITY = "4"


def encode(wav: Path, ogg: Path, ffmpeg: str) -> None:
    subprocess.run(
        [ffmpeg, "-y", "-loglevel", "error", "-i", str(wav),
         "-c:a", "libvorbis", "-q:a", OGG_QUALITY, "-map_metadata", "-1", str(ogg)],
        check=True,
    )


def encode_ios(wav: Path, caf: Path, ffmpeg: str) -> None:
    subprocess.run(
        [ffmpeg, "-y", "-loglevel", "error", "-i", str(wav),
         "-c:a", "adpcm_ima_qt", "-map_metadata", "-1", "-f", "caf", str(caf)],
        check=True,
    )


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        print("ffmpeg bulunamadı: winget install Gyan.FFmpeg")
        return 1
    OUT.mkdir(parents=True, exist_ok=True)
    IOS_OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.wav"):
        old.unlink()
    total = 0
    with tempfile.TemporaryDirectory() as tmp:
        for name, samples in sounds().items():
            wav = Path(tmp) / f"{name}.wav"
            write(wav, samples, GAIN.get(name, 1.0))
            path = OUT / f"{name}.ogg"
            encode(wav, path, ffmpeg)
            caf = IOS_OUT / f"{name}.caf"
            encode_ios(wav, caf, ffmpeg)
            size = path.stat().st_size
            total += size + caf.stat().st_size
            print(f"  {path.relative_to(ROOT)}  {len(samples) / RATE:.2f} sn  {size / 1024:.1f} KB")
    print(f"Toplam {total // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
