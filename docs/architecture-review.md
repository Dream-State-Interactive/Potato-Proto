# Architecture & Organization Review

**Date:** 2026-08-04 · **Branch:** `feat_Theme_k` @ `5f542a2` · **Reviewer:** Claude (read-only pass)

Scope: every `.gd` in `src/`, `tools/`, `addons/` (183 + 7 files, ~14.6k LOC), all 71 scenes,
all 140 `.tres`, `project.godot`, CI, and the git log. No files were modified.

---

## 1. Executive summary

The engineering here is genuinely better than "prototype." There's a real component
system, a real event bus, a real data-driven content pipeline, a real save system, and
some clever stuff (the speed-blended collision shapes, the shader-based peel/aging, the
seeded deterministic segment recipes, the code-drawn biome art). Individual systems are
documented in-file better than most hobby projects.

The problem isn't quality of parts. It's that **the repo contains three or four
generations of the same game, all still wired up and all still loadable**, and nothing
records which one won. That's what makes it feel like a mess, and it's also — I'd argue —
the actual cause of the design stall. You can't decide what the game *is* while the
codebase is still offering four answers.

Three structural facts drive most of my findings:

1. **The shipping level lives in `tools/`.** "Play" loads
   `tools/LevelGen/scenes/level_gen.tscn`. `src/` contains the *older* generator. Anyone
   (including future-you, including me) reading this repo top-down will study the wrong
   system first. I lost a good while doing exactly that.
2. **Two complete, non-overlapping level generators coexist**, plus a third
   (`zoo_theme_generator`) and a fourth vestige (`theme_manager_olde.gd`). They have
   separate theming models, separate hazard placement, separate art strategies, separate
   sky systems. ~2,400 LOC of the ~14.6k is the losing branch.
3. **`GameManager` is half proxy shim.** ~100 of its 285 lines are `@deprecated`
   forwarders to `RunState`/`SignalBus`, and *most call sites still use the forwarders*.
   The refactor was started (commit `2f60c98` "Broke up game manager") and never finished,
   so there are now two spellings for every piece of run state.

None of this is hard to fix. Most of it is deletion and a rename, not redesign.

---

## 2. What's actually good (keep these)

| Thing | Why it's worth protecting |
|---|---|
| `SignalBus` + `RunState` split | Correct shape. Pure relay, no state; state object, no flow. Finish the migration to it. |
| `c_*` component pattern | `CHealth`, `CGrip`, `CHazard`, `CLauncher`, `CArmor`, `CGuiScale` are genuinely reusable and mostly decoupled. `CGrip`'s delegation contract (returns `true` = "I took the frame") is a clean idea. |
| Resource-driven content | `BiomeProfile`/`LayerProfile`/`ProcAsset`, `HazardConfig`, `StatBlock`, `WorldTheme`, `UpgradeData`. Designers can build content without code. This is the project's biggest asset. |
| `ProcAssetInstance` | Lets you preview a single `ProcAsset` in the editor on a fake flat terrain. Small, high-leverage tooling. |
| Code-drawn biome art | ~2.9k LOC of `Polygon2D`/`Line2D` drawing across 7 biomes. Zero art dependencies, infinitely re-colourable, tiny on disk. Unusual and it works. |
| Deterministic segment recipes (`level_generator._get_or_decide_segment_recipe`) | Recursive seeded lookup so backtracking reproduces the same level. Correct solution to a real problem. This idea is worth porting to `LevelGen`, which currently uses a mutable `_chunk_meta` registry instead. |
| `SceneLoader` threaded load + transition | Background load gated on "transition is opaque" is the right pattern. |
| `SurfaceDefinition` / `SurfaceTagger` / `SurfaceManager` | Clean metadata-based surface→audio/physics mapping. Newest system in the repo and the best-designed one. |
| Settings migration system | `settingsService._migrate` with schema versioning and atomic-ish save is more care than this project needed. |
| In-file documentation | The header comments in `player.gd`, `c_grip.gd`, `c_hazard.gd`, `fracturable2D.gd` are teaching-quality. Don't strip them. |

---

## 3. Folder hierarchy

### 3.1 The `tools/` vs `src/` inversion

