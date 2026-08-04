# Potato Game (Potato-Proto)

2D physics "roller": the player is a `RigidBody2D` potato that rolls right through
procedurally generated biomes, collecting Starch Points, buying upgrades/abilities,
and dodging hazards for a high score. Godot 4 / GDScript, no C#.

## Design direction (as of 2026-08-04)

- **High score is the goal.** Plot / linear-progression / handcrafted-campaign artifacts in
  the repo are obsolete — don't treat them as the target.
- Target shape is **rogue-lite or rogue-like**. Open split: whether any progression exists
  outside a single run. A procedural runner is in the game either way; a campaign mode
  alongside it is still under discussion between the two devs.
- Known weak points: **mechanical depth** (few verbs; the only reliably satisfying feedback is
  high-speed impact) and **runaway speed** (top speed is emergent, launches skip whole biomes,
  colliders are rebuilt every frame). Read `docs/design-assessment.md` §1.7 and §1.8 before
  proposing gameplay or physics work — both contain worked diagnoses.
- Already on a private Steam developer page; intended to be their first public release.

## Deliberate choices — do not "fix" these

- **Mouse-button roll is intentional, and the wonkiness is the point.** `roll_left`/`roll_right`
  are mouse 1/2. Treat as a design constraint.
- **Uncapped scroll-wheel zoom (`c_zoom.gd`) is a dev feature.** Planned replacement is
  velocity-driven zoom over a clamped band the player can influence. Needs an
  `OS.is_debug_build()` gate, not removal.
- **High-speed invincibility is a design pillar** — get fast enough and you plow through things.
  It's under-designed rather than wrong; the plan is to make it conditional (destructibles yes,
  hazards no; tuck-gated; armor-tiered), not to delete it.
- **Still undecided, so don't assume:** whether the air dash is an unlockable or always-on, and
  how the combo triggers. The combo is known-crude and currently only fires off dashes.

## Engine + build

- Project targets **Godot 4.4** (`config/features` in `project.godot`); CI exports with 4.4.1.
  An engine update is planned but low priority. If the only local Godot is newer, opening the
  project migrates it — worth a heads-up, not a blocker.
- Release: push a `v*` tag → `.github/workflows/release.yml` exports + creates a GH release.
- No tests, no linter. Verification is manual playtesting.
- Working branch is `feat_Theme_k`. `origin/development` is strictly behind it.

## Entry points (important — not obvious from the tree)

| Path | What it is |
|---|---|
| `src/ui/menus/MainMenu.tscn` | `run/main_scene`. Immediately pushes `home_menu.tscn` via `MenuManager`. |
| `tools/LevelGen/scenes/level_gen.tscn` | **The live game.** Home menu "Play" points here. |
| `src/modes/gauntlet/world.tscn` | Older generator, reachable only via Level Select (2 & 4). |
| `src/levels/zoo/zoo_themes.tscn` | Theme-preview harness (Level 3). |
| `src/levels/level_1`, `level_proto` | Handcrafted test levels (Level 1 / Level 0). |

Buttons navigate via `metadata/destination` / `PushMenu` / `ReplacementMenu` on
`StandardButton` — scene wiring, not code.

## Two level generators (do not confuse them)

- **`tools/LevelGen/` — current.** `level_maker_modular.gd` (~940 lines) streams
  fixed-width chunks off `BiomeProfile` → `LayerProfile` → `ProcAsset` resources.
  Biome art is *drawn in code* (Polygon2D/Line2D) by `asset_*.gd` + per-biome
  `*DrawUtils` static classes — ~2.9k LOC under `tools/LevelGen/assets/`.
  Biome order and handcrafted inserts live in `level_gen.tscn`'s inspector arrays.
- **`src/modes/gauntlet/` — legacy.** `level_generator.gd` + `hill_generator.gd`
  build seeded bezier hill *segments* driven by `WorldTheme` resources, and are the
  only consumer of the `ThemeManager` autoload / `src/themes/` sky stack.

