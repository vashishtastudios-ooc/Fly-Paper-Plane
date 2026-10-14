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

## Publish to Google Play

The game is set up as a free release with no ads and no data collection. Store text, Play Console answers and step-by-step release instructions are in **[store/STORE_LISTING.md](store/STORE_LISTING.md)**. The privacy policy is **[PRIVACY.md](PRIVACY.md)**: fill in your support email and host it publicly.

Short version:

1. Open *Editor > Manage Export Templates* and download the templates for your Godot version.
2. Open *Editor Settings > Export > Android* and set the JDK 17 path and the Android SDK path.
3. Choose *Project > Install Android Build Template*. The preset builds an **AAB** with Gradle.
4. Create an upload keystore and enter it under *Project > Export > Android > Keystore > Release*.
5. Export `export/GlideHome.aab` and upload it to an Internal testing track first.

What the **Android** preset in `export_presets.cfg` already sets:

- AAB through Gradle, arm64, min SDK 24, target SDK 35
- package id `com.vashishtastudios.glidehome` (change it before your first upload if you want a different id)
- launcher and adaptive icons from `icons/`
- the VIBRATE permission only

Store graphics are in `store/`, generated from the game:

- `feature_graphic.png` (1024×500)
- `screenshots/phone_*.png` (1080×1920)
- `screenshots/landscape_*.png` (1920×1080)

The `store/` folder has a `.gdignore` file, so Godot never imports or exports it.

Platform settings applied through feature tags:

- `rendering/renderer/rendering_method.mobile = "mobile"` selects the Mobile renderer. Desktop uses Forward+.
- The shadow atlas is 2048 on mobile and 4096 on desktop. SSAO is used only on desktop at High quality. SSR, SDFGI and volumetric fog are never used.
- `window/handheld/orientation = sensor`, so the game supports both portrait and landscape. The UI stretch base switches between 1280×720 and 720×1280 to match.
- Touch UI respects the safe area on notched phones. The back button pauses the game or returns to the menu, and switching apps pauses the flight.

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

| # | Flight | Start | Landing target |
|---|---|---|---|
| 1 | Window to the Picnic | Upstairs balcony on Linden Lane | Picnic blanket in the park |
| 2 | Under the Old Bridge | Corner balcony by the river | Fishing jetty |
| 3 | Up to the Clock Tower | Bakery roof on Market Street | Clock tower balcony |
| 4 | Classroom Window Escape | A desk in the upstairs classroom of Linden Primary | A friend's backpack at the bus stop on Linden Lane |
| 5 | Lantern Night | The clock tower balcony, at dusk | The lantern festival on the old bridge |
| 6 | Open House Day | An attic bedroom on Rowan Row | The cat's rug by the cottage fireplace |

**Classroom Window Escape:** warm air rises off the radiator, and the spinning ceiling fan or a closed window crashes the plane. After the window you cross the schoolyard and glide about 130 m down Linden Lane, under bunting and through two pockets of rising air, to the bus stop. Rings inside the classroom are smaller (`small_gate_box`).

**Lantern Night:** the same town at dusk. The sky deepens, the sun sits low and every window and street lamp glows. You glide about 300 m down Market Street.
- Rings are hoops of paper lanterns (`gate_style = "lantern"`).
- Rising air comes from the lanterns and carries glowing sky lanterns upward (thermal style `lantern`).
- Lantern strings across the street are hazards.
- The festival decor (`decor = "lantern_festival"`) adds floating river lanterns and lantern posts along the bridge.
- `time_of_day = "dusk"` switches the lighting through `TownBuilder.set_time_of_day()`.

**Open House Day:** a flight through the houses of Rowan Row, a garden street behind the east side of Market Street (`TownBuilder._rowan_row()`). It takes about 7 s along the line.
- Out the attic's gable window, in through the bedroom's open window, through the doorway into the study and out the back.
- Over the washing line, along the stairwell house's landing, over the banister and down the stairwell, out through the french doors.
- Through the greenhouse, in at the cottage's back door, through the kitchen archway onto the round rug.
- Open windows and inner doorways are bare frames (no swung leaves). Bonus rings in every level are pink, so they never look like the main gold route rings.
- Closed windows, greenhouse glass, hanging lamps, furniture and the banister crash the plane. Warm air rises off the bedroom radiator, the patio and the greenhouse.
- The secret line: line up left from the attic, go through the bedroom's left window and the small hatch beside the door (the pink bonus ring, +300), then out the study's left window and in at the stairwell house's left window.
- Houses are `props/open_house.tscn` with `layout` set to `attic`, `bedroom`, `stairwell`, `greenhouse` or `cottage`.