```
tools/
├── LevelGen/          ← THE GAME (generator core, 7 biomes, 105 .tres, the live level scene)
├── PathMaker/         ← editor tool
├── ShapeMaker/        ← editor tool (+ 4 stray .tmp files)
├── collisionmaker/    ← editor tool
├── Trigger/           ← unused editor tool
├── ParallaxBackground/← main-menu background scripts (used) + Door/ (unused)
├── terrain/           ← duplicate of tools/terrain.tscn
├── terrain.gd/.tscn   ← the other duplicate
└── env_water.gd/.tscn ← unused wrapper around src/env/water
```

`tools/` is doing three unrelated jobs: shipping content, editor plugins, and a scratch
drawer. Recommended split:

- `tools/LevelGen/core` + `biomes` + `assets` + `scenes` → **`src/levelgen/`** (or
  `src/world/`). It is not a tool; it is the game.
- `PathMaker`, `ShapeMaker`, `collisionmaker` → keep under `tools/`, they're real
  editor-time utilities. Consider promoting to `addons/` since they're `@tool` scripts.
- `Trigger/`, `terrain*`, `env_water*`, `ParallaxBackground/Door/` → delete or move to
  an explicitly-labelled `scratch/` that's excluded from export.
- `ParallaxBackground/*.gd` (the ones `MainMenu.tscn` uses) → `src/ui/menus/` or
  `src/env/parallax/`. Four scripts of ~10 lines each; `fullscreen_control.gd`,
  `skyscale.gd`, `groundscale.gd`, `ParallaxScroll.gd` are all one-liners that could
  collapse into one.

This single move is the highest-value organizational change available. It costs a day of
path fixing and permanently removes the "which system is real?" question.

### 3.2 `src/` layout

Mostly sound. `src/core`, `src/player`, `src/components`, `src/ui`, `src/abilities`,
`src/hazards`, `src/env`, `src/collectibles` are all defensible. Specific issues:

- **`src/modes/gauntlet/` is a misnomer.** There is no gauntlet mode; nothing selects
  modes; the folder is "the legacy generator plus five things the live game still needs"
  (`store.tscn`, `ability_store.tscn`, `store_interaction.gd`, `progression_manager.gd`,
  `breakable_joint_2d.gd`). Those five should move out to `src/interactables/`,
  `src/core/`, and `src/env/` respectively; the rest is deletable once you commit to
  `LevelGen`.
- **`src/themes/` and `tools/LevelGen/biomes/` are competing answers to the same
  question.** `ThemeData` (23 exported visual params, sky shader, celestials, day/night,
  palette grading, 5-layer parallax A/B crossfade) vs `BiomeProfile` (sky gradient, glow,
  fog flags, layer list). `ThemeData` is far richer and is only used by the *legacy*
  path. That's the single biggest piece of value stranded on the losing branch — see §6.
- **`src/levels/zoo/`** contains `cheat_room.tscn`, which is the **starting segment of
  the live game**. A dev cheat room is the first thing a player sees. It also contains
  `zoo_themes.tscn`/`theme_segment.gd`/`zoo_theme_generator.gd`, a third generator used
  only as a theme previewer. Split: cheat room → `src/levels/dev/`, zoo → `tools/`.
- **`src/utility/` holds exactly one file** (`batch_spawner.gd`). Fold into
  `src/core/` or `src/components/`.
- **`src/npc/npc_goobie/`** is a folder-per-NPC for one 8-line NPC. Fine for now, but
  it's the kind of premature structure that accumulates.

### 3.3 `assets/`

```
assets/
├── graphics/          ← organized: proto/ sprites/ textures/ ui/
├── Images/            ← unorganized, PascalCase, 13 files, overlaps graphics/
├── Music/  sfx/       ← inconsistent case
├── Shaders/           ← 5 shaders … while 7 more live in src/themes/shaders/
├── fonts/  themes/
└── blendergodotpipelinetest.{obj,mtl}, blenderpipeline_test0.glb   ← 3D test files in a 2D game
```

- `assets/Images/` and `assets/graphics/` hold near-duplicates (`potato.png` in both,
  `bustin.png` in both, `goobie.png` vs `goobie/goob_*.png`). Pick `graphics/`, migrate,
  delete `Images/`.
