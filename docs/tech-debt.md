# Tech Debt Inventory

Companion to `docs/architecture-review.md`. Everything here was verified by reading the
file — nothing is inferred. Nothing has been changed.

Severity: **A** = wrong behaviour today · **B** = will bite soon / measurable cost ·
**C** = cleanup, no behavioural risk.

---

## A — Defects with visible effect

### A1. Dash impulse scales with mass², not mass

`src/player/player.gd:449-455`

```gdscript
apply_central_impulse(Vector2(0, -jump_strength * mass * jump_multiplier
    * combo_multiplier * GameManager.player_instance.mass))
```
`GameManager.player_instance` *is* `self`, so `mass` is applied twice. With
`default_potato_stats.tres` `mass = 1.2` the dash is 20 % stronger than the formula
reads; any future mass tuning skews it quadratically. Drop the trailing
`* GameManager.player_instance.mass`.

### A2. Worms can never spawn in the live game

`src/hazards/worm/hazard_worm.gd:_ready()` gates on
`ProgressionManager.max_forward_index < unlock_at_hills` (default 3) and `queue_free()`s
itself if the check fails. `ProgressionManager.update_progress()` is only called from the
**legacy** `level_generator.gd:405`. In `level_gen.tscn` it is never called, so
`max_forward_index` is permanently 0 and every worm deletes itself on spawn.
Fix: have `level_maker_modular` report chunk progress, or gate worms on
`ctx.chunk_index` like every other hazard.

### A3. Atmosphere controller never loads → fog / vignette / cloud mass are dead

`tools/LevelGen/core/level_maker_modular.gd:838`

```gdscript
var atm_script = load("res://src/core/atmosphere_controller.gd")
```
The file is at `tools/LevelGen/core/atmosphere_controller.gd`. `load()` returns null,
`_atmosphere_controller` stays null, and the guard at `:815` silently skips
`update_biome()` forever. This is the only consumer of `BiomeProfile.use_fog_overlay`
and `use_cloud_mass` — i.e. the entire atmospheric layer of the graveyard biome.
One-line path fix.

### A4. Two health fields, three readers — and health upgrades don't survive a save

`src/player/stat_block.gd` declares both `max_health: float = 100.0` and
`health: int = 100`.

- `src/core/game_manager.gd:231-232` seeds `CHealth.max_health` from **`max_health`**.
- `src/player/player.gd:618-619` overwrites it from **`health`**.
- `src/upgrades/upgrade_health.tres` upgrades **`"health"`**.
- `src/player/player.gd:517` and `:563` still divide by **`stats.max_health`**.
- `src/core/save_manager.gd:31-34` — `STATS_TO_SAVE` contains **`"max_health"` but not
  `"health"`**.

Two distinct bugs fall out. After buying one health upgrade,
`health_component.max_health = 110` while `heal()` and `_on_health_changed()` compute percentages
against a stale 100. And because the *upgraded* field isn't in `STATS_TO_SAVE`, **health upgrades
are silently lost across save/load** — the saved `max_health` is always 100 since nothing
upgrades it, and on load `apply_stats_from_resource()` pushes the reverted `stats.health` back
into the component. Buy health, save, load, upgrades gone.

