Mosslight original soundtrack / 苔光旅人原创配乐
Producer / 制作人: TQ

skybound.wav — Skybound / 云上微光: title theme, D major, 96 BPM, 40 s.
moss_and_fireflies.wav — Moss and Fireflies / 苔林与萤火: Chapter I, D major,
96 BPM, 32 bars in 4/4, 80 s. Plucked arpeggios, flute, warm pads.
steps_of_amber.wav — Steps of Amber / 琥珀石阶: Chapter II, B minor,
90 BPM, 48 bars in 3/4, 96 s. Glass mallets and a bowed middle section.
a_path_through_stars.wav — A Path Through Stars / 星间归途: Chapter III,
D with a Lydian colour, 104 BPM, 32 bars in 4/4, about 73.846 s.
Wide strings, rising arpeggios and restrained chimes.
victory.wav — Four-second completion coda.

All are original compositions synthesized for this project without external
samples or recordings. Stereo, 44.1 kHz, 16-bit PCM. Project MIT license applies.
Instrument and room tails wrap around loop boundaries. No streamed audio.

The title has its own theme. Story cards and gameplay use their chapter's score.
Same-chapter restarts preserve playback. A 1.25-second equal-power crossfade
connects different scores, and paused gameplay lowers the existing mix.
Volume and mute apply to every score through the shared Music bus.

Rebuild the menu/coda: Python tools/compose_music.py
Rebuild the three chapters: Python tools/compose_chapters.py
Independent PCM checks: Python tools/verify_scores.py
Only authoring needs Python and NumPy; playing/exporting needs neither.
Playback and state-dependent mixing are in scripts/audio.gd.