- Shaders are split across `assets/Shaders/` (player peel/aging/scroll) and
  `src/themes/shaders/` (sky/celestial/fog/grade/terrain). Defensible if you frame it as
  "generic vs theme-system", but as-is it just looks arbitrary. I'd put all of them in
  `assets/shaders/` or all of them next to their owning system — not half-and-half.
- `assets/Images/TitleText.png` is 1.8 MB; `proto_bg_hills_02.png` is 2.8 MB. Both are
  larger than they need to be for 1920×1080.
- The two `.mp3` music tracks are 12.5 MB of the repo. Fine for now; if the repo grows,
  Git LFS is the answer.

### 3.4 Repo hygiene

Tracked files that shouldn't be (full list in `docs/tech-debt.md`):
7 `.tmp` Godot editor temp-saves, 4 Audacity `.asd` files (two of which have no
corresponding `.mp3`), the Blender pipeline test files, and **~30 MB of
`addons/godot-git-plugin/` prebuilt binaries** (`.so`, `.dylib`, `.dll`). That plugin
is a per-developer editor convenience; it does not belong in project source.

`.gitignore` already lists `*.tmp` — the files predate it and were never untracked.

---

## 4. Logical architecture

### 4.1 Data / control flow, as built

```
                          ┌──────────────┐
              emit        │  SignalBus   │        connect
   ┌──────────────────────┤  (relay)     ├────────────────────┐
   │                      └──────────────┘                    │
   │                             ▲                            ▼
┌──┴──────┐  register    ┌───────┴────────┐            ┌────────────┐
│ Player  ├─────────────▶│  GameManager   │            │ GUI  → HUD │
│(RigidB) │              │  flow + shim   │            │ level-up   │
└──┬──────┘              └───────┬────────┘            │ ability    │
   │ group "player"              │ delegates           └────────────┘
   │                             ▼
   │                      ┌────────────┐   ┌────────────┐  ┌──────────────┐
   │                      │  RunState  │   │SaveManager │  │ SceneLoader  │
   │                      └────────────┘   └────────────┘  └──────┬───────┘
   │                                                              │
   └──────────── polled every frame by ───────────────────────────┘
                 level_maker_modular._process()  (player.global_position.x)
```

The spine is fine. Four things bend it out of shape:

**(a) `GameManager` is both the shim and the thing being shimmed.** `_ready()` connects
nine `SignalBus` signals to nine identical local signals purely so old code keeps
working. `hud.gd` connects to *all six* of its UI signals through `GameManager`, not
`SignalBus`. So every starch pickup does: `RunState` setter → `SignalBus.starch_changed`
→ lambda → `GameManager.starch_changed` → HUD. Two extra hops and two places to look
when it breaks. `RunState`/`SignalBus` were the right refactor; it just needs finishing
(mechanical: 30-ish call sites).

**(b) `GameManager.player_instance` is a group lookup dressed as a property.** It does
`get_tree().get_first_node_in_group("player")` on *every* access. `player.gd` calls it
**eight times**, including four times inside `_physics_process`/`dash` — to fetch
`GameManager.player_instance.mass`, i.e. its own `mass`. `level_maker_modular` touches it
6×/frame, `hud.gd` 6×/frame. This is both a perf smell and a readability trap: in
`player.gd` it reads as "some other object."

**(c) `ThemeManager` is an autoload that renders an *unmanaged* full-screen visual stack in
every scene.** It adds `visual_stack.tscn` (CanvasLayer at `layer = -100`, sky shader,
celestials, glow, starfield, fog, post-grade, 5 parallax layers × 2 sprites) as its own
child on boot, unconditionally. In `level_gen.tscn` nothing ever calls `apply_theme()`, so
`current_theme` stays null and `_apply_frame()` early-returns — **but `_ready()` sets the
Control visible anyway.** So the stack draws with whatever was baked into the `.tscn`, and
none of the corrective logic in `_apply_frame`/`_update_overlays`/`_update_stars` ever runs.