Each level is a `LevelData` resource in `levels/level_N.tres`. You can edit them in the inspector. Each one holds:

- launch platform and aim point
- the route `Curve3D` (handles are smoothed at runtime)
- landing pad, radius, name and par time
- thermals, bonus stars, the bonus ring and hazard lines
- `gate_radius`, the ring size (smaller indoors)

A thermal can also set `base` (start height, for example a classroom floor) and `ceiling` (where the visual column stops).

To add a level, create `levels/level_7.tres` and add its path to `LEVEL_PATHS` in `autoload/game.gd`.

## Look and atmosphere

- **Storybook pass** (`shaders/storybook_post.gdshader`, attached to the chase camera):
  - a soft warm ink outline found from depth edges, fading with distance
  - a gentle vignette and faint paper grain
- **Color grading:** a warm split-tone 3D LUT built in `TownBuilder._storybook_lut()` and used as the environment's color correction.
- **Wind** (`shaders/foliage.gdshader`, `shaders/cloth_wind.gdshader`):
  - trees, bushes and flowers sway and rustle
  - about 9,000 grass tufts bend from the base (about 3,200 on phones)
  - bunting, washing and the school flag flutter
- **Light:**
  - soft slanted sunbeams through gaps in the trees (`shaders/sunbeam.gdshader`)
  - a sun glow on the horizon
  - warmer haze toward the sun
- **Water** (`shaders/water.gdshader`):
  - a reflection probe over the river captures the bridge, banks and houses, and re-captures at dusk
  - desktop High adds screen-space reflections
  - twinkling glints appear only where light reaches, so they respect shadows and also shine under the festival lights
- **Quality levels:**
  - Low turns off the outline, sunbeams and grass
  - Medium and High enable everything
  - SSR runs only on desktop High

## Sliding landings

A gentle belly touch on a flat surface makes the plane slide instead of crumple. This covers the ground, floors, balconies, flat roofs and the bridge deck: anything flatter than about 32°, met at under 25° (`slide_max_angle`), as long as the plane isn't diving nose-first.

- **Slide length:** about the touchdown speed divided by 2 m/s (`slide_friction`). Touching down at 9 m/s slides about 4 m.
- **Onto the target:** it's a landing. Once on the target it settles faster (`pad_friction`).
- **Scoring:** accuracy is measured where the plane comes to rest. Softness uses the first touch, so landing short and sliding to the center scores the same as landing there directly.
- **Into something:** a normal crash.
- **Off an edge:** the plane is flying again.
- **Stops before the target:** "Touched down short", without the crumple.
- **Steep or nose-first hits** still crash.

## Water: skip, skim, splash

How the river reacts to a touch (all tunable in the Water group on `Plane.gd`):

- **Skip:** a fast, flat touch (over 8 m/s and under 15°) bounces the plane back up like a stone. It keeps 70% of its speed, gets a small upward pop and a spray, and "Skip!" shows. Another skip is possible once the plane climbs about 1 m clear of the water.
- **Skim:** a slower gentle touch, or a second dip without climbing away, skims on the belly with a small wake. Water is grabby (`skim_friction`), so this lasts about 1–1.5 m. Skimming onto the bank becomes a normal slide. Otherwise the plane stops "Soaked!" and settles into the water, without the crumple or shake.
- **Splash:** a steep or nose-first touch is a crash, "Splash! Into the river".

## Collisions (what counts as a hit)

The rule: you only crash when the plane visibly touches something.

- **Plane:** a 0.2 m ball at its center (`collision_radius` in `plane.gd`), swept along its path every tick so it can't skip through thin walls.
- **Strings** (bunting, washing, lanterns, rope lines) are only what you see:
  - **The thin rope:** about 9 cm below the plane's center up to 6 cm above it counts as touching. Passing 10 cm above the rope is safe.
  - **Hanging items:** each pennant, shirt, sheet and lantern by its own shape. Flying into a flag tangles you, and the gaps between flags are really gaps.