(The two `"health"` literals at `save_manager.gd:77,132` are the `player_state` key for *current*
health, not the stat — they don't cover this.)

**Priority split (Alex, 2026-08-04):** save/load is an up-in-the-air feature — built early when
the direction was unclear, and likely to be reworked wholesale if it's ever revisited. So:

- **Still worth fixing now:** the two-field divergence itself. The stale-denominator bug in
  `heal()` and `_on_health_changed()` is a *runtime* problem independent of saving, and it
  affects every run.
- **Deprioritized:** the `STATS_TO_SAVE` omission. It's a real bug, but it's a bug in a system
  that's getting replaced. Note it in whatever reworks save/load rather than patching it now.

**Decision (Alex, 2026-08-04):** the original intent was `max_health` = bar size, `health` =
current health, which doesn't match how the resource is actually used. Health should be an
**int**, and the two fields **collapse to one**. `CHealth.current_health` stays the runtime value;
`StatBlock` holds only the maximum.

*One nit worth 30 seconds when you do it:* name the surviving field **`max_health`** (typed
`int`) rather than `health`. "Health" reading as *current* health is exactly the ambiguity that
produced this divergence, and `StatBlock` is a stat resource — it shouldn't hold runtime state.
Same decision, less chance of re-colliding later. Whichever name wins, add it to `STATS_TO_SAVE`.

Related: `horizontal_nudge` **is** in `STATS_TO_SAVE` but has no upgrade — someone anticipated
making it upgradeable, which is notable given §1.8 finds it's the stat that actually governs top
speed.

### A5. `heal()` divides by zero at full health

`src/player/player.gd:567`

```gdscript
var percent_missing_health_healed = amount / (max_health - health_component.current_health)
```
At full HP the divisor is 0 → `inf` → `int(inf * size)` at `:574` clamps to `size` → the
next starch pickup **erases every peel decal**. Guard the divisor (or compute
un-peeling from actual health restored, which `CHealth.heal` already knows).

### A6. `CHealth.take_damage` assumes an `ArmorComponent` sibling exists

`src/components/c_health.gd:74` dereferences `armor_component.armor` with no null check
after a `get_node_or_null()`. Only `player.tscn` has one, so the moment `CHealth` is
reused on an enemy/breakable — which is the entire point of the component — it throws.
Add `if armor_component and armor_component.armor > 0`.

### A7. `CHealth.max_health` setter is a no-op that looks like a rescale

`src/components/c_health.gd:33-37`

```gdscript
set(value):
    max_health = value
    current_health = int((current_health/max_health) * value)   # max_health == value already
```
`max_health` is assigned *before* the ratio is computed, so the expression reduces to
`current_health = current_health`. Intent was presumably to preserve the health *fraction*
across a max-health change; it preserves the absolute value instead. Also risks a
division by zero if `max_health` is ever set to 0. Decide the intent and write it
explicitly.

### A8. Runs start silent and push a null stream into `AudioService`

`tools/LevelGen/core/level_maker_modular.gd:142` calls
`AudioService.play_music(current_biome.music, …)`. `level_gen.tscn` sets
`current_biome = farm_biome.tres`, which has **no `music` assigned** (only `barn` and
`forest` do). `AudioService._play_sound` then evaluates
`if "loop" in audio_player.stream` on a null stream. Either assign music to all 7 biomes
or early-out on a null stream in `play_music`.

### A9. Two getters index arrays without an empty guard

- `src/core/menu_manager.gd:13` — `_menu_stack[_menu_stack.size() - 1]`. Reading
  `active_menu` on an empty stack throws.
- `src/core/leaderboard_manager.gd:6-7` — with an empty `currentLeaderboard`,
  `endOfLeaderboard` is `-1`; GDScript wraps to the last element, so it throws on empty
  rather than returning a sensible floor. `leaderboard_death.gd:425` reads this on every
  death.

### A10. `settings_menu.gd` is not attached to `settings_menu.tscn`

`src/ui/menus/settings_menu.tscn` has no `script =` on its root, so the `BaseMenu`
subclass at `src/ui/menus/settings_menu.gd` never runs. Settings' back navigation works
only via `StandardButton` metadata. Either attach it or delete the script.

### A11. Score counts distance from the origin in *both* directions

`src/player/player.gd:218`

```gdscript
var distanceFromRoot = player_position.distance_to(root_position) - 414
```
`distance_to` is unsigned, so rolling left away from spawn scores the same as rolling
right. `414` is an unexplained magic constant (presumably the spawn offset). Should be
`max(0.0, global_position.x - spawn_x)` or a monotonic best-x tracker.

### A14. Every starch point carries a dangling signal connection

`src/collectibles/starch_point.tscn` ends with:

```
[connection signal="body_entered" from="." to="." method="_on_body_entered"]
```

**`_on_body_entered` is not defined** on `starch_point.gd`, on `collectible.gd`, or on `Area2D`.
Meanwhile `starch_point.gd:_ready()` separately does `body_entered.connect(_on_triggered)` — which
is the handler that actually works. Someone wired it in the editor, re-wired it in code, and left
the first one behind.

Consequence: Godot errors on the dead connection, and starch points spawn by the **hundreds** per
run via `BatchSpawner`. That's a lot of console noise on top of the 109 `print()`s (B3), and it
makes real errors hard to spot.

Fix: delete the connection line from the `.tscn`. One line, belongs in Phase 1.

*Good news from the same check:* `starch_point.tscn` bakes **no** `unique_id`, so procedurally
spawned starch has `unique_id = ""`, and both `RunState.is_item_collected()` and
`register_collected_item()` guard on `is_empty()`. So the collectible-ID system is a clean no-op
in the live game rather than a bug — I'd been worried a shared baked ID would make every starch
point after the first delete itself on spawn. It doesn't.

### A15. The collectible-ID machinery exists only to serve save/load

Not a defect — a dependency worth knowing before the save/load rework (see A4's priority split).

`Collectible.unique_id`, `RunState.collected_items`, the collectible-culling loop in
`GameManager.load_game_after_player_ready()`, the **`CollectibleBaker` autoload**
(`addons/id_assigner_plugin/collectible_baker.gd`), and the enabled **`id_assigner_plugin`**
editor plugin all exist for one purpose: so hand-placed collectibles don't respawn after loading a
save.

In an endless procedural runner, none of it does anything — per A14, procedural starch has no ID,
so the whole path is inert in the live game. If save/load is reworked or dropped, that's one
autoload, one editor plugin, and a `@tool`-script property across the `Collectible` hierarchy that
can go with it. Worth deciding together rather than piecemeal.

### A12. `ThemeManager`'s visual stack renders unmanaged in every scene

*Added 2026-08-04 after Alex reported the in-game skies look correct — my original read
(that the stack was inert) was wrong. This is the correction.*

`ThemeManager._ready()` unconditionally instantiates `src/themes/visual_stack.tscn`, sets
its `CanvasLayer.layer = -100`, calls `_apply_frame()` — which **early-returns when
`current_theme == null`** (`theme_manager.gd:244`) — and then does `ctrl.visible = true`
anyway (`:112`). In `level_gen.tscn` nothing ever calls `apply_theme()`, so the stack is
**visible and rendering with whatever was baked into the `.tscn`**, with none of the
corrective code in `_apply_frame`/`_update_overlays` ever running. Baked values:

| Node | Baked state | Effect |
|---|---|---|
| `Sky` (ColorRect) | `sky_top = (0.25, 0.45, 0.95)`, `sky_bottom = (0.85, 0.92, 1.0)`, `transition_blend = 0.0` | A full-screen **daytime blue sky**, identical in every biome and every menu. |
| `PostGrade` (ColorRect) | `amount = 0.4`, `palette_tex` **never assigned** | `palette_grade.gdshader` only skips when `amount <= 0.0001`, so it runs and does `mix(c, texture(null) = vec3(0), 0.4)` → **darkens its layer by 40 %**. `_update_overlays()` would have set `amount = 0.0` for a null palette, but it never runs. |
| `Celestials` / `CelestialsGlow` | `time_of_day = 0.25` | Draws a **sun** at a fixed position, forever. |
| `Starfield` (GPUParticles2D) | `amount = 300`, `texture = moth.png`, no `emitting = false` | GPUParticles2D defaults to `emitting = true`, so **300 particles emit in every scene**, including the main menu. `_update_stars()` never runs to gate them. |
| `FogOverlay` | `fog_color.a = 0.0` | Harmless (alpha 0). |

Each row is independently a bug. The 40 % grade and the always-on 300-particle emitter are
the two worth fixing immediately. Minimal fix: bail out of `_ensure_stack()` — or hide the
`Control` — while `current_theme == null`, rather than making it visible unconditionally.

### A13. Two sky systems draw at `CanvasLayer.layer = -100` simultaneously

In the live level both of these exist at once:

- `ThemeManager`'s `visual_stack` `CanvasLayer` (A12) — blue daytime sky, 40 %-darkened.
- `level_maker_modular._setup_sky()` (`:818-821`) — its own `CanvasLayer` at `layer = -100`
  holding a `GradientTexture2D` driven from `BiomeProfile.sky_top_color`/`sky_bottom_color`.

Equal `layer` values means draw order falls back to canvas insertion order, which I can't
determine by reading: `ThemeManager` is an autoload (registered first), but LevelGen's
canvas is created later, inside the level's `_ready()`. So either the biome gradient covers
the theme sky, or the theme sky is what you see and the biome colours are never visible.

**30-second experiment to settle it:** disable the `ThemeManager` autoload in
`project.godot` and run the Play level. If the sky changes, `ThemeManager` was drawing it
and the per-biome `sky_*_color` data has never been visible. If it doesn't change, the
biome gradient is winning and A12's stack is being covered (still wasteful, still worth
removing).

Whichever way it lands, one of the two systems should be deleted — see
`docs/architecture-review.md` §6.

---

## B — Cost / correctness risk

### B1. Per-frame linear scans in the live generator

- `_get_chunk_index_at_x()` (`level_maker_modular.gd:754`) scans `_gameplay_chunks` then
  `_chunk_meta`. `_chunk_meta` is **never pruned** — it holds every chunk generated in the
  run so far, by design (backtrack fidelity). Called twice per frame (`:175`, `:204`).
  After ~2000 chunks that's a 2000-entry dictionary walk 120×/second.
  Fix: since chunks are contiguous in x, keep a sorted `start_x` array and binary-search,
  or cache the last result and check neighbours first.
- `_get_biome_for_index()` (`:741`) calls `keys.sort()` on every invocation. Sort once in
  `_ready()`.

### B1b. Top speed is emergent, not chosen — and air control has no drag counterpart

*Added 2026-08-04 from Q19. Full analysis in `docs/design-assessment.md` §1.8.*

`player.tscn` sets no `linear_damp`/`angular_damp`, and `project.godot` has **no `[physics]`
section**, so both are engine defaults (`0.1` linear, `1.0` angular). The player's real
propulsion is not the torque but `apply_central_force(roll_input * stats.horizontal_nudge *
mass, 0)` at `player.gd:397`, which gives:

```
v_terminal = (horizontal_nudge · mass) / (mass · linear_damp) = 1000 / 0.1 = 10,000 px/s
```

Mass cancels; the number is `horizontal_nudge / 0.1` and nothing else. **There is no velocity
cap anywhere in `src/` or `tools/`** — I grepped every clamp/limit/max-speed form against
`linear_velocity`. `INDESTRUCTIBLE_VELOCITY = 4000.0` is an invincibility threshold, not a cap.

Airborne (`player.gd:400-415`), `effective_air_control = clamp(100 + |v.x|·0.2, 100, 800)`
applies forward thrust with **no drag counterpart**, so a launched player accelerates
horizontally for the whole flight toward `800 / 0.1 = 8,000 px/s` — and because the thrust
scales with current speed, it's positive feedback. This is the direct cause of launching over
an entire biome.

Fix: remove the forward component of air control (keep steering), and set terminal velocity
deliberately via speed-proportional drag rather than a hard `clamp()`, which fights the solver.

### B1c. `upgrade_roll_speed` raises its stat by 200 % per purchase

`src/upgrades/upgrade_roll_speed.tres` has `upgrade_value = 5000.0` against a base of
`2500.0` in `default_potato_stats.tres` — one purchase **triples** it, for `base_cost = 100`.
Compare `jump_force` (+37 %), `health` (+10 %), `armor` (from 0). This is why roll speed is
the only upgrade the player perceives, and why speed runs away within a run. `.tres` edit only.

### B1d. `update_collision_shapes()` rebuilds colliders every physics frame

`player.gd:671-720`, called unconditionally from `_physics_process`:

- reassigns `collision_polygon.polygon` with a new `PackedVector2Array` each frame (rebuilds
  the shape — expensive, and a solver discontinuity);
- resizes capsule/circle radii **while in contact**, so a growing shape penetrates terrain and
  the solver ejects the body;
- takes the collider from ~49 × 91 px (scaled polygon) → ~44 × 90 (capsule) → **90 × 90**
  (circle) as ω crosses 10 → 12 rad/s — roughly doubling width mid-motion, driven by a value
  (ω) that collisions themselves perturb. Feedback loop.

`continuous_cd = 2` (`CCD_MODE_CAST_SHAPE`) *is* set on the player, so tunnelling is already
handled — the ejection-impulse path above is the more likely cause of the reported
"launched into the sky" and "collision issues."

Fix: hysteresis on threshold crossings, or three discrete states with a dead zone, or only
permit a shape change when `get_contact_count() == 0`. Best: make it a player input
(`docs/design-assessment.md` §1.7 verb 1).

### B1e. Streaming lookahead is denominated in pixels, not seconds

`level_maker_modular.gd` — `render_distance_px = 4000` is **1.0 s** of lookahead at 4,000 px/s
and 0.4 s at terminal speed, and `_update_gameplay_window`'s
`while player_x + render_distance_px > _last_end_position.x` loop has **no iteration cap**, so
outrunning it generates chunks synchronously until it catches up (polygons + hazards + starch
batchers). That's the hitch after a launch. `biome_prewarm_px = 2500` gives backgrounds 0.6 s
to spawn; `biome_transition_time = 1.0` means you're 4,000 px into a biome before its
crossfade ends. Scale all three from current player speed.

Related: `_get_chunk_index_at_x()`'s fallback `int(floor(x / chunk_size))` ignores
`BiomeProfile.scale`, and barn's is **2.0** — so after barn the estimate is permanently ~7
chunks low. It only fires when `x` is outside every loaded and recorded chunk, i.e. exactly
mid-launch, where it can mis-assign the visual biome.

### B2. `GameManager.player_instance` is a tree search disguised as a property

`src/core/game_manager.gd:84-87` runs `get_tree().get_first_node_in_group("player")` on
every read. Call counts per file: `player.gd` 8 (four inside `_physics_process`/`dash`,
all to fetch its own `mass`), `level_maker_modular.gd` 6 (per `_process`), `hud.gd` 6 (per
`_process`), `mashed_potato.gd` 4, `ability_menu.gd` 3.
Fix: cache the reference in `GameManager.register_player()`; inside `player.gd` just use
`self`/`mass`.

### B3. 109 `print()` + 18 `printerr()` in shipping code, several on hot paths

Worst offenders:
- `src/components/c_health.gd:57` — every health change.
- `src/components/c_hazard.gd:_ready()` — 3–5 lines **per hazard instance**; hazards
  spawn by the dozen per chunk.
- `src/ui/menus/level_up_menu.gd` — 15 prints, including a full dump on every open.
- `src/player/player.gd` — 13, including `_on_damaged`/`force_visual_update` shader dumps.
- `src/components/sequencer/c_sequence_runner.gd` — 4 per node transition.

A minimal `Log` autoload with a level switch, or plain deletion, both work.

### B4. Weak RNG seeding in `LevelGen` correlates layers

`level_maker_modular.gd:675` — `ctx.rng.seed = (idx * 420) ^ (profile.z_index * 420)`.
Two `LayerProfile`s sharing a `z_index` inside one chunk get **identical** seeds, so
their scatter patterns line up. `ProgressionManager.get_seed_for_index()` (string-hash
based) is the correct approach already present in the repo.

### B5. `SurfaceManager._last_impact_times` never shrinks

`src/core/surface/surface_manager.gd:9` — a `static var Dictionary` keyed by collider
instance ID, written on every impact (`:22`), never pruned, and static so it survives
scene changes for the whole process. Slow unbounded growth. Sweep entries older than
`COOLDOWN_MS` on write, or cap the dictionary.

### B6. Settings migration re-runs the newest migration every launch

`src/core/settings/settingsService.gd:23` — `if schema <= CURRENT_SCHEMA`. With
`CURRENT_SCHEMA = 1` and a stored schema of 1, migration 1 executes on every boot.
Harmless today (`_ensure_section_defaults` is idempotent) but it makes destructive
migrations unsafe. Should be `<`.

### B7. Unbounded camera zoom is a dev feature that needs a ship-time gate

*Reclassified 2026-08-04 — not a bug.*

`src/components/c_zoom.gd` — the `clamp` to `min_zoom`/`max_zoom` is commented out (`:58-59`),
and the script is on the player's `Camera2D` with `scroll_up`/`scroll_down` bound to the wheel.
**Confirmed intentional:** uncapped scroll is a dev convenience. The plan is to replace it with
velocity-driven zoom over a clamped band the player can still influence — i.e.
`docs/design-assessment.md` §1.8.6 L21/L22, already on their roadmap.

Remaining actual issue: there's nothing gating it out of a release build. Put it behind
`OS.is_debug_build()` or a debug flag so the shipped game doesn't hand players an
infinite-zoom exploit, and so removing it later isn't a scramble.

### B8. Input map is undocumented, and one binding overlaps

*Substantially revised 2026-08-04. I previously wrote that "half of it looks accidental." That
was wrong — most of it is deliberate.*

Confirmed intent:

- **Mouse-button roll is deliberate**, and the wonkiness is the point. Not a bug, not a
  candidate for "fixing." Any future session should treat it as a design constraint.
- **The dashes are undecided** — possibly an unlockable skill, possibly always-on. The combo
  trigger and effect are acknowledged as crude, and currently only fire off dashes.
- **Uncapped scroll zoom is a dev feature** — see B7.

What's still worth attention:

1. **The one genuine overlap:** `roll_left` and `click` are both mouse button 1; `roll_right`
   and `right_click` are both mouse button 2 (`project.godot [input]`). Worth confirming this
   doesn't bleed between gameplay and UI — `GUI_manager._unhandled_input` and
   `store_interaction._process` both read input while a player exists, and
   `AbilityIcon`/`AbilitySlot` use drag-and-drop on mouse button 1. If it works, leave it.
2. **The `mass²` bug in `dash()`** (A1) is orthogonal to the design question and worth fixing
   whichever way dashes land.
3. **The combo system is the opening for §1.7.** `ComboCooldownTimer` exists and only dashes
   feed it — which is exactly the "chain" mechanic §1.7 wants, just wired to one input. If
   impacts and smashes also fed it, the crude dash combo becomes the general combo system
   instead of needing a separate one. Worth designing them together rather than in sequence.
4. **Nothing documents the scheme.** Given point 1 and the fact that mouse-roll is
   counter-intuitive by design, a short comment block in `player.gd` or a line in `CLAUDE.md`
   saves the next person (or the next session) from "fixing" it.

### B9. `@tool` scripts that destructively rebuild their children each editor frame

- `tools/collisionmaker/collisionmaker.gd:_process()` — `remove_child()` on *all*
  children every editor frame (also leaks the removed nodes; never freed).
- `tools/LevelGen/core/proc_asset_instance.gd:_generate()` — `child.free()` (immediate,
  not deferred) on all children.
Both work in their intended slot but will eat a scene if attached to the wrong node.

### B10. No verification layer at all

No tests, and `.github/workflows/release.yml` only runs on `v*` tags. A headless job that
boots the project and loads each of the five playable scenes, failing on any
error/`printerr`, would have caught A2/A3/A8 immediately. Cheapest quality win available.

---

## C — Dead code, duplication, hygiene

### C1. Files tracked in git that shouldn't be

```
src/ui/hud/hud2F78.tmp        src/ui/hud/hud7A.tmp        src/ui/hud/hudFAC9.tmp
src/ui/menus/MaiEBF5.tmp      src/ui/menus/pau26C6.tmp
tools/ShapeMaker/Sha5713.tmp  Sha6746.tmp  Sha6826.tmp  ShaC891.tmp
assets/sfx/sfx_proto_02.mp3.asd  ..._03.mp3.asd  ..._04.mp3.asd  ..._1.mp3.asd
assets/blendergodotpipelinetest.{obj,mtl,obj.import}
assets/blenderpipeline_test0.{glb,glb.import}
addons/godot-git-plugin/{linux,macos,win64}/   ← ~30 MB of prebuilt binaries
```
`.gitignore` already excludes `*.tmp`; these predate it. `sfx_proto_04.mp3.asd` and
`sfx_proto_1.mp3.asd` have no corresponding `.mp3` at all. The git-plugin binaries are a
per-developer editor convenience and dominate repo size.

### C2. Broken / dead references

| Reference | Site | Status |
|---|---|---|
| `res://src/main.tscn` | `src/core/scene_loader.gd:22` | File absent. Only used by `game_manager.gd:160,166`, which nothing calls. `game_manager.on_game_scene_ready()` (`:143`) likewise uncalled. Whole boot-routing flow is vestigial. |
| `ProgressionManager.get_worm_params()` | `src/hazards/spawner/worm_hazard_spawner.gd:11` | Method does not exist. Spawner is itself unused. |
| `res://src/core/atmosphere_controller.gd` | `level_maker_modular.gd:838` | See A3. |

### C3. Superseded systems still present

| Dead | Superseded by |
|---|---|
| `src/hazards/spawner/` (4 files: `hazard_system`, `hazard_spawner`, `basic_hazard_spawner`, `worm_hazard_spawner`) | `src/modes/gauntlet/hazard_generator.gd` + `HazardConfig` |
| `src/modes/gauntlet/segment_start_trigger.{gd,tscn}`, `segment_end_trigger.{gd,tscn}` | `segment_boundary.gd` (bidirectional crossing detection) |
| `src/modes/gauntlet/special_segment_config.gd`, `special_segment_rule.gd` | `handcrafted_segment_rule.gd` |
| `src/core/theme_manager_olde.gd` (8 hardcoded colour pairs) | `src/themes/theme_manager.gd` |
| `src/ui/components/standard_menu.gd` | nothing — it's non-functional pseudocode (`add_child($"res://…")`) |
| `tools/ShapeMaker/shape_maker.gd` | an inline copy embedded in `ShapeMaker.tscn` as a `SubResource` |
| `tools/terrain/terrain.gd` + `terrain.tscn` | `tools/terrain.gd` + `tools/terrain.tscn` (the scene in the subfolder points at the *root* script) |
| `tools/env_water.{gd,tscn}` | `src/env/water/water.tscn` |
| `tools/ParallaxBackground/{ParallaxLayer_extender,tilescale,fullscreen_control_ground}.gd`, `Door/` | unused variants |

### C4. Empty placeholder nodes in `src/modes/gauntlet/world.tscn`

`:52-53` — `StoreGenerator` carries an inline `SubResource("GDScript_4ied8")` whose entire
body is `extends Node2D`. `:55` — `SpecialGenerator` is a bare `Node2D`. Both are
abandoned plans.

### C5. Vestigial members in `player.gd`

`:74 roll_strength`, `:75 roll_multiplier` (exported, never read), `:81 prevDistance`,
`:139/461/465 ready_for_combo` (set, never read), `:733 _on_area_2d_body_entered` (empty;
`player.tscn` has no `Area2D`), plus commented-out zoom blocks at `:210-213` and
`:239-242` superseded by `c_zoom.gd`.

### C6. Unused elsewhere

- `tools/LevelGen/core/level_maker_modular.gd:369` — `b_scale` computed, never used.
- `src/upgrades/upgrade_grip.tres` — authored but not in `level_up_menu.tscn`'s
  `upgrades` array (only roll_speed, armor, jump_force, health are wired).
- `tools/LevelGen/assets/cave/layers/cave_layer0_ceiling.tres` — not in
  `cave_biome.tres`'s layer list.
- `assets/sfx/starchPointDing.mp3` — superseded by `StarchyCrunch.ogg`.
- `assets/graphics/ui/icons/ability/` has 7 icons for 4 implemented abilities
  (`Heal`, `Shell`, `Spike` have no ability behind them).
- `src/hazards/knife/` — `knife.tscn` + config exist; `hazard_knife_config.tres` is in
  no biome or `WorldTheme`.

### C7. Complete-but-unwired systems (**not** dead — parked)

Listed separately because deleting these would destroy real work. See
`docs/architecture-review.md` §4.6.
`src/components/sequencer/` (12 files, ~730 LOC) · `src/dialogue/` (7 files, ~350 LOC,
5 locales wired in `project.godot`) · `src/env/water/` (~400 LOC) ·
`src/env/breakable/fracturable2D.gd` (448 LOC) · the entire graveyard biome
(`tools/LevelGen/assets/graveyard/`, 5 scripts + 16 `.tres`, absent from
`level_gen.tscn`'s `biome_list`).

Suggestion: move to `src/_parked/` with a one-line README each stating *why* it's parked
and *what would bring it back*. Ambiguity is the expensive part, not the code.

### C8. Duplicate / disorganized assets

- `assets/Images/` (13 files, PascalCase) overlaps `assets/graphics/` — `potato.png`,
  `bustin.png`, `goobie.png` exist in both trees.
- Shaders split: `assets/Shaders/` (5) vs `src/themes/shaders/` (7).
- Oversized for 1080p: `assets/Images/TitleText.png` (1.8 MB),
  `assets/graphics/textures/env/proto_bg_hills_02.png` (2.8 MB).
- Case inconsistency: `assets/Music/` + `assets/Images/` + `assets/Shaders/` vs
  `assets/graphics/` + `assets/sfx/` + `assets/fonts/` + `assets/themes/`.

### C9. Naming inconsistency (four conventions)

`snake_case.gd` (majority) · `PascalCase.gd` (`BaseMenu`, `DialogueResource`,
`DialogueLineResource`, `MainMenu`, `PathMaker`, `CustomAction`, `ParallaxBackground`,
`ParallaxScroll`) · `camelCase.gd` (`audioService`, `settingsService`) · mixed
(`GUI_manager.gd`, `ParallaxLayer_extender.gd`). Scenes similarly: `hud.tscn` /
`AbilityMenu.tscn` / `playerSpawn.tscn`. Not worth a big-bang rename; worth adopting
Godot's convention (`snake_case` files, `PascalCase` `class_name`) and applying on touch.

### C10. Content / config oddities worth a look

- **`cheat_room.tscn` is the live game's starting segment.** `level_gen.tscn` sets
  `starting_segment = res://src/levels/zoo/cheat_room.tscn`, so a new run begins in a dev
  room containing both stores and a pile of starch.
- **All 7 biomes have a near-black `sky_top_color`** — every value is between `(0,0,0.1)`
  and `(0.1,0.1,0.2)`; `farm_biome` (the opening biome) is `(0.02, 0.02, 0.10)`.
  ⚠️ **Corrected 2026-08-04:** I originally wrote that the game therefore *renders* as
  permanent night. Alex confirms it does not — the in-game skies look correct. The data
  above is accurate, so the likely explanation is that these values are never visible; see
  **A12/A13**. Treat the biome sky colours as *unverified authoring*, not as what ships.
- **Biome pacing:** farm 0-22 · barn 23-29 · forest 30-68 · cave 69-99 · farm 100-149 ·
  **desert 150-400** · warehouse 401→∞. Desert alone is longer than everything preceding it.
- **Level Select's Level 2 and Level 4 point at the same scene** (`world.tscn`).
- `level_gen.tscn` sets `player_node = NodePath("PlayerSpawn")`, which is the *spawner*,
  not the player; harmless because `_process` reassigns from `GameManager.player_instance`
  on frame 1, but it's misleading in the inspector.
- `README.md` is one line (`# Potato-Proto`).