> **Corrected 2026-08-04.** My first pass said this stack "sits inert." That was wrong.
> It is rendering: a hardcoded daytime blue sky, a sun at a fixed `time_of_day = 0.25`, 300
> always-emitting particles, and a colour-grade overlay stuck at `amount = 0.4` with a null
> palette — which darkens its own layer by 40 %. Full breakdown in
> `docs/tech-debt.md` **A12**, and the resulting two-competing-skies question in **A13**.
> Thanks to Alex for pushing back on the "everything renders as night" claim; chasing it
> is what surfaced this.

That makes it worse than dead weight: there are now two independent sky systems at the same
`layer = -100` (this one and the one `level_maker_modular._setup_sky()` builds), with draw
order decided by canvas insertion order. One of them should go — see §6.

**(d) Two competing "where am I in the world?" authorities.** `ProgressionManager`
(`max_forward_index`, seeds, difficulty curves, `current_level`) belongs to the legacy
segment generator, but the live chunk generator uses its own `chunk_index` and never
updates `ProgressionManager`. Consequences in the live game: `hazard_worm.gd` gates itself
on `ProgressionManager.max_forward_index`, which is permanently 0, so worms
`queue_free()` themselves immediately and **worms never spawn**; `progression_manager`'s
whole difficulty curve is inert. Difficulty in the live game comes only from
`HazardConfig.min_chunk_index`/`density_increase_per_chunk`.

### 4.2 Player (`src/player/player.gd`, 734 lines)

The largest single file and the one most in need of a split. It currently owns: input
(two schemes), rolling torque, air control, jump + coyote time, a 4-direction dash with a
combo window, dynamic collision-shape blending across 3 shapes, invincibility rules,
contact iteration for both impact audio *and* hazard damage, peel-decal UV math, aging
shader driving, healing, ability equipping/unequipping + signal rewiring, score
generation, and save/load visual restore.

Natural seams, in the spirit of the existing `c_*` pattern:
`CRoller` (torque/nudge/air control), `CDash`, `CCollisionMorph`, `CPotatoVisuals`
(peel + aging + shader params), `CScore`, `CAbilityHost`. `player.gd` shrinks to wiring.

Specific issues found while reading (details in `docs/tech-debt.md`):

- `dash()` multiplies by `mass` **twice** (`jump_strength * mass * jump_multiplier *
  combo * GameManager.player_instance.mass`, where `player_instance` *is* `self`) — dash
  impulse scales with mass², so any mass tuning breaks dash disproportionately.
- Two health fields. `StatBlock` has both `max_health: float = 100.0` and
  `health: int = 100`. `GameManager.register_player` seeds `CHealth.max_health` from
  `max_health`; `player.apply_stats_from_resource()` overwrites it from `health`; the
  health *upgrade* (`upgrade_health.tres`) targets `"health"`. So after buying health,
  `health_component.max_health` is 110 while `player.heal()` and
  `_on_health_changed()` still divide by the stale `stats.max_health` (100).
- `heal()` divides by `(max_health - current_health)` with no zero guard, so healing at
  full HP produces `inf` and wipes every peel decal.
- Dead/vestigial exports: `roll_strength`, `roll_multiplier`, `prevDistance`,
  `ready_for_combo`, `_on_area_2d_body_entered` (no `Area2D` exists in `player.tscn`).
- `_input()` binds WASD to `dash()` while `roll_left`/`roll_right` are mouse buttons 1
  and 2 — which are *also* bound to `click`/`right_click`, and the camera's
  `SmoothCameraZoom` grabs the scroll wheel with its clamp commented out (unbounded
  zoom). The control scheme is undocumented and partly accidental.
- `generate_score()` uses `global_position.distance_to(Vector2.ZERO) - 414`, so *moving
  left from the origin also scores*, and the `414` is an unexplained magic offset.

### 4.3 LevelGen (`tools/LevelGen/`, ~4.4k LOC)

Solid design: a chunk window (`_gameplay_chunks`) over a persistent metadata registry
(`_chunk_meta`) so backtracking rebuilds identically, with parallax background layers
managed per-biome in their own local coordinate space and cross-faded on biome change.
The `ProcContext` object threading `rng`/`terrain_curve`/`occupied_ranges` through the
asset list is a nice touch — assets can reserve horizontal space so a barn doesn't spawn
inside a fence.

Concerns:

