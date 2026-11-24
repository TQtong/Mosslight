# Mosslight / 苔光旅人

Mosslight is a 2D sky-island platformer by TQ. Carry a fading ember across twelve stages, collect lightseeds, and rekindle the beacon.

## Run from source

1. Open `project.godot` with the standard GDScript build of Godot 4.7.2.
2. Let Godot import the bundled assets, then press F5. The project uses the Compatibility renderer.
3. To export Windows x64, install matching Godot export templates and use the **Windows Desktop** preset. Create `builds/windows-alpha/` first, or choose another output directory.

The game runs offline. Its exported Windows executable and `.pck` belong in the same directory.

## Controls

| Action | Default keyboard |
| --- | --- |
| Move | A / D or Left / Right |
| Jump | Space / W / Up |
| Air dash (Chapter III) | Shift / X |
| Retry checkpoint | R |
| Pause | Esc |

Chapter II adds a midair jump. Chapter III adds an air dash to cross wider gaps. The journey map revisits unlocked stages, and collecting all 36 lightseeds unlocks an epilogue.

## Verification

After importing the project, replace `godot` below with your Godot executable if needed. The route test traverses all twelve stages using game inputs and collects every lightseed.

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/route_test.gd -- --collect
```

The score authoring scripts are in `tools/`. The bundled WAVs are ready to play. Rebuilding them requires Python and NumPy.

## AI use

Generative AI assisted with code, in-game vector art implementation, story text, translations, and the writing of the procedural score. The score was rendered offline with local synthesis scripts. The promotional illustration for the itch.io cover was AI-generated using a Mosslight gameplay capture as reference. Gameplay screenshots are captured from the game. The game runs offline without generative AI services.

## Licenses

Project source is available under the [MIT License](LICENSE). Bundled fonts are distributed under SIL OFL 1.1. See [third-party notices](THIRDPARTY.md) and the included Godot license.

## 简体中文

用 Godot 4.7.2 的标准 GDScript 版打开 `project.godot`，等待资源导入后按 F5。第三章解锁空中冲刺，默认 Shift 或 X。按 Esc 暂停，按 R 返回检查点。
