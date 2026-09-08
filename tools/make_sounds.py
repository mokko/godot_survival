#!/usr/bin/env python3
"""Generate simple synthesized sound effects for survivalm (16-bit mono WAVs).

Existing files (orb_pickup.wav, game_over.wav) are left alone. New:
  jump.wav      - quick upward pitch blip
  land.wav      - soft low thud
  grab.wav      - short rising click (block pickup)
  drop.wav      - short falling click (block release)
  step.wav      - very quiet footstep tick (kept subtle)
  splash.wav    - noise burst with lowpass-ish decay (falling in water)
  splash_menu.wav - not used; placeholder for future UI sounds
Run:  python3 tools/make_sounds.py
"""
import math
import struct
import wave
from pathlib import Path

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "sounds"
OUT.mkdir(exist_ok=True)


def write_wav(name: str, samples: list[float]) -> None:
    # Normalize to 0.8 peak.
    peak = max(abs(s) for s in samples) or 1.0
    data = b"".join(struct.pack("<h", int(s / peak * 0.8 * 32767))
                    for s in samples)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(f"{name}: {len(samples)} frames, {len(data)} bytes")


def env(i: int, n: int, attack: float = 0.01, curve: float = 3.0) -> float:
    """Attack-decay envelope, attack fraction of length, pow decay."""
    t = i / n
    a = min(1.0, t / max(attack, 1e-6)) if attack > 0 else 1.0
    return a * (1.0 - t) ** curve


def tone(dur: float, f_start: float, f_end: float,
         harmonics=((1.0, 1.0),), curve: float = 3.0) -> list[float]:
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f_start + (f_end - f_start) * t
        phase += 2 * math.pi * f / SR
        s = sum(a * math.sin(phase * h) for h, a in harmonics)
        out.append(s * env(i, n, curve=curve))
    return out


def noise(dur: float, lp: float = 0.2, curve: float = 4.0) -> list[float]:
    """Filtered noise: one-pole lowpass over white noise."""
    import random
    random.seed(7)
    n = int(SR * dur)
    out, y = [], 0.0
    for i in range(n):
        y += lp * (random.uniform(-1, 1) - y)
        out.append(y * env(i, n, curve=curve))
    return out


def mix(*layers: list[float]) -> list[float]:
    n = max(len(x) for x in layers)
    return [sum(x[i] if i < len(x) else 0.0 for x in layers) for i in range(n)]


write_wav("jump.wav", tone(0.22, 280, 660, harmonics=((1.0, 1.0), (2.0, 0.3))))
write_wav("land.wav", mix(tone(0.15, 140, 60, curve=5.0), noise(0.15, 0.08)))
write_wav("grab.wav", tone(0.09, 500, 900, curve=2.0))
write_wav("drop.wav", tone(0.09, 900, 450, curve=2.0))
write_wav("step.wav", noise(0.07, 0.12, curve=6.0))
write_wav("splash.wav", mix(noise(0.5, 0.25, curve=2.5),
                            tone(0.5, 300, 90, curve=3.0)))