- **`level_maker_modular.gd` is a 940-line god object** doing chunk streaming, parallax
  layer lifecycle, biome segment bookkeeping, sky construction, celestial spawning,
  environment/glow tuning, crossfade tweening, and hazard placement. Four clear
  extractions: `ChunkStreamer`, `ParallaxLayerManager`, `BiomeVisuals` (sky + env +
  atmosphere), `HazardPlacer`.
- **`_get_chunk_index_at_x()` is a linear scan over two dictionaries, called from
  `_process`** (via `_update_visual_biome` and `_update_gameplay_window`, twice per
  frame). `_chunk_meta` grows unboundedly for the whole run — after a few thousand chunks
  that's a per-frame walk over thousands of entries.
- **`_get_biome_for_index()` sorts `_biome_map_cache.keys()` on every call**, also per
  frame. Sort once at `_ready`.
- **The atmosphere controller never loads.** `_setup_sky()` does
  `load("res://src/core/atmosphere_controller.gd")`; the file is at
  `tools/LevelGen/core/atmosphere_controller.gd`. So fog overlay, vignette, and cloud
  mass are dead — which is exactly the content that would have made the graveyard biome
  atmospheric.
- **The graveyard biome is fully built and completely unused.** 5 scripts (~460 LOC), 10
  data `.tres`, 5 layer `.tres`, and `graveyard_biome.tres` — none referenced from
  `level_gen.tscn`'s `biome_list`. It's the only biome that sets `use_fog_overlay` and
  `use_cloud_mass`, both of which depend on the broken loader above. Someone built a
  whole biome and it never shipped.
- **Biome pacing is lopsided.** `biome_list` = farm(0) → barn(23) → forest(30) →
  cave(69) → farm(100) → desert(150) → warehouse(401+). At 1024 px/chunk that's ~23
  chunks of farm, 7 of barn, 39 forest, 31 cave, 50 farm-again, **250 of desert**, then
  warehouse forever. Desert is 2.5× the length of everything before it combined. This is
  the "you end up in the last one which just goes endlessly" symptom, and it's one
  inspector array away from being fixed.
- **Every biome's `sky_top_color` is near-black** (`0.0–0.1` per channel); `farm_biome` —
  the *starting* biome — is `(0.02, 0.02, 0.10)`. ⚠️ **Corrected:** I first concluded the
  game therefore renders as permanent night. It doesn't — Alex confirms the in-game skies
  look right. The data is real, so the most likely reading is that this gradient is never
  visible, because `ThemeManager` is drawing a hardcoded blue sky at the same canvas layer.
  See §4.1(c) and `docs/tech-debt.md` A12/A13, including a 30-second experiment to confirm
  which system wins.
- **Only 2 of 7 biomes have music** (barn, forest). `_ready()` calls
  `AudioService.play_music(current_biome.music, ...)` with `current_biome = farm_biome`,
  whose `music` is null — so the run starts silent and pushes a null stream into
  `AudioService._play_sound`, which then does `if "loop" in audio_player.stream` on null.
- **RNG seeding is weak and collision-prone:** `ctx.rng.seed = (idx * 420) ^
  (profile.z_index * 420)`. Two layers with the same `z_index` in one chunk get identical
  seeds, so their scatter correlates. `ProgressionManager.get_seed_for_index()` (legacy)
  does this properly with a string hash — reuse it.
- `_ensure_biome_bg_layers_initialized` computes `b_scale` and never uses it.

### 4.4 Legacy gauntlet generator (`src/modes/gauntlet/`)

`level_generator.gd` (442) + `hill_generator.gd` (419) + `hazard_generator.gd` (94) +
`obstacle_generator.gd` (108) + support resources. The recursive recipe cache is the best
idea in the repo; `hill_generator`'s bezier-sampling with dual bake resolutions (dense
visual, RDP-simplified collision) is real craft. `world.tscn` still declares a
`StoreGenerator` node with an **inline empty GDScript** (`extends Node2D`) and an empty
`SpecialGenerator` — leftovers from an abandoned plan.

