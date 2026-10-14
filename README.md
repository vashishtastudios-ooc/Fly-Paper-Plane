# Glide Home

A calm 3D paper-plane gliding game for Godot 4.4 (GDScript). A kid throws a folded notebook-paper plane from a balcony and you glide it across a golden-hour town to land softly on a target.

Everything is built at runtime from primitives, procedural meshes, generated textures and synthesized audio. The project imports no models, images or sounds.

## Open and run

1. Install **Godot 4.4** (standard build). Later 4.x versions also work.
2. In the Project Manager choose **Import**, pick `project.godot` in this folder, then **Import & Edit**.
3. Press **F5**. The main scene is `scenes/main.tscn`.

The first launch spends a second or two on "Folding the plane..." while it builds the town and textures. Music is synthesized on a worker thread and starts shortly after.

To try the touch controls on desktop, run with the user argument `--touch-ui`. In the editor, set this under *Project Settings > Editor > Run > Main Run Args*: `-- --touch-ui`. Mouse clicks then act as touches.

### Controls

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Turn | A / D or Left / Right | Left stick | Drag on the left 60% of the screen |
| Pull up / dive | W / S or Up / Down | Left stick | Drag up / down |
| Gust | Space | A | Gust button |
| Barrel roll | Q / E | LB / RB | Roll button |
| Throw | Enter or Space | A | "Throw the plane" |
| Pause | Esc | Start | Pause button (top right) |

## Export to Android

1. Open *Editor > Manage Export Templates* and download the templates for your Godot version.
2. Open *Editor Settings > Export > Android* and set the Java SDK path (JDK 17) and the Android SDK path. Godot creates a debug keystore automatically.
3. Open *Project > Export*, select the **Android** preset (already included in `export_presets.cfg`, arm64), change `package/unique_name` to your own id, then click **Export Project** (or use one-click deploy with a phone connected over USB).

Android-specific settings are already applied through feature tags:

- `rendering/renderer/rendering_method.mobile = "mobile"` selects the Mobile renderer. Desktop uses Forward+.
- The directional shadow atlas is 4096 on desktop and 2048 on mobile. MSAA is lighter on mobile, and the 3D render scale is 0.8.
- SSAO is on for desktop and off for mobile. SSR, SDFGI and volumetric fog are never used (see `Settings.configure_environment`).
- `window/handheld/orientation = sensor`, so the game supports both landscape and portrait. The UI stretch base switches between 1280x720 and 720x1280 to match.
- Touch UI respects the display safe area on notched phones. The Android back button pauses the game or returns to the menu.

## Tuning the flight

All flight constants are `@export` variables on **`scenes/plane/plane.gd`** (class `PaperPlane`). Select the `Plane` node in `scenes/plane/plane.tscn` or `scenes/main.tscn` to edit them in the inspector. The defaults match the specification exactly:

- **Pitch and roll:** stall below 4.6 m/s, stall pitch -0.45, trim -0.07, input gain 0.55, pitch range -0.75..0.5, pitch damping 2.6 (3.0 while stalled), roll 0.95 at rate 3.2, turn factor 1.2, input smoothing 10.
- **Speed and sink:** gravity 9.8, drag 0.0075, speed 2.5..21, base sink 0.25 plus 0.45 per m/s below 6, ground effect under 1.8 m, flap damping 2.2.
- **Gusts and tricks:** +3.4 flap and +1.8 speed per gust, 3 gusts refilling one per 9 s, +0.5 gust per star, 0.6 s barrel roll, launch at 10.5 m/s with pitch 0.05.

Other places to tune:

- Rising air for river sink lives in `scripts/level/level_runtime.gd` (`lift_at`). Each thermal's lift is in `scenes/gameplay/thermal.gd`.
- Camera framing, damping and FOV are exported on `scenes/camera/chase_camera.gd`.
- Scoring rules are in `autoload/game.gd` (`compute_landing_score`).

## Levels

