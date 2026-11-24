"""Offline instruments and circular mixing for Mosslight's original chapter scores."""
from functools import lru_cache
from pathlib import Path
import wave
import numpy as np

RATE = 44100


@lru_cache(maxsize=128)
def instrument(note: int, seconds: float, timbre: str) -> np.ndarray:
    t = np.arange(round(seconds * RATE), dtype=np.float64) / RATE
    frequency = 440 * 2 ** ((note - 69) / 12)
    remaining = np.maximum(seconds - t, 0)
    if timbre in ("reed", "bowed"):
        vibrato = .002 if timbre == "reed" else .0014
        phase = np.cumsum(frequency * (1 + vibrato * np.sin(2 * np.pi * 4.7 * t))) * (2 * np.pi / RATE)
        signal = np.sin(phase) + .1 * np.sin(phase * 2) + .035 * np.sin(phase * 3)
        attack = .04 if timbre == "reed" else .18
        envelope = (1 - np.exp(-t / attack)) * np.minimum(remaining / .13, 1) * np.exp(-t / 5)
    elif timbre == "pad":
        signal = (np.sin(2 * np.pi * frequency * t) + np.sin(2 * np.pi * frequency * 1.0012 * t + .24)) * .5
        signal += .06 * np.sin(2 * np.pi * frequency * 2 * t)
        envelope = np.minimum(t / .5, 1) * np.minimum(remaining / .85, 1)
    elif timbre == "bass":
        signal = np.sin(2 * np.pi * frequency * t) + .12 * np.sin(2 * np.pi * frequency * 2 * t)
        envelope = (1 - np.exp(-t / .016)) * np.exp(-t / .8) * np.minimum(remaining / .08, 1)
    elif timbre == "glass":
        signal = np.sin(2 * np.pi * frequency * t)
        signal += .16 * np.sin(2 * np.pi * frequency * 2.76 * t) * np.exp(-t * 2.5)
        signal += .025 * np.sin(2 * np.pi * frequency * 5.4 * t) * np.exp(-t * 4)
        envelope = (1 - np.exp(-t / .006)) * np.exp(-t / 1.05) * np.minimum(remaining / .12, 1)
    else:
        signal = np.sin(2 * np.pi * frequency * t)
        signal += .19 * np.sin(2 * np.pi * frequency * 2.003 * t) * np.exp(-t * 2)
        signal += .055 * np.sin(2 * np.pi * frequency * 3.99 * t) * np.exp(-t * 4)
        envelope = (1 - np.exp(-t / .004)) * np.exp(-t / .65) * np.minimum(remaining / .09, 1)
    result = signal * envelope
    result.setflags(write=False)
    return result


class Score:
    def __init__(self, bpm: int, bars: int, beats: int, seed: int):
        self.beat = 60 / bpm
        self.bar_beats = beats
        self.bars = bars
        self.mix = np.zeros((round(bars * beats * self.beat * RATE), 2), dtype=np.float64)
        self.rng = np.random.default_rng(seed)

    def add(self, signal, at: float, gain: float, pan: float = 0):
        gains = np.array([np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)]) * gain
        offset = round(at * RATE) % len(self.mix)
        count = min(len(signal), len(self.mix) - offset)
        self.mix[offset:offset + count] += signal[:count, None] * gains
        if count < len(signal):
            self.mix[:len(signal) - count] += signal[count:, None] * gains

    def note(self, bar: int, beat: float, pitch: int, length: float, timbre: str, gain: float, pan: float = 0):
        at = (bar * self.bar_beats + beat) * self.beat
        human = self.rng.uniform(-.003, .003) if timbre not in ("pad", "bass") else 0
        duration = round(max(.1, length * self.beat), 5)
        self.add(instrument(pitch, duration, timbre), at + human, gain, pan)

    def chord(self, bar: int, notes, gain: float):
        for i, note in enumerate(notes):
            self.note(bar, 0, note, self.bar_beats + 1.5, "pad", gain, (i - 1.5) / 2.5)

    def brush(self, bar: int, beat: float, gain: float, pan: float):
        t = np.arange(round(.085 * RATE)) / RATE
        noise = self.rng.standard_normal(len(t))
        brushed = np.convolve(noise, [0.2, 0.6, 0.2], mode="same") * np.exp(-t * 75)
        brushed *= np.minimum(t / .002, 1)
        self.add(brushed, (bar * self.bar_beats + beat) * self.beat, gain, pan)

    def write(self, path: Path):
        dry = self.mix.copy()
        for seconds, gain in [(.137, .1), (.283, .075), (.431, .055), (.719, .03)]:
            self.mix += np.roll(dry[:, ::-1], round(seconds * RATE), axis=0) * gain
        self.mix = np.tanh(self.mix * 1.1)
        self.mix *= .76 / max(float(np.max(np.abs(self.mix))), .001)
        assert np.isfinite(self.mix).all()
        pcm = np.rint(self.mix * 32767).astype("<i2")
        path.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(path), "wb") as output:
            output.setnchannels(2)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(pcm.tobytes())
        block = RATE
        levels = [float(np.sqrt(np.mean(self.mix[i:i + block] ** 2))) for i in range(0, len(self.mix), block)]
        return {
            "file": path.name,
            "seconds": round(len(self.mix) / RATE, 6),
            "peak_dbfs": round(float(20 * np.log10(np.max(np.abs(self.mix)))), 2),
            "rms_dbfs": round(float(20 * np.log10(np.sqrt(np.mean(self.mix ** 2)))), 2),
            "quietest_second_dbfs": round(float(20 * np.log10(min(levels))), 2),
            "loop_boundary_step": round(float(np.max(np.abs(self.mix[-1] - self.mix[0]))), 6),
        }