Also dead in here: `segment_start_trigger`/`segment_end_trigger` (superseded by
`segment_boundary`), `special_segment_config.gd` + `special_segment_rule.gd` (superseded
by `handcrafted_segment_rule.gd`), `wave_hill_animator` (only reachable via a `WAVE` hill
profile), and the entire `src/hazards/spawner/` tree (superseded by
`hazard_generator` + `HazardConfig`; `worm_hazard_spawner.gd` calls a
`ProgressionManager` method that doesn't exist).

### 4.5 UI / menus

`MenuManager` (path stack) + `GUI` (container/instancer) + `BaseMenu` (back-button
wiring) is a reasonable three-part design, but it's leaky:

- `GUI` preloads and permanently instantiates HUD + level-up + ability menus, while
  `MenuManager` menus are `load()`ed and `queue_free()`d per push. Two lifecycles for the
  same concept.
- `MenuManager.active_menu`'s getter does `_menu_stack[size - 1]` with no empty guard —
  reading it on an empty stack throws.
- `settings_menu.gd` extends `BaseMenu` but **`settings_menu.tscn` has no script
  attached**, so the file is dead and settings' back button works only by
  `StandardButton` metadata.
- `standard_menu.gd` is broken pseudocode (`add_child($"res://...")`).
- `hud.gd` computes `1/delta` for an FPS label every frame and writes three labels
  unconditionally; `level_up_menu.gd` has 15 `print()`s including a per-open dump.
- `leaderboard_manager.minimum_highscore`'s getter indexes the array directly; on an
  empty leaderboard it throws.
- `leaderboard_death.tscn` is loaded by `SceneLoader` as a *full scene replacement* on
  death, so the level is destroyed before the score screen. That forecloses any
  "continue from here" / run-summary-over-the-corpse design later.

### 4.6 Systems built but never wired in

Complete, non-trivial, and unreachable from any playable level:

| System | Size | Notes |
|---|---|---|
| `src/components/sequencer/` | 12 files, ~730 LOC | A visual scripting / cutscene graph: manager, runner, nodes for walk/jump/wait/set-property/function-call/conditional-branch/goto/switch-sequence, plus `Condition` resources. Genuinely ambitious. Only demo scene references it. |
| `src/dialogue/` | 7 files, ~350 LOC | Localized dialogue with auto-sizing speech bubbles, 5 languages (de/en/es/fr/ja `.translation` files are in `project.godot`), typewriter reveal. |
| `src/env/water/` | 2 files, ~400 LOC | Spring-based dynamic water with buoyancy, editor preview, two-way resize. |
| `src/env/breakable/fracturable2D.gd` | 448 LOC | Delaunay-ish polygon shattering with UV-correct shards, particles, sound, lifetime fade. Referenced by `FracturePolygon2D.tscn` only. |
| graveyard biome | ~460 LOC + 16 `.tres` | See §4.3. |

That's roughly **2,400 LOC and one whole biome of finished work sitting on the shelf.**
Not waste — but it is a signal. Each of these was built for a version of the game that
the current version doesn't have room for. Deciding what the game is (see
`docs/design-assessment.md`) is also deciding which of these come back.

---

## 5. Cross-cutting issues

**Logging.** 109 `print()` + 18 `printerr()` in shipping paths. `c_health.gd`'s setter
prints on every health change; `c_hazard._ready()` prints 3–5 lines *per hazard
instance*, and hazards are spawned by the dozen per chunk. On a long run this is
thousands of lines of stdout and measurable frame cost. A 20-line `Log` autoload with
levels, or just deletion, fixes it.

**No test or verification layer.** Zero tests, and no `--headless` smoke check in CI —
`release.yml` only exports on tag. A single "boot the project headless, load each level
scene, assert no errors" job would have caught the three broken paths in §7 immediately.
That's the cheapest quality win in the repo.

**Naming.** Four conventions in play: `snake_case.gd` (majority), `PascalCase.gd`
(`BaseMenu`, `DialogueResource`, `MainMenu`, `PathMaker`, `CustomAction`),
`camelCase.gd` (`audioService`, `settingsService`), `SCREAMING_Mixed`
(`GUI_manager.gd`, `ParallaxLayer_extender.gd`). Scenes likewise (`hud.tscn` vs
`AbilityMenu.tscn` vs `playerSpawn.tscn`). Not worth a big-bang rename, but worth
picking one (Godot convention: `snake_case` files, `PascalCase` `class_name`) and
enforcing on touch.

