"""Original Mosslight score. Rebuild with Python 3 and NumPy; no samples needed."""
from pathlib import Path
import json
import wave
import numpy as np

RATE = 44100
BPM = 96
BEAT = 60 / BPM
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "music"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(3407)


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def voice(pitch, seconds, kind):
    t = np.arange(round(seconds * RATE)) / RATE
    f = hz(pitch)
    release = np.minimum(1, (seconds - t) / 0.075).clip(0, 1)
    if kind == "flute":
        phase = 2 * np.pi * np.cumsum(f * (1 + 0.0025 * np.sin(2 * np.pi * 5 * t))) / RATE
        signal = np.sin(phase) + 0.12 * np.sin(2 * phase) + 0.025 * np.sin(3 * phase)
        env = (1 - np.exp(-t / 0.025)) * np.exp(-t / 3) * release
    elif kind == "pad":
        signal = (np.sin(2 * np.pi * f * t) + np.sin(2 * np.pi * f * 1.0017 * t + 0.3)) / 2
        signal += 0.09 * np.sin(2 * np.pi * f * 2 * t)
        env = np.minimum(t / 0.35, 1) * np.minimum((seconds - t) / 0.8, 1).clip(0, 1)
    elif kind == "bass":
        signal = np.sin(2 * np.pi * f * t) + 0.18 * np.sin(2 * np.pi * f * 2 * t)
        env = (1 - np.exp(-t / 0.012)) * np.exp(-t / 0.55) * release
    else:
        signal = np.sin(2 * np.pi * f * t)
        signal += 0.22 * np.sin(2 * np.pi * f * 2.001 * t) * np.exp(-t * 2)
        signal += 0.06 * np.sin(2 * np.pi * f * 3.998 * t) * np.exp(-t * 4)
        env = (1 - np.exp(-t / 0.003)) * np.exp(-t / 0.62) * release
    return signal * env


def add(mix, signal, start_seconds, volume, pan=0):
    gains = np.array([np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)])
    stereo = signal[:, None] * gains[None, :] * volume
    start = round(start_seconds * RATE) % len(mix)
    split = min(len(stereo), len(mix) - start)
    mix[start:start + split] += stereo[:split]
    if split < len(stereo):
        mix[:len(stereo) - split] += stereo[split:]