Each level is a `LevelData` resource in `levels/level_1.tres`, `level_2.tres` and `level_3.tres`. You can edit them in the inspector. Each one holds:

- launch platform and aim point
- the route `Curve3D` (handles are smoothed at runtime)
- landing pad, radius, name and par time
- thermals, bonus stars, the bonus ring and hazard lines

At runtime the game places seven stars along the route, gold rings about every 14 m, and the dotted flight line. It also removes trees near the first route segments and the pad.

## Project layout

```
autoload/        Settings (platform, input map, safe area), Game (state, levels, scoring, save), Audio (synth)
scenes/main.*    Main flow: loading, menu, intro, throw, flight, result, pause
scenes/town/     town.tscn -> scripts/town/town_builder.gd (fixed seed 20261013)
props/           One scene per prop: house, shop, civic building, clock tower, bridge, fountain,
                 bandstand, jetty, picnic blanket, cafe table, car
scenes/plane/    Plane scene, flight model, procedural paper dart
scenes/kid/      The kid who throws the plane
scenes/gameplay/ Thermal, Star, Gate (ring), LandingPad, HazardLine (bunting / washing / rope)
scenes/ambient/  Birds, butterflies, ducks, pedestrians, cyclists, falling leaves and motes
scenes/ui/       HUD, TouchControls, Menu, LevelIntro, Result, Pause (notebook-paper theme)
scripts/core/    MeshBuilder, TexGen (generated textures), Mats, PropMeshes, Batcher (MultiMesh), Prop
scripts/level/   LevelData resource and LevelRuntime
shaders/         Water, thermal shimmer, pad light beam
levels/          level_1.tres ... level_3.tres
```

Saves go to `user://save.cfg`: best score and ribbons per level, plus unlocked levels. Volume settings go to `user://settings.cfg`.

## Swapping in real models

- **Prop scenes** (`props/*.tscn`, the kid, the plane's `Visual` node, stars): add a child named **`Model`** with your imported model. The procedural build is then skipped, and colliders are still created so gameplay keeps working.
- **Small repeated props** are drawn with MultiMesh: pickets, flowers, bushes, hedges, tree canopies and trunks, windows, shutters, flower boxes, lamps, mailboxes, benches, reeds, rocks, bunting flags. To replace one, save a scene at `res://props/overrides/<kind>.tscn` containing a `MeshInstance3D` (for example `canopy.tscn` or `lamp.tscn`). `PropMeshes` picks it up automatically. The kind names are listed in `scripts/core/prop_meshes.gd`.

## Fonts

The UI uses Caveat Brush (handwriting), Newsreader (serif body) and Barlow Condensed (UI numbers). These are SIL Open Font License fonts. Put the font files in `res://fonts/` with these names:

- `CaveatBrush-Regular.ttf`
- `Newsreader-Regular.ttf` or `Newsreader.ttf`
- `BarlowCondensed-SemiBold.ttf` or `BarlowCondensed-Medium.ttf`

Include each font's `OFL.txt` alongside it. If a file is missing, `scripts/ui/ui_kit.gd` falls back to similar system fonts, such as Segoe Print, Georgia and Arial Narrow, or casual, serif and sans-serif-condensed on Android.

## Landing and rising air

- **Touchdown rule:** the plane touches down only when it reaches the pad surface: within 0.3 m above the pad top and within the pad radius + 0.4 m. You can glide over the pad and settle near the center for a better accuracy score. The threshold is `TOUCHDOWN_HEIGHT` in `scripts/level/level_runtime.gd`.
- **Thermals:** each column shows a golden shimmer, bright rising sparkles and a swirl of leaves spiralling upward. Flying into one plays a soft whoosh and gently lifts the camera.

## Verified

- All scripts and scenes load without errors in a headless check.
- A test autopilot that steers along the dotted line and settles onto each pad lands all three levels with the flight constants unchanged:
  - Level 1: about 10 s, 0.5 m from the center
  - Level 2: about 7.3 s, including the +500 bridge ring
  - Level 3: about 32 s
