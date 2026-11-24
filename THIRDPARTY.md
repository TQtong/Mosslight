# Third-party fonts

These fonts are bundled for offline Latin, Cyrillic, Chinese, Japanese and Korean
text coverage. They retain their own SIL Open Font License 1.1, independent of
the project's MIT license.

| File | Official source | License included |
| --- | --- | --- |
| `assets/fonts/NotoSansCJKsc-Regular.otf` | <https://github.com/notofonts/noto-cjk/tree/main/Sans/OTF/SimplifiedChinese> | `assets/fonts/NotoCJK-LICENSE.txt` |
| `assets/fonts/NotoSansCJKtc-Regular.otf` | <https://github.com/notofonts/noto-cjk/tree/main/Sans/OTF/TraditionalChinese> | `assets/fonts/NotoCJK-LICENSE.txt` |
| `assets/fonts/NotoSansCJKjp-Regular.otf` | <https://github.com/notofonts/noto-cjk/tree/main/Sans/OTF/Japanese> | `assets/fonts/NotoCJK-LICENSE.txt` |
| `assets/fonts/NotoSansCJKkr-Regular.otf` | <https://github.com/notofonts/noto-cjk/tree/main/Sans/OTF/Korean> | `assets/fonts/NotoCJK-LICENSE.txt` |
| `assets/fonts/NotoSerif-Variable.ttf` | <https://github.com/google/fonts/tree/main/ofl/notoserif> | `assets/fonts/NotoSerif-OFL.txt` |

The original fonts are unmodified. Traditional Chinese, Japanese and Korean use
the TC, JP and KR regional variants respectively, including their regional Han
forms. Simplified Chinese and the other UI locales use SC for body text, with
Noto Serif for supported non-CJK title text. Fonts are bundled for offline play
and loaded when their locale is selected. Pinned upstream revisions, URLs, sizes
and SHA256 hashes for the added variants are in
`assets/fonts/regional-font-sources.json`.

Godot itself is distributed separately under its own MIT license:
<https://godotengine.org/license/>.