**Editor-time `@tool` scripts that mutate scenes.** `collisionmaker.gd` calls
`remove_child()` on *all* children every `_process` in the editor; `proc_asset_instance`
uses `child.free()` (not `queue_free`) for the same reason. These work but are the kind
of thing that eats a scene if it's ever attached to the wrong node.

**`SurfaceManager._last_impact_times`** is a `static var Dictionary` keyed by instance ID
that is never pruned. It grows for the lifetime of the process across every scene load.
Small leak, trivially fixed with a periodic sweep or a max size.

---

## 6. The stranded-value problem: `ThemeData` vs `BiomeProfile`

Worth calling out on its own, because it's the most consequential architectural fork.

`ThemeData` (legacy path) has: sky top/bottom + horizon curve as a *shader* with
old→new crossfade, sun and moon with independent size/colour/glow/halo/core-softness,
a full day/night cycle (`time_of_day` 0–1, driven by `DayNightController`), ambient
`CanvasModulate`, palette-based colour grading, fog band, GPU starfield, per-layer
parallax textures + motions with A/B sprite crossfade, tone-map exposure and glow
strength interpolated day↔night, and terrain lighting that receives sun/moon screen
position so hills self-shade. Five authored `.tres` themes exist.

`BiomeProfile` (live path) has: a two-stop sky gradient, glow toggles, fog/cloud booleans
(both broken, see §4.3), a music track, a layer list, a hazard list, and a global scale.

The live game is running on the *weaker* visual model, while the richer one renders
unconfigured on top of (or underneath) it in every scene — see §4.1(c) and
`docs/tech-debt.md` A12/A13. This is no longer just stranded value; the two are actively
fighting. **Resolving this is now a bug fix, not a nice-to-have.** Options:

1. **Port `ThemeData` into `BiomeProfile`** as a nested `visuals: ThemeData` field, let
   `level_maker_modular` drive `ThemeManager.transition_to_theme()` on biome change
   instead of building its own sky. Deletes `level_maker_modular`'s entire sky/celestial
   section (~120 LOC) and revives the day/night cycle, grading, and terrain self-shading
   for free. Highest value, moderate risk (two sky systems at the same z-layer must be
   reconciled).
2. **Delete `ThemeManager` + `src/themes/` + the legacy generator** and accept the
   simpler look. Cheapest, loses the most.
3. **Leave both.** Current state — and now known to be actively buggy, not merely wasteful.
   Not an option any more.

I'd take (1). **Update 2026-08-04:** Alex has confirmed the procedural runner will be part
of the game "one way or another, even if it's not the main mode," so the biome-streaming
model is load-bearing regardless of how the campaign question lands. That removes the reason
I'd originally given for deferring this decision — investing in `LevelGen`'s visuals is safe
now.

---

## 7. Broken references (verified absent, not guessed)

| Reference | From | Consequence |
|---|---|---|
| `res://src/main.tscn` | `SceneLoader.MAIN_GAME_SCENE` | File does not exist. Only used by `GameManager.start_new_game_at_level()` / `start_loaded_game()`, **neither of which is called by anything** — so it's a dead trap, not a live crash. `GameManager.on_game_scene_ready()` is likewise never called. The whole "boot into Main.tscn then route" flow was replaced by direct scene loads and left in. |
| `res://src/core/atmosphere_controller.gd` | `level_maker_modular._setup_sky()` | Script is at `tools/LevelGen/core/`. `load()` returns null, `_atmosphere_controller` stays null, fog/vignette/cloud-mass silently never render. |
| `ProgressionManager.get_worm_params()` | `worm_hazard_spawner.gd:11` | Method doesn't exist. Would throw if the spawner were ever used; it isn't. |
| `ProgressionManager.max_forward_index` | `hazard_worm.gd:_ready()` | Exists, but is never updated in the live game → always 0 → every worm `queue_free()`s itself. **Worms are effectively cut content.** |

---

## 8. Recommended sequence

Deliberately ordered so nothing here forecloses a design decision. Steps 1–3 are pure
cleanup and are safe to do before you've decided anything.