They share nothing but `HazardConfig` and the player. Pick one before touching either.

## Autoloads (`project.godot [autoload]`, order matters)

`Algorithms` `SettingsService` `DisplayManager` `AudioService` `SignalBus` `RunState`
`GameManager` `SaveManager` `SceneLoader` `MenuManager` `GUI` `CollectibleBaker`
`LanguageTester` `ProgressionManager` `Leaderboard` `ThemeManager`

- `RunState` — per-run data (starch, stats, collected IDs). **Source of truth.**
- `SignalBus` — global signal relay. **Emit/listen here.**
- `GameManager` — game flow + a large deprecated proxy layer forwarding to
  `RunState`/`SignalBus`. Read the `@deprecated` tags; write new code against the real owner.
- `GUI` (`src/core/GUI.tscn`) — owns HUD, level-up menu, ability menu, pause backdrop.
- `SceneLoader` — always use this, never `get_tree().change_scene_to_file()`.
- `SaveManager` — **parked.** Built early under an unclear direction; expected to be reworked
  wholesale. Don't patch bugs in it or build on it. A dependency tree hangs off it
  (`Collectible.unique_id`, the `CollectibleBaker` autoload, the `id_assigner_plugin` editor
  plugin) that is inert in the live procedural game — see `docs/tech-debt.md` A15.
- `ThemeManager` — only *driven* by the legacy/zoo paths, but it instantiates its full-screen
  `visual_stack.tscn` in **every** scene and currently renders it unconfigured (stray sky,
  sun, 300 particles, a 40 % colour grade). Known bug — `docs/tech-debt.md` A12. Don't
  debug unexplained visuals without reading that first.

## Conventions

- Reusable components: `src/components/c_*.gd`, `class_name CFoo`, added as child nodes;
  parents delegate to them (e.g. `player.gd` → `CGrip.process_grip_physics`).
- Data-driven config = `Resource` subclasses + `.tres` (`StatBlock`, `HazardConfig`,
  `BiomeProfile`, `WorldTheme`, `UpgradeData`, `ProcAsset`).
- Player lookup is by group: `get_tree().get_first_node_in_group("player")`.
- Handcrafted segments/chunks must contain a `Marker2D` named `EndMarker`.
- Hazard hitboxes are identified by name suffix `_hazard` (see `c_hazard.gd`).
- Naming is inconsistent (snake_case, PascalCase, camelCase all present). Match the
  local directory rather than "fixing" neighbours.
- `tools/` holds both the live generator *and* editor scratch tools
  (`PathMaker`, `ShapeMaker`, `collisionmaker`, `Trigger`, `ParallaxBackground`, `terrain`).

## Gotchas

- ~110 `print()` calls ship in gameplay code, several on hot paths (`c_health.gd`
  setter, `c_hazard._ready`). Don't add more; prefer removing when you touch a file.
- `src/env/water/`, `src/dialogue/`, `src/components/sequencer/` are complete but
  unreferenced by any live level.
- Known dead references: `SceneLoader.MAIN_GAME_SCENE` → `res://src/main.tscn` (absent);
  `level_maker_modular._setup_sky()` loads `res://src/core/atmosphere_controller.gd`
  (actual path is `tools/LevelGen/core/`); `worm_hazard_spawner.gd` calls
  `ProgressionManager.get_worm_params()` (absent).
- **Content gaps that look like bugs but are unfinished data:** only farm and forest have
  hazards or Starch Points; worms never spawn at all; the graveyard biome is complete but
  absent from `level_gen.tscn`'s `biome_list`. `docs/design-assessment.md` §0 has the table.
- See `docs/` for the full architecture review, tech-debt inventory, design assessment,
  and open questions.

## Repo hygiene

Do not commit: `.tmp` (Godot editor temp saves), `.asd` (Audacity), `.godot/`.
Several are already tracked — see `docs/tech-debt.md`.