- **Buildings and props:** every collision shape is the same size as what's drawn or slightly smaller, never bigger. This covers:
  - roof slabs with their eaves
  - porch posts and roofs, with the open space under them flyable
  - awnings as thin canvas
  - lamps as a pole and head
  - swings and the climbing frame as bars
  - the bus shelter with an open front
  - pendant lamps and the chandelier by their actual shapes
- **On a crash,** a bright burst appears at the exact point of contact.
- **Collision view:** press **F3** (or Settings > Testing in test builds) to draw every collision shape:
  - orange: walls and props
  - green: landing pads
  - red: strings and their hanging items
  - white: the plane's ball

  This helps when checking a new map.

## Hangar (plane customization)

The Hangar lets players change the plane's paper, wingtip trail and wing sticker. These are looks only, so flight behavior and level balance never change. Items unlock from the total number of ribbons earned across all flights (up to 18):

- **Papers:** Notebook (free), Graph paper (2), Red origami (4), Newspaper (6), Old map (8), Sky blue card (10), Polka dot (12)
- **Trails:** Classic white (free), Rainbow ribbon (3), Gold sparkles (5), Confetti (7), Comet glow (9)
- **Stickers:** Gold star (free), Heart (1), Smiley (2), Lightning (6), Lucky 7 (11)

The catalog and unlock thresholds are in `scripts/cosmetics/cosmetics.gd`. Paper and sticker textures are generated in `scripts/core/tex_gen.gd`. The result screen announces new unlocks.

## Settings, tips and accessibility

- **Settings** (from the menu or pause screen), with a **Reset to defaults** button:
  - Music, Effects and Wind/birds volume
  - graphics quality (Low, Medium, High)
  - steering sensitivity
  - invert climb and dive
  - vibration (phones)
  - flight tips
- **Flight tips:** one-time hints on the first flights:
  - steering
  - climbing costs speed
  - rising air
  - gusts
  - how to land

  Turning tips back on in Settings shows them again. A "Too slow!" warning appears before every stall.
- **Credits:** includes the Godot Engine license notice that publishing requires.

At runtime the game places seven stars along the route, gold rings about every 14 m, and the dotted flight line. It also removes trees near the first route segments and the pad.

## Project layout

```
autoload/        Settings (platform, input map, safe area), Game (state, levels, scoring, save), Audio (synth)
scenes/main.*    Main flow: loading, menu, intro, throw, flight, result, pause
scenes/town/     town.tscn -> scripts/town/town_builder.gd (fixed seed 20261013)
props/           One scene per prop: house, shop, civic building, clock tower, bridge, fountain,
                 bandstand, jetty, picnic blanket, cafe table, car, school, backpack mat,
                 open house (walk-through houses of Rowan Row)
scenes/plane/    Plane scene, flight model, procedural paper dart
scenes/kid/      The kid who throws the plane
scenes/gameplay/ Thermal, Star, Gate (ring), LandingPad, HazardLine (bunting / washing / rope)
scenes/ambient/  Birds, butterflies, ducks, pedestrians, cyclists, falling leaves and motes
scenes/ui/       HUD, TouchControls, Menu, LevelIntro, Result, Pause, Hangar, SettingsMenu, Credits
scripts/core/    MeshBuilder, TexGen (generated textures), Mats, PropMeshes, Batcher (MultiMesh), Prop
scripts/level/   LevelData resource and LevelRuntime
scripts/cosmetics/ Paper, trail and sticker catalog
icons/           App icons (SVG sources plus Android PNGs)
store/           Play Store listing text and generated store graphics (ignored by Godot)
shaders/         Water, thermal shimmer, pad light beam
levels/          level_1.tres ... level_3.tres
```

Saves go to `user://save.cfg`: best score and ribbons per level, unlocked levels, Hangar choices and seen tips. Settings go to `user://settings.cfg`.

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
  - Level 4: about 15 s, from the classroom to the bus stop
  - Level 5: about 32 s, from the clock tower to the bridge
- Screenshots were checked in landscape and portrait, for every flight and for the Hangar, Settings and Credits screens.