**Phase 0 — ~~record the decision~~ ✅ answered 2026-08-04.** `LevelGen` is the generator,
and the procedural runner stays in the game regardless of whether a campaign mode is added
alongside it. `CLAUDE.md` is correct as written. Phases 2–3 are therefore unblocked, with
one amendment noted in Phase 3.

**Phase 1 — hygiene, no behaviour change (1 day).**
`git rm` the 7 `.tmp`, 4 `.asd`, Blender test files, and `addons/godot-git-plugin/`
binaries (confirm with Alex's partner first — see `docs/open-questions.md` Q7).
Add a headless smoke-check CI job. Fix the 4 broken references in §7 (three are one-line
path/guard fixes; the fourth needs the §4.1(d) decision). **Add the `ThemeManager` visual
stack fix here too** (`docs/tech-debt.md` A12) — the 40 % colour grade and the 300
always-emitting particles are affecting every scene right now, and gating `_ensure_stack()`
on a non-null `current_theme` is a couple of lines.

**Phase 2 — the `tools/`→`src/` move (1–2 days).** Relocate `LevelGen` into `src/`.
Move `cheat_room.tscn` to `src/levels/dev/` and give the live level a real start segment.
Move `store*`/`progression_manager`/`breakable_joint_2d` out of `modes/gauntlet/`.
Pure path churn, big legibility payoff, and it makes the next step obvious.

**Phase 3 — retire the losing branch (1 day).** Safe to delete outright:
`src/hazards/spawner/`, superseded segment rules, `theme_manager_olde.gd`,
`standard_menu.gd`, `settings_menu.gd`, the empty `StoreGenerator`/`SpecialGenerator`
nodes, duplicate `terrain*`/`env_water*`.

**Amended 2026-08-04 — do *not* delete the legacy generator yet.** Two reasons emerged from
Alex's answers: (a) a campaign mode is still under discussion with his partner, and
`hill_generator`'s authorable `HillGenerationParams` shape profiles are exactly what authored
content wants; (b) it's the only thing that exercises `ThemeData`, which §6 now recommends
porting rather than dropping. Better move: **port `hill_generator`'s shape profiles into
`LevelGen` as a `ProcAsset` variant**, then delete the legacy generator once the port lands.
That converts a delete-vs-keep argument into a one-way migration.

Keep `sequencer`/`dialogue`/`water`/`fracturable` — unreferenced but not superseded, and
`fracturable2D` in particular is now on the critical path (see
`docs/design-assessment.md` §1.7). Consider a `src/_parked/` folder with a README so their
status is explicit rather than ambiguous.

**Phase 4 — finish the `GameManager` refactor (1 day).** Migrate ~30 call sites to
`RunState`/`SignalBus`, delete the proxy layer, replace `GameManager.player_instance`
with a cached reference set in `register_player`. Mechanical and mostly find-replace.

**Phase 5 — the cheap wins (1 day).** Resolve the two sky systems (§6). Biome pacing array.
Per-biome music. Strip/gate the 109 prints. `_get_chunk_index_at_x` /
`_get_biome_for_index` per-frame costs. The `mass²` dash bug and the `heal()`
divide-by-zero.

**Phase 6 — split the two god objects.** `player.gd` → components; `level_maker_modular`
→ 4 collaborators. Do this last: it's the only step that benefits from knowing what the
game actually is, and §4.2/§4.3 list the seams.

> **Sequencing note (2026-08-04).** Alex's answers make clear the binding constraint is
> *mechanical depth*, not structure (`docs/design-assessment.md` §1.7). If you only have
> appetite for one thread, do Phase 1 (it contains live bugs) and then go straight at the
> verb set — Phases 2–6 are real value but they don't move the thing that's actually
> stalling the project.

Roughly a week of unglamorous work to get from "four generations of a game" to "one
game with a clear spine." I'd do Phases 0–3 before writing any new gameplay code —
the current ambiguity is a tax on every future change, including the design experiments
in `docs/design-assessment.md`.

---

## 9. Companion documents

- `docs/tech-debt.md` — itemized dead code, defects, and hygiene, with file:line refs.
- `docs/design-assessment.md` — the gameplay-loop / longevity question and options.
- `docs/open-questions.md` — things I couldn't determine from the code. No rush.