def finish(mix, path, loop):
    dry = mix.copy()
    for delay, gain in [(0.113, 0.12), (0.227, 0.09), (0.359, 0.065), (0.541, 0.035)]:
        offset = round(delay * RATE)
        if loop:
            mix += np.roll(dry[:, ::-1], offset, axis=0) * gain
        else:
            mix[offset:] += dry[:-offset, ::-1] * gain
    mix = np.tanh(mix * 1.1)
    mix *= 0.76 / max(float(np.max(np.abs(mix))), 0.001)
    if not loop:
        fade = round(0.5 * RATE)
        mix[-fade:] *= np.linspace(1, 0, fade)[:, None]
    assert np.isfinite(mix).all()
    pcm = np.rint(mix * 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    return {
        "seconds": len(mix) / RATE,
        "peak_dbfs": round(float(20 * np.log10(np.max(np.abs(mix)))), 2),
        "rms_dbfs": round(float(20 * np.log10(np.sqrt(np.mean(mix ** 2)))), 2),
        "loop_boundary_step": round(float(np.max(np.abs(mix[-1] - mix[0]))), 6),
    }


# Sixteen bars in D major: a warm plucked arpeggio under an airy flute melody.
chords = [
    (38, [62, 66, 69, 73]), (37, [61, 64, 69, 71]),
    (35, [59, 62, 66, 69]), (31, [55, 59, 62, 66]),
    (30, [57, 62, 66, 69]), (28, [55, 59, 62, 66]),
    (31, [55, 59, 62, 69]), (33, [57, 61, 64, 71]),
]
melody = [
    [(0, 74, .75), (.75, 78, .25), (1, 81, 1), (2.25, 78, .5), (3, 76, .75)],
    [(0, 73, 1), (1.5, 76, .5), (2, 81, .75), (3, 83, .5), (3.5, 81, .5)],
    [(0, 78, .5), (.5, 74, .5), (1, 73, 1), (2.25, 71, .75), (3.25, 74, .5)],
    [(0, 74, .75), (.75, 78, .25), (1, 79, 1), (2.5, 78, .5), (3.25, 74, .75)],
    [(0, 76, .5), (.5, 78, .5), (1, 81, 1.25), (2.5, 78, .5), (3.25, 76, .75)],
    [(0, 76, .75), (.75, 78, .25), (1, 79, .75), (2, 78, .5), (2.5, 76, .5), (3.25, 74, .75)],
    [(0, 74, .5), (.5, 71, .5), (1, 74, 1), (2.5, 76, .5), (3, 78, .5)],
    [(0, 76, 1), (1.5, 73, .5), (2, 71, .75), (3, 73, .5)],
    [(0, 81, 1), (1.25, 83, .5), (2, 81, .5), (2.75, 78, .75)],
    [(0, 81, .75), (1, 85, .5), (1.75, 83, .5), (2.5, 81, .5), (3.25, 76, .5)],
    [(0, 78, 1), (1.5, 81, .5), (2, 78, .5), (2.75, 74, 1)],
    [(0, 79, .75), (.75, 78, .25), (1, 74, 1), (2.25, 71, 1)],
    [(0, 78, .5), (.5, 81, .5), (1, 86, 1), (2.5, 81, .5), (3.25, 78, .5)],
    [(0, 79, 1), (1.25, 78, .5), (2, 76, .75), (3, 74, .5)],
    [(0, 74, .5), (.5, 78, .5), (1.25, 79, .75), (2.5, 78, .5), (3.25, 74, .5)],
    [(0, 73, 1), (1.5, 76, .5), (2.25, 71, .5), (3, 73, .5)],
]
music = np.zeros((round(64 * BEAT * RATE), 2), dtype=np.float64)
arp = [0, 2, 1, 3, 2, 1, 3, 2]
for bar in range(16):
    root, chord = chords[bar % 8]
    start = bar * 4 * BEAT
    for j, note in enumerate(chord):
        add(music, voice(note - 12, 4 * BEAT + 1, "pad"), start, .025, (j - 1.5) / 2.2)
    for beat in [0, 2]:
        add(music, voice(root, 1.8 * BEAT, "bass"), start + beat * BEAT, .11)
    for step, chord_index in enumerate(arp):
        note = chord[chord_index] + (12 if step == 6 and bar % 4 == 3 else 0)
        human = float(rng.uniform(-.006, .006))
        add(music, voice(note, 1.9, "harp"), start + step * .5 * BEAT + human, .071 if step % 2 == 0 else .052, -.45 if step % 2 == 0 else .45)
    for beat, note, length in melody[bar]:
        add(music, voice(note, length * BEAT, "flute"), start + beat * BEAT + .014, .115, .12)
    # Quiet wooden taps and brushed shakers support the jumps without masking SFX.
    for beat in [1, 3]:
        t = np.arange(round(.1 * RATE)) / RATE
        tap = np.sin(2 * np.pi * 720 * t) * np.exp(-t * 75)
        add(music, tap, start + beat * BEAT, .018, -.25)
    for step in range(8):
        t = np.arange(round(.065 * RATE)) / RATE
        noise = rng.standard_normal(len(t))
        brushed = np.convolve(noise, [0.25, 0.5, 0.25], mode="same") * np.exp(-t * 85)
        add(music, brushed, start + step * .5 * BEAT, .006 if step % 2 else .004, .6)

stats = {"skybound": finish(music, OUT / "skybound.wav", True)}
assert stats["skybound"]["loop_boundary_step"] < .01, "Loop boundary is not smooth"

victory = np.zeros((round(4 * RATE), 2), dtype=np.float64)
for i, note in enumerate([74, 78, 81, 86]):
    add(victory, voice(note, 2.0, "harp"), .12 + i * .24, .18, (i - 1.5) * .18)
for note in [62, 66, 69, 74]:
    add(victory, voice(note, 2.9, "pad"), .75, .055)
stats["victory"] = finish(victory, OUT / "victory.wav", False)
print(json.dumps(stats, indent=2))
