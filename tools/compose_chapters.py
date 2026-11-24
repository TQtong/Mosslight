"""Three original scores; synthesized offline without samples. Python 3 + NumPy."""
from pathlib import Path
import json
from music_synth import Score

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/music"

# Motifs are authored as (beat, MIDI pitch, length in beats). No external melodies.
WOODS = [
    [(0,74,1), (1.5,78,.5), (2.25,81,.75), (3.25,78,.5)],
    [(0,76,.75), (1,73,1), (2.5,69,.5), (3.25,73,.5)],
    [(0,74,.75), (1,78,.75), (2,76,.5), (3,71,.75)],
    [(.5,71,.5), (1.5,74,1), (3,78,.75)],
    [(0,76,1), (1.5,79,.5), (2.5,78,.5), (3.25,76,.5)],
    [(0,74,1.25), (2,71,.75), (3,69,.75)],
    [(.5,71,.5), (1.5,74,.5), (2.5,76,.75)],
    [(0,73,1), (1.5,76,.5), (2.5,73,.5), (3.25,69,.5)],
]
WOODS_B = [
    [(0,81,1.25), (1.75,83,.5), (2.5,81,.5), (3.25,78,.5)],
    [(0,78,.5), (.75,76,.75), (2,73,1.5)],
    [(0,78,.75), (1,81,1), (2.5,78,.5), (3.25,74,.5)],
    [(0,79,1), (1.5,78,.5), (2.5,74,1)],
    [(.5,79,.75), (1.5,83,.75), (2.5,81,.75)],
    [(0,81,.75), (1,78,.5), (2,74,1.5)],
    [(0,76,.5), (1,78,.5), (2,79,.75), (3,76,.75)],
    [(0,76,1), (1.5,73,.75), (2.75,69,1)],
]


def woods():
    s = Score(96, 32, 4, 340701)
    harmony = [(38,[62,66,69,73]),(37,[61,64,69,71]),(35,[59,62,66,69]),(31,[55,59,62,66]),
               (28,[55,59,64,67]),(30,[57,62,66,69]),(31,[55,59,62,69]),(33,[57,61,64,71])]
    arp = [0,2,1,3,2,1,3,2]
    for bar in range(32):
        root, chord = harmony[bar % 8]
        section = bar // 8
        s.chord(bar, [n - 12 for n in chord], .022)
        for beat in [0,2]: s.note(bar, beat, root, 2, "bass", .09)
        for step, index in enumerate(arp):
            gain = .056 if step % 2 == 0 else .04
            if section == 3: gain *= .85
            s.note(bar, step * .5, chord[index], 2.8, "pluck", gain, -.5 if step % 2 == 0 else .5)
        phrase = (WOODS_B if section in [1,2] else WOODS)[bar % 8]
        for beat, note, length in phrase:
            s.note(bar, beat + .03, note, length, "reed", .095 if section != 3 else .075, .1)
        if section == 2 and bar % 2 == 0:
            s.note(bar, 3, chord[1] + 12, 1.8, "glass", .035, -.4)
        if section != 3:
            for step in range(8): s.brush(bar, step * .5, .004 if step % 2 == 0 else .005, .6)
    return s.write(OUT / "moss_and_fireflies.wav")


def ruins():
    s = Score(90, 48, 3, 340702)
    harmony = [(35,[59,62,66,69]),(31,[55,59,62,66]),(38,[57,62,66,69]),(33,[57,61,64,69]),
               (35,[59,62,66,73]),(28,[55,59,64,67]),(31,[55,59,62,69]),(33,[57,61,64,71])]
    phrases = [
        [(0,71,1.5),(2,74,.75)], [(0,78,.75),(1,74,.75),(2,71,.75)],
        [(.5,69,1),(2,74,.75)], [(0,73,1),(1.5,76,1)],
        [(0,78,1),(1.5,74,1)], [(0,76,.75),(1,71,.75),(2,67,.75)],
        [(.5,71,.75),(1.5,74,.75)], [(0,73,1),(1.5,69,1)],
    ]
    for bar in range(48):
        root, chord = harmony[bar % 8]
        section = bar // 16
        s.chord(bar, [n - 12 for n in chord], .026)
        s.note(bar, 0, root, 2.9, "bass", .095)
        for step, index in enumerate([0,2,1,3,2,1]):
            s.note(bar, step * .5, chord[index], 3.2, "glass", .048 if step % 2 == 0 else .032, -.45 + (step % 3) * .45)
        # A sparse opening, a warmer bowed middle, and a glass response on return.
        if not (section == 0 and bar % 4 == 3):
            for beat, note, length in phrases[bar % 8]:
                s.note(bar, beat + .04, note - (12 if section == 1 else 0), length + (.25 if section == 1 else 0), "bowed" if section == 1 else "reed", .085, -.12)
        if section == 2 and bar % 2 == 1:
            s.note(bar, 2, chord[2] + 12, 2.1, "glass", .026, .45)
        for beat in [.75,1.75,2.75]: s.brush(bar, beat, .0035, -.55)
    return s.write(OUT / "steps_of_amber.wav")


def stars():
    s = Score(104, 32, 4, 340703)
    harmony = [(38,[62,66,69,73]),(40,[64,68,71,76]),(35,[59,62,66,73]),(30,[57,61,66,69]),
               (31,[55,59,62,69]),(33,[57,62,66,69]),(28,[55,59,64,67]),(33,[57,61,64,71])]
    phrases = [
        [(0,78,1),(1.5,81,.5),(2.5,85,1)], [(0,83,1),(1.5,80,.5),(2.5,76,1)],
        [(0,81,.75),(1,78,.75),(2.5,74,1)], [(0,78,1.5),(2,73,1.5)],
        [(0,79,.75),(1,83,.75),(2.5,86,1)], [(0,85,1),(1.5,81,.75),(2.75,78,1)],
        [(0,79,1),(1.5,76,.5),(2.5,74,1)], [(0,76,1),(1.5,73,.5),(2.5,69,1)],
    ]
    for bar in range(32):
        root, chord = harmony[bar % 8]
        section = bar // 8
        s.chord(bar, [n - 12 for n in chord], .03)
        for beat in [0,2.5]: s.note(bar, beat, root, 2.5, "bass", .09)
        for step, index in enumerate([0,1,2,3,2,1,3,2]):
            octave = 12 if section == 2 and step in [3,6] else 0
            s.note(bar, step * .5, chord[index] + octave, 3, "pluck", .047 if step % 2 == 0 else .033, -.55 if step % 2 == 0 else .55)
        for beat, note, length in phrases[bar % 8]:
            s.note(bar, beat + .03, note, length + .1, "bowed" if section in [1,2] else "reed", .09, .08)
        if section != 3:
            s.note(bar, 3.5, chord[1] + 12, 2, "glass", .035, -.4)
            for step in range(8): s.brush(bar, step * .5, .004, .6)
    return s.write(OUT / "a_path_through_stars.wav")


if __name__ == "__main__":
    report = {"moss_and_fireflies":woods(), "steps_of_amber":ruins(), "a_path_through_stars":stars()}
    for key, stats in report.items():
        assert stats["loop_boundary_step"] < .01, key
        assert stats["quietest_second_dbfs"] > -34, key
    (OUT / "chapter-score-analysis.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report,indent=2))
