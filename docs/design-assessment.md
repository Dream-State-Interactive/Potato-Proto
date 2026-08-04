# Design Assessment: the Loop and the Longevity Problem

**Written:** 2026-08-04 from a code read of the live level
(`tools/LevelGen/scenes/level_gen.tscn`), not from playing.
**Revised:** 2026-08-04 after Alex answered `docs/open-questions.md` — the recommendation in
§4 changed materially. Where I'm inferring feel rather than reading data, I say so.

**Confirmed direction (Q1, Q8, Q9):** high score is the concrete goal. Plot, linear
progression, and handcrafted-campaign artifacts are obsolete. The target is rogue-lite or
rogue-like; **the open split is whether any progression exists outside a single run.** A
procedural runner is in the game either way, even if it ends up not being the main mode. A
campaign mode alongside it is still an open conversation between Alex and his partner. This
is intended to be their first title published publicly on Steam.

---

## 0. The content cliff

**The live game only has gameplay content for its first two biomes.**

| Chunks | Biome | Hazards | Starch Points | Terrain |
|---:|---|---|---|---|
| 0–22 | farm | rock, pitchfork_special | ✓ (wave pattern) | noise hills |
| 23–29 | barn | **none** | **none** | flat floor, 2-vertex |
| 30–68 | forest | rock | ✓ (flat pattern) | noise hills |
| 69–99 | cave | **none** | **none** | floor + ceiling |
| 100–149 | farm | rock, pitchfork_special | ✓ | noise hills |
| 150–400 | desert | **none** | **none** | noise hills + big curve |
| 401→∞ | warehouse | **none** | **none** | flat floor, 2-vertex |

Sources: `BiomeProfile.hazards` in each `tools/LevelGen/biomes/*.tres` (barn, cave, desert,
warehouse are all `Array[HazardConfig]([])`), and `ProcStarchSpawner` appearing in only
`farm_Layer1.tres` and `forest_1_layer_fg.tres`. At 1024 px/chunk, chunk 150 is ~153,600 px
in — on the order of a minute or two of rolling.

Two structural notes worth keeping:

- **Barn and warehouse can barely host hazards under the current placement algorithm.**
  `_generate_biome_hazards` walks the terrain vertex list and needs
  `i + config.slot_cost < total_points`. `AssetBarnFG` and `AssetWarehouseFloor` report a
  **2-point** `terrain_curve`, while the hazards actually configured in biomes have
  `slot_cost` 16 (rock) and 32 (pitchfork_special) — so filling in their arrays with the
  existing configs would spawn nothing. A `slot_cost = 1` hazard would squeeze through, but
  only one per chunk, pinned to the midpoint. Flat-floor biomes need a different placer.
- **Worms never spawn anywhere.** `hazard_worm.gd` gates on
  `ProgressionManager.max_forward_index`, which the live generator never updates
  (`docs/tech-debt.md` A2). So the hazard roster actually reaching the player is *rocks and
  one pitchfork variant*.

> **Revised after Q3.** My first draft led with this and argued you'd been evaluating a loop
> that stops running ninety seconds in. Alex confirms the cliff is known, and adds the part I
> was missing: *"even if we do fill out hazards, levels, etc, there still just isn't that
> much mechanics going on here."*
>
> That's the more important diagnosis, and it demotes this section. Filling the cliff is
> still necessary — you can't evaluate pacing without it, and it's mostly `.tres` editing —
> but it is **not sufficient**, and I was wrong to imply it might be. More hazards in more
> biomes is more of the same verb. See §1.7, which is now the centre of this document.

---

## 1. Diagnosis of the loop

### 1.1 Spending starch costs you nothing, so the store isn't a decision

`RunState.current_starch_points`'s setter only adds to `total_starch_points` when the value
*increases*, and `player.generate_score()` scores from `total_starch_points`. So spending
starch on upgrades has **zero** score cost. Every store visit reduces to "buy everything you
can afford."

Score off `current_starch_points`, or add a banked/spent split, and every store becomes a
real question: bank for score, or convert into the survivability to reach more points? For a
rogue-lite this is the load-bearing decision, and it's a handful of lines.

### 1.2 Speed is the goal, the reward, *and* the defence

- The goal is distance, which means speed.
- Every upgrade (`roll_speed`, `jump_force`, `health`, `armor`) makes you faster or harder to stop.
- And `player.gd` grants **outright invincibility** above 4000 px/s once the circle collider
  is ≥95 % grown (`invincible_at_high_speed`, `INDESTRUCTIBLE_VELOCITY`).

The optimal strategy — hold roll-right, get fast — is also the safest, and gets safer as you
progress. No tension curve, because one axis serves offence, defence, and scoring.

**Confirmed intent (2026-08-04):** the invincibility is deliberate — "if you manage to get
enough speed, you can smash through anything without issue" — and Alex's own read is that it may
want "splitting invincible smashes off from pure speed as an upgrade or something so players
can't cheese the mechanic."

Right instinct, and the fantasy is worth keeping. The problem isn't invincibility; it's that
it's **unconditional and free**. Three ways to charge for it, which compose:

1. **Make it selective rather than blanket.** Invincible to *destructibles* (hay bales, crates,
   fry piles, box towers) but never to *hazards* (rocks, pitchforks, worms). This preserves
   "smash through anything" literally — you smash through smashable things — while hazards stay
   threats at any speed. The distinction already exists in the type system: `CHazard` marks the
   dangerous shapes, `fracturable2D` / `BreakableJoint2D` mark the breakable ones. Cheapest
   change, and it gives players a rule they can learn: *speed is safe against what you want to
   hit and dangerous against what you want to avoid.*
2. **Tie activation to tuck rather than raw velocity** (§1.7 verb 1). Then it's a held choice
   with a built-in cost — no air control while tucked — rather than a passive state you drift
   into.
3. **Put the hazard-proof version on the upgrade axis**, per Alex's suggestion. `CArmor` and the
   `armor` stat already exist (`upgrade_armor.tres`, +5/purchase from a base of 0, feeding
   percentage damage reduction in `CHealth.take_damage`), so there's a ready-made ladder:
   successive armor tiers let you plow through progressively nastier hazard classes. That turns
   the power fantasy into a *build goal* instead of a default — exactly the shape §4.3's
   rogue-lite frame wants.

Baseline (1) + activation (2) + progression (3) resolves the conflict with §1.7's smash loop
without losing anything: you still get to be unstoppable, you just have to choose it and pay
for it.

### 1.3 The abilities aren't verbs, because nothing asks for them

Extreme Torque (burst spin), Sticky (8 s wall/ceiling climb), Mashed Potato (jump → hang →
slam), Stop On A Fry (kill all momentum). Two equippable.

None has a matching *problem* in the world. No wall Sticky solves, no gap Mashed crosses, no
hazard Stop On A Fry evades. `CGrip` is genuinely sophisticated — full wall-and-ceiling
climbing with gravity cancellation and ceiling-factor blending — gated behind a toggle in a
world with no walls worth climbing. General pattern: **the mechanics are ahead of the level
design that would justify them.**

`assets/graphics/ui/icons/ability/` also has icons for `Heal`, `Shell`, and `Spike` — three
abilities designed and never implemented. Someone already felt the roster was thin.

### 1.4 Biomes are wallpaper, with one accidental exception

Only **cave** has a mechanical identity: `AssetCaveTerrain` builds *both* floor and ceiling
collision, so it's the one place the world constrains your arc.

Warehouse's `AssetWarehouseFloor` does randomise FLAT / BRIDGE (with a gap!) / STAIRS_UP /
STAIRS_DOWN — real level-shape variety, wasted 250+ chunks past where anyone stops caring.
The conveyors are pure particles: no physics, no belt force, no interaction.

A biome should change a *rule*, not a palette. Cave = ceiling. Warehouse = gaps and moving
surfaces. Barn = tight indoor space, hay to smash. Desert = long open speed with sparse
lethality. The art is done; the rules are the missing half.

### 1.5 There's nothing to come back for

`RunState.reset()` wipes stats, starch, and collected items every run. The only cross-run
persistence is a 12-entry local leaderboard. The complete save system (position, velocity,
rotation, health, peel decals, slots) is only useful in the handcrafted levels the endless
mode doesn't touch.

This is exactly Q1's open split. My view is in §4.3.

### 1.6 The roller fantasy is unexpressed

A potato rolling downhill should be about *momentum management*. All the machinery exists:

- three collision shapes blended by angular velocity (polygon → capsule → circle),
- bezier hill profiles with authorable shapes (`NOISE_HILL`/`VALLEY`/`HILL`/`WAVE`/`UPHILL`),
- `TerrainOverride` curves shaping biome-length landforms,
- per-contact impact impulse already computed every frame,
- a coyote timer, a combo-window timer, an air-control curve that scales with speed.

The player touches none of it. The collision morph is automatic. The combo timer feeds
nothing. The impact impulse only plays a sound. Input is: roll left, roll right, jump,
four-way dash, two abilities. **There is no verb for "commit to the hill."**

### 1.7 The verb set is the actual constraint — and the fix is already half-built

*This section is the answer to Q3 and the main change in this revision.*

Alex: *"The only really satisfying feedback we get is smashing into something at high speed
— and that's not enough to hold people's attention or even really get them interested to
begin with."*

Two separate problems in that sentence, and they want different responses.

**(a) "Not enough to hold attention" — a depth problem.** Right now smashing is a *side
effect*, not a mechanic. Here's the thing worth knowing: **the game already measures impact
force with high fidelity in three separate places, and every one of them throws the number
away.**

| Site | What it computes | What it's used for |
|---|---|---|
| `player.gd:286-312` (`_integrate_forces`) | per-contact `specific_impulse` = Δvelocity·normal × mass, keeping the frame's hardest hit | picking one audio sample |
| `breakable_joint_2d.gd:_physics_process` | relative velocity at the joint anchor | deciding whether a pin snaps |
| `fracturable2D.gd` | `min_break_impulse` threshold | deciding whether to shatter |

So the one thing that already feels good is precisely quantified and then discarded. Route
that impulse into a combo multiplier and score channel, and the satisfying moment *becomes*
the scoring verb. `ComboCooldownTimer` already exists on the player and currently feeds only
a vestigial `ready_for_combo` flag. This is a small change with a large effect, and it's the
highest-leverage thing in this document.

**A design frame for the verbs.** A roller's only real resource is **momentum**. Every verb
should spend, protect, or convert it. That gives a coherent set rather than a laundry list —
and all four below reuse code that already exists:

1. **Tuck — hold.** Spend control to gain speed. Make `update_collision_shapes()`
   player-driven instead of automatic. *Tucked:* circle collider, low friction, no air
   control, and (inverting §1.2) **more** damage taken. *Untucked:* polygon, grippy, full air
   control, safe. Now every hill is a decision. Reuses the entire 3-shape morph.
2. **Slam — down.** Convert height into speed and impact. `mashed_potato.gd` already
   implements jump → hang → slam; promote it from an ability to a core verb. Landing a slam
   on a downslope should convert vertical into horizontal — that conversion *is* Tiny Wings'
   whole game and it maps onto a roller exactly.
3. **Smash chain — on contact.** Impulse above a threshold on a destructible opens a combo
   window; each link multiplies; a clean smash **preserves** momentum where a bad angle
   bleeds it. Reuses the impulse math above, `ComboCooldownTimer`, `fracturable2D`,
   `BreakableJoint2D`, and `obstacle_generator`'s box towers.
4. **Grip — hold, contextual.** Trade momentum for position. `CGrip` is built; give it walls
   to climb. Cave already has ceilings.

Four verbs, on inputs that already exist, each with a real trade-off. Critically, this also
fixes §1.3: abilities stop being standalone flavour and become **modifiers on verbs** — which
is the shape a rogue-lite build system needs. "Tuck deals damage in a radius." "Slam creates
a shockwave." "Combo window doesn't decay while airborne." That's a build.

**(b) "Doesn't get them interested to begin with" — a legibility problem, not a depth one.**
This is a first-impression/marketing failure and it deserves a different fix. "Potato rolls
downhill" isn't a legible hook in a screenshot or a 6-second clip. "Potato accelerates into a
barn and detonates it into 200 tumbling pieces" is. So the destruction channel is
simultaneously the depth fix *and* the hook — which matters a lot given Q9 (Steam page,
intended first public release). `fracturable2D.gd` is 448 lines of finished,
UV-correct polygon shattering sitting in a drawer. It is the single most valuable parked
asset in the repo and it should come back first.

**What I'd be cautious about:** don't add all four verbs at once. Tuck alone is the cheapest
test of whether momentum management is fun here, and if it isn't, verbs 2–4 won't save it.

### 1.8 The speed problem — diagnosed

*Added after Q19. This is the "rolling so fast you skip a whole biome / fly into the sky /
break collision" issue, and it has specific, findable causes.*

**First, the thing to check before anything else: there is no velocity cap in the pushed
code.** I grepped for every form of clamp/limit/max-speed on `linear_velocity` across `src/`
and `tools/` and found nothing. The only speed constant on the player is
`INDESTRUCTIBLE_VELOCITY = 4000.0`, which is the *invincibility threshold*, not a cap. So
either the cap is in your partner's unpushed work (Q21), or it's the 4000 constant being
remembered as a cap. Worth confirming — a lot of the diagnosis below changes if a cap does
exist somewhere I can't see.

#### 1.8.1 Terminal velocity is an accident, not a decision

The player has **two independent, unbounded propulsion channels**, and the one that actually
sets your top speed isn't the one you think:

| Channel | Code | Damped by | Terminal value |
|---|---|---|---|
| Spin | `apply_torque(roll_input * stats.roll_speed * mass)` | project `default_angular_damp = 1.0` | modest ω; couples to linear motion only through contact friction |
| **Direct linear push** | `apply_central_force(roll_input * stats.horizontal_nudge * mass, 0)` | project `default_linear_damp = **0.1**` | **≈ 10,000 px/s** |

`player.tscn` sets no `linear_damp`/`angular_damp` overrides and `project.godot` has no
`[physics]` section at all, so both are engine defaults. That makes the ground terminal
velocity:

```
v_terminal = (horizontal_nudge · mass) / (mass · linear_damp)
           = horizontal_nudge / linear_damp
           = 1000 / 0.1
           = 10,000 px/s
```

Note that **mass cancels** — the number is `horizontal_nudge / 0.1` and nothing else. Nobody
chose 10,000 px/s; it fell out of a stat named "nudge" whose own comment describes it as a
helper ("helps counter friction and makes movement feel more responsive"). It is in fact the
dominant source of your speed, and it is not upgradeable.

**Airborne is worse, and this is what skips biomes.** `_physics_process` applies:

```gdscript
effective_air_control = clamp(base_air_control + |v.x| · air_control_velocity_scalar,
                              base_air_control, max_air_control)
                      = clamp(100 + |v.x| · 0.2, 100, 800)
```

Saturating at 800 once `|v.x| ≥ 3500`. There is **no drag counterpart in the air**, so a
launched player keeps *accelerating horizontally for the entire flight*, toward a terminal of
`800 / 0.1 = 8,000 px/s`. The launch isn't what skips the biome — the uninterrupted
mid-flight acceleration is. And because air control scales *with* current speed, it's a
positive feedback loop: faster launch → more air thrust → faster still.

#### 1.8.2 Why `roll_speed` is "the one stat you really feel"

It's the only upgrade whose step is large relative to its base:

| Upgrade | Base (`default_potato_stats.tres`) | Step | Step as % of base |
|---|---:|---:|---:|
| `upgrade_roll_speed` | 2500 | **+5000** | **+200 %** |
| `upgrade_jump_force` | 40 | +15 | +37 % |
| `upgrade_health` | 100 | +10 | +10 % |
| `upgrade_armor` | 0 | +5 | (5 % damage reduction) |

One roll-speed purchase **triples** the stat, for a `base_cost` of 100 with `+50` per level.
Three purchases put you at 17,500 — 7× base. Every other upgrade is a rounding error by
comparison, so of course roll speed is the only one that registers. **This is a data problem,
not a physics problem** — a `.tres` edit, not a refactor. Bringing the step to something like
+250 (10 %) would make all four upgrades comparably legible and immediately slow the runaway.

#### 1.8.3 Why the collisions break

`update_collision_shapes()` runs **every physics frame** and does three things that physics
engines dislike:

1. **Reassigns `collision_polygon.polygon`** with a freshly scaled `PackedVector2Array`.
   Rebuilding a collision shape every frame is both expensive and a solver discontinuity.
2. **Resizes the capsule and circle radii while the body is in contact.** Growing a shape
   inside terrain creates penetration, and the solver resolves penetration by ejecting the
   body — which is a launch you didn't ask for.
3. **Nearly doubles the body's width mid-motion.** The scaled polygon is ~49 × 91 px, the
   capsule ~44 × 90, the circle **90 × 90**. So the collider gets ~2× wider as ω crosses
   10 → 12 rad/s, and that transition is re-evaluated every frame from a value (ω) that
   collisions themselves perturb. Feedback loop: resize → penetration → ejection impulse →
   ω changes → different resize.

Good news: `player.tscn` has `continuous_cd = 2` (`CCD_MODE_CAST_SHAPE`), so tunnelling is
already handled — I'd expected that to be the culprit and it isn't. The ejection-impulse path
above is the more likely cause of "flying off into the sky" and "collision issues."

Fixes, cheapest first: add hysteresis so shapes only change on threshold *crossings*, not
continuously; or switch to three discrete states with a dead zone; or only permit a shape
change when `get_contact_count() == 0`. Best of all, per §1.7: make the morph a *player
input* (tuck), which makes it deliberate, infrequent, and legible.

#### 1.8.4 Why a whole biome vanishes — the arithmetic

Biome spans, accounting for `BiomeProfile.scale` (barn is the only non-1.0 at **2.0**, so its
chunks are 2048 px wide):

| Biome | Chunks | Width | @2,000 px/s | @4,000 px/s |
|---|---:|---:|---:|---:|
| farm | 0–22 | 23,552 px | 11.8 s | 5.9 s |
| barn | 23–29 | 14,336 px | 7.2 s | **3.6 s** |
| forest | 30–68 | 39,936 px | 20.0 s | 10.0 s |
| cave | 69–99 | 31,744 px | 15.9 s | 7.9 s |
| farm | 100–149 | 51,200 px | 25.6 s | 12.8 s |
| desert | 150–400 | 257,024 px | 128.5 s | 64.3 s |
| **to warehouse** | | **417,792 px** | **3 m 29 s** | **1 m 44 s** |

At the 10,000 px/s the physics actually permits, the entire authored biome sequence is **42
seconds**. Barn is under four seconds at moderate speed. That is the "few minutes of
gameplay," and it's arithmetic rather than opinion.

The structural point: **`biome_list` is authored in chunks, but the thing that matters is
seconds of play.** 1024 px is a meaningful unit at 500 px/s and a rounding error at 10,000.
Either raise `chunk_size` substantially, or author biome lengths as target durations and
convert — the latter is better, because it stays correct when you retune speed.

#### 1.8.5 Streaming can't keep up either

- `render_distance_px = 4000` is the generation lookahead. At 4,000 px/s that's **1.0 second**
  of world ahead of the player; at terminal speed, **0.4 s**. `_update_gameplay_window`'s
  `while player_x + render_distance_px > _last_end_position.x` loop has no iteration cap, so
  when you outrun it the generator builds chunks *synchronously until it catches up* —
  polygons, hazards, starch batchers and all. That's your hitch. Fix: scale
  `render_distance_px` from current speed so it's always N *seconds* of lookahead.
- `biome_prewarm_px = 2500` gives the next biome's backgrounds 0.6 s to spawn at 4,000 px/s.
  Hence pop-in at speed.
- `biome_transition_time = 1.0` means you're 4,000 px into a biome before its crossfade
  finishes — a quarter of the way through barn.
- Subtle one: `_get_chunk_index_at_x()`'s fallback is `int(floor(x / chunk_size))`, which
  ignores barn's `scale = 2.0`. Once you've passed barn, that estimate is permanently ~7
  chunks low. It's only used when `x` isn't inside any loaded or recorded chunk — i.e. exactly
  when the player has launched far outside the window — so it can mis-assign the visual biome
  mid-flight.

#### 1.8.6 The lever inventory

*Rewritten after Alex's reply. My previous version recommended "cap horizontal velocity,"
which is precisely the invisible wall he's arguing against — a hard `clamp()` on
`linear_velocity` is the last line of defence, not the design. His framing:*

> "We want to let players go as fast as possible — but at some point, the level turns into a
> blur and there's no time to react. We're aiming for the fun nestled between 'I can't go
> faster than this??' and going so fast that you blinked and missed a whole biome. […] I'd
> like to have as many levers to address this problem as I can."

**One reframe worth making explicit first: the two ends of that window are governed by
different things.** The lower bound ("I can't go faster??") is about *propulsion authority* —
whether pushing harder still yields something. The upper bound ("blinked and missed it") is
about *reaction time*, which is a function of speed **and** lookahead **and** how legible the
terrain is. So widening the sweet spot isn't only about restraining the player; roughly half
the available levers make higher speeds *survivable* rather than making them unreachable. The
camera one (L21) is the clearest case — it raises the blur threshold without touching physics
at all, and the machinery is already in the repo.

**Soft** = self-correcting and legible to the player; diminishing returns they can feel.
**Hard** = a discontinuity the player experiences as an arbitrary wall.

##### Damping & drag — shape the ceiling

| # | Lever | Where | Effect on the curve | Kind | Cost |
|---|---|---|---|---|---|
| L1 | `linear_damp` on the player | `player.tscn` (currently unset → project default 0.1) | Ceiling scales as `1/d`; exponential approach. Halving speed = doubling damp. | soft | trivial |
| L2 | **Quadratic drag** — apply `-k·v·\|v\|` centrally | ~5 lines in `_physics_process` | Terminal = `sqrt(F/k)`. Much firmer knee than linear damp while still asymptotic. Physically the "air resistance" model. | soft | ~30 min |
| L3 | Speed-dependent damp **curve** | expose a `Curve` on `StatBlock` | Full authorial control of the whole speed band, tunable in the inspector. Matches how the project already does data (`TerrainOverride.curve`). | soft | ~1 hr |
| L4 | `angular_damp` | `player.tscn` / project | Bounds ω, which bounds how much rolling friction can convert into linear speed. Targets the torque channel specifically. | soft | trivial |

##### Propulsion authority — shape how you *reach* speed

| # | Lever | Where | Effect on the curve | Kind | Cost |
|---|---|---|---|---|---|
| L5 | `horizontal_nudge` magnitude | `default_potato_stats.tres` (1000) | Direct multiplier on the ceiling (`nudge / linear_damp`). | soft | trivial |
| L6 | **Thrust falloff with speed** — `nudge · (1 - smoothstep(v_comfort, v_max, \|v.x\|))` | `player.gd:396-397` | Brisk acceleration low down, natural asymptote up high. Reads diegetically as "can't push faster than you're already rolling." What most racing games do. | soft | ~30 min |
| L7 | Remove **forward** thrust from air control, keep steering | `player.gd:400-415` | Not a limiter — removes an *unintended accelerator*. Biggest single fix for skipping, and makes launches feel more committed (your arc is set once airborne). | soft | ~20 min |
| L8 | `roll_speed` base + the **upgrade step** | `default_potato_stats.tres`, `upgrade_roll_speed.tres` | Governs runaway *across a run* rather than the instantaneous ceiling. +200 %/purchase today (§1.8.2). | soft | trivial |
| L9 | `grip` → `physics_material_override.friction` | `player.apply_stats_from_resource()` | How much spin converts to forward motion. Lower grip = more skid, less conversion. | soft | trivial |
| L10 | Dash impulse + the **10× combo** | `player.gd:441-458` | A discrete speed *injector* — currently the largest single one (≈2400 px/s per combo'd dash, ×2 per airtime), plus the `mass²` bug. | hard-ish | ~20 min |

##### Gravity & airtime — shape the launch

| # | Lever | Where | Effect on the curve | Kind | Cost |
|---|---|---|---|---|---|
| L11 | `gravity_scale` on the player | `player.tscn` (unset → 1.0, project gravity 980) | Shorter airtime → shorter launches → less skipping, with no effect on ground speed. Reads as "the potato is heavy." | soft | trivial |
| L12 | **Asymmetric gravity** (heavier while ascending, or above a speed) | `_integrate_forces` | Keeps the launch punchy off the ramp but pulls you down sooner. Standard platformer technique. | soft | ~30 min |
| L13 | **Airtime-ramped gravity** | `_physics_process` | Bounds flight *duration* without bounding speed — directly targets "skipped a whole biome" rather than "went fast." | soft | ~30 min |

##### Terrain — shape what speed *does*

| # | Lever | Where | Effect on the curve | Kind | Cost |
|---|---|---|---|---|---|
| L14 | Gameplay terrain **step size** | `proc_terrain_asset.gd` — `step = 20.0` | At 66 px/frame, 20 px segments mean vertex corners act as unintended ramps. Finer steps (or a smoothing pass on the collision curve) remove *accidental* launches while leaving authored ones. Probably the highest-value single constant here. | soft | ~1 hr |
| L15 | Per-biome `noise_amp` / `noise_freq` | each biome's terrain `.tres` | Bumpiness is launch probability. Smoother terrain in fast biomes = diegetic pacing, no rules changed. | soft | trivial |
| L16 | `TerrainOverride` curves | `level_gen.tscn` inspector | Put ramps where you *want* launches and flat runs where you don't. Authored intent instead of emergent accident. | soft | free (data) |
| L17 | **Ceilings / tunnels** | `AssetCaveTerrain` already builds them | Physically and diegetically forecloses launching. Cave is the proof it works; barn and warehouse are indoors and could use it too. | soft | low (pattern exists) |
| L18 | **Uphill sections** | `HillGenerationParams.UPHILL` (legacy gen) / `TerrainOverride` | The most diegetic governor available to a roller: hills. Bleeds speed for free and the player never feels cheated. Worth porting with the shape profiles. | soft | medium |

##### Player choice & incentive — make speed a decision

| # | Lever | Where | Effect on the curve | Kind | Cost |
|---|---|---|---|---|---|
| L19 | **Held tuck** (§1.7 verb 1) | `update_collision_shapes()` | The brake the game currently lacks. Untucked = grippy and controllable; tucked = fast and fragile. Turns "as fast as possible" from the default into a choice. | soft | ~half day |
| L20 | **Condition** `invincible_at_high_speed` rather than remove it | `player.gd:271-276` | Confirmed deliberate (§1.2). Selective (destructibles yes, hazards no) + tuck-gated + armor-tiered makes the player *self*-regulate without losing the fantasy. Strongest form of "many levers," because the limit is a choice rather than a rule. | soft | ~half day |
| L21 | **Speed-based camera zoom-out** — *already your plan* | `c_zoom.gd` already has `_target_zoom` + lerping | Raises the speed at which the level becomes a blur, i.e. widens the sweet spot from the *perception* side rather than the physics side. Confirmed intent: velocity-driven with a clamped band the player can still influence — which is better than pure auto-zoom, since it keeps agency. | soft | ~1 hr |
| L22 | Camera lead / lookahead offset in travel direction | `Camera2D` on the player | More reaction time at the same speed. Compounds with L21. | soft | ~30 min |
| L23 | **Score off combos rather than raw distance** | `player.generate_score()` | Today score is `distance · 0.1 + starch · 10`, so the *incentive* is to redline. If score came from smash/combo chains (§1.7), the player's own reason to max out drops. An economic lever, not a physical one — and probably the most underrated on this list. | soft | ~half day |
| L24 | Hard `clamp()` on `linear_velocity` | `_integrate_forces` | The invisible wall. Also fights the solver and causes jitter. | **hard** | trivial |

L24 is on the list only so it's explicitly the *last* resort, as you said.

##### A suggested starting combination

Not a prescription — a starting point to tune away from, chosen so each lever addresses a
different failure and none of them is a wall:

- **L7** (air control steers, doesn't thrust) — removes the actual biome-skipping mechanism.
- **L2 or L3** (quadratic or curve-driven drag) — gives a real knee instead of `nudge/0.1`.
- **L8** (roll-speed upgrade step to ~+10 %) — stops the in-run runaway.
- **L14** (finer gameplay terrain step) — removes accidental launches, keeps authored ones.
- **L21** (speed-linked zoom) — buys back reaction time so the ceiling can be higher.
- **L19** (held tuck) — makes the whole thing a player decision rather than a system limit.

That's roughly two days of work and it moves six independent dials, which is the position you
want to be tuning from.

##### Prerequisite: instrumentation

You've said this gets resolved by playtesting, which means the tuning loop needs numbers.
`hud.gd` already draws an FPS label and a speed label (`linear_velocity.length() / 100`, oddly
labelled "MPH"). Extending that into a debug overlay — current `v.x`/`v.y`, ω, current
terminal velocity, airtime, px/sec, chunks/sec, seconds-in-biome, active collider shape — is
maybe an hour and turns "playtest and feel it out" into "playtest and read the dials." Worth
doing *before* touching any of the levers above, so you can see which one moved what.

##### Why this is the same work as §1.7

L19 is a §1.7 verb, and L20 and L23 are §1.7 mechanics. The missing brake and the missing verb
set are the same absence seen from two sides: the game has no way for the player to trade speed
for anything, so speed has no cost, so it runs away. Fix the trade and the tuning problem gets
substantially smaller.

---

## 2. What the codebase is telling you it wants to be

Three games' worth of intent, each with real code behind it. Q1 resolves this in favour of B,
with C as the reward channel — but the artifacts are worth naming because they explain the
repo's shape.

**Game A — "Alto's Odyssey with a potato."** Momentum, lines, biomes as mood, score
multipliers. Evidence: legacy `hill_generator`'s authorable hill shapes, `ThemeData`'s
day/night + parallax crossfade, the collision morph, the score formula. The most complete
*visual* vision in the repo.

**Game B — "roguelite runner."** Evidence: equippable ability slots with a shop, scaling stat
upgrades, `special_chunk_list` placing stores at fixed chunk indices, biome list as act
structure, `HazardConfig.min_chunk_index` unlock gating, the Goobie shopkeeper.
**Confirmed as the direction.**

**Game C — "physics destruction toy."** Evidence: `fracturable2D.gd`, `BreakableJoint2D`,
`obstacle_generator`'s breakable towers, the segmented worm, spring water, peel/aging damage
visuals, physics buttons. **Per Q3, this is where the fun already is.** Not a game on its own
— but as B's reward channel it's the missing half.

---

## 3. Four directions (superseded by §4, kept for reference)

- **D1 — Momentum score attack.** High reuse (collision morph, hill shapes,
  `TerrainOverride`, surface system, `ThemeData`). Cheapest hypothesis to falsify.
- **D2 — Roguelite run structure.** Highest reuse of the shop/ability/upgrade stack; biggest
  content bill. **Chosen frame.**
- **D3 — Handcrafted campaign.** Only option where the save system earns its keep; cost is
  per-level authoring, forever. Still open between Alex and his partner — see §4.4.
- **D4 — Destruction sandbox.** Great ingredient, not a whole game. Promoted from "optional"
  to "required" by Q3 — see §1.7.

---

## 4. Recommendation (revised)

### 4.1 Order of work

0. **Confirm whether a velocity cap exists** (§1.8). There isn't one in the pushed code. If
   it's in your partner's tree, everything in §1.8 needs re-reading against his version
   first. *Minutes.*
1. **Build the tuning instrumentation, then install the levers (§1.8.6).** First the debug
   overlay (speed, ω, terminal velocity, airtime, px/sec, seconds-in-biome) so playtesting
   produces numbers rather than impressions. Then the suggested starting combination — air
   control steers rather than thrusts (L7), drag with a real knee (L2/L3), roll-speed upgrade
   step (L8), finer gameplay terrain step (L14), speed-linked camera zoom (L21) — plus
   hysteresis on the collision morph (§1.8.3). Six independent dials, no hard cap. Until this
   exists you can't tune anything else, because every other number is measured against a top
   speed nobody chose. *~2 days.*
2. **Fix the live rendering bugs** (`docs/tech-debt.md` A12) — a 40 % colour grade and 300
   always-emitting particles are affecting every scene right now. You cannot evaluate feel
   through a broken frame. *Hours.*
3. **Prove the verb set (§1.7).** Held tuck, speed-invincibility removed, impulse → combo
   multiplier on the HUD, and `fracturable2D` on one destructible type. This is the
   experiment that decides whether the project is worth finishing. Note that held-tuck is
   *also* step 1's design fix — it's the brake the game currently lacks. *Days.*
4. **Make the store a decision (§1.1).** Score from unspent starch; store offers 1 of 3.
   *Hours.*
5. **Fill the content cliff (§0).** Hazards and starch in all biomes, a flat-floor hazard
   placer, unbreak worms, and re-pace `biome_list` — in *seconds of play*, not chunks
   (§1.8.4). *Days.*
6. **One rule per biome (§1.4).** Cave has its ceiling; warehouse has gaps and stairs; barn
   wants smashable hay; desert wants long lines. Uses art that already exists. *Days.*
7. **Then** decide acts, gates, and the meta layer — with a loop that works under you.

Two changes from my first draft. Step 3 before step 5: filling the cliff makes the game
*complete*, fixing the verbs makes it *good*, and if the verbs don't land then a filled cliff
is just more of something nobody wants to play. And step 1 moved to the front after Q19,
because biome pacing, hazard density, store spacing, and score tuning are all denominated in
a top speed that is currently an accident (`horizontal_nudge / default_linear_damp`). Tune
those first and you'll re-tune them all again.

### 4.2 The thing to be honest about

The core mechanic is currently one verb (hold right) with an automatic reward (speed) and no
cost. Every other problem in this document is downstream of that. If §1.7 step 2 doesn't
produce something you and your partner *want to keep playing for ten minutes*, the right
answer may be to ship it small — fill the cliff, polish, publish as a modest score-attack
title, and take the pipeline experience to the next project. That's a legitimate outcome
given Q9, and it's better than a third year of ambitious drift. Worth agreeing on the
falsification criterion *before* running the experiment, so the answer means something.

### 4.3 On Q1's split: meta-progression, but deliberately thin

My recommendation is **rogue-lite** — with the meta layer kept small on purpose.

The argument: a pure rogue-like puts 100 % of its retention weight on mechanical depth and
run-to-run variety. That is precisely the axis you've identified as weak (Q3). Meta-progression
is the *cheaper* way to buy retention here, because it can gate **content that already
exists** rather than requiring new content: the 4 implemented abilities (+3 designed icons),
the unused graveyard biome, authored chunks, starting loadouts.

⚠️ **Cost estimate corrected 2026-08-04.** I originally argued `SaveManager` was already ~80 % of
the persistence you'd need. Alex has since noted save/load is up in the air — built early when the
direction was unclear, and likely to need a full rework if it's revisited. So the meta-progression
persistence is closer to greenfield than I implied.

That doesn't reverse the recommendation: a small unlock ledger (one currency, a set of unlocked
IDs) is a much simpler thing than the current save system, which serialises player position,
velocity, rotation, health, and peel decals for resuming *mid-level*. A rogue-lite doesn't need
any of that — runs aren't resumable, only the meta state persists. If anything, "save/load needs a
rework anyway" is an argument *for* the rogue-lite framing, since it lets you replace a
complicated mid-run save with a simple between-run ledger rather than maintaining both.

But the honest comparison is now "build a small new thing" rather than "finish an existing one,"
and that was load-bearing in my original argument.

Kept thin means: one unlock currency, unlocks gate existing content only, **no meta stat
trees**. Stat trees are the part that inflates into economy-balancing work and the part that
genuinely can paper over a weak core — which is the honest counter-argument to meta-progression
and the reason to bound it.

Also relevant to §4.4: unlocks give authored levels a destination inside the runner.

### 4.4 On Q8: the campaign question, and a way to not have to settle it

Alex leans away from a handcrafted campaign and flagged his own bias (wanting to finish and
move on). His partner is interested in a campaign *in addition to* a gauntlet/runner mode.
Both positions are reasonable, so rather than pick, here's the structural observation:

**In a rogue-lite, handcrafted set-pieces are content, not a separate mode.** The machinery to
inject authored scenes into the procedural stream already exists and already ships:
`special_chunk_list` (fixed chunk indices — currently placing the two stores),
`handcrafted_segment_rule.gd` (probabilistic injection with cooldowns), and the `EndMarker`
convention that every authored scene already follows.

So the partner's level-design and asset labour can go into **authored chunks** — mini-challenge
rooms, boss arenas, shops, secret rooms, set-piece destructibles — which raise run variety
inside the runner. That satisfies the "I want to design levels" impulse without paying for a
second mode with its own progression, save flow, puzzle-depth mechanics, and one-off assets.
And if the campaign happens later, those authored chunks *are* its building blocks. Nothing is
wasted in either branch, which is the property you want from a decision you can't make yet.

For the conversation with your partner, the honest costing of a *separate* campaign mode:
its own progression + UI + save flow, a deeper verb set to sustain puzzle design (the same
problem as §1.7 but larger, since puzzles need more verbs than a runner does), one-off assets
per level, and a second balance surface. Realistically it roughly doubles remaining scope. That
is a statement about scope, not about whether it would be good — it would probably be good.
The sequencing question ("runner first, ship it, campaign as the follow-on") may satisfy both
leans better than either "instead of" framing.

One thing that cuts *for* the partner and against Alex's lean: §1.3 and §1.7 both say the
mechanics are ahead of the level design justifying them. Authored content is the direct fix for
that, and it's the labour the partner is offering. Even in the pure-runner branch, you want
some of it.

---

## 5. Cheap wins, independent of direction

1. **Fix the `ThemeManager` visual stack** (`docs/tech-debt.md` A12). Every scene is currently
   rendering a hardcoded blue sky, a fixed sun, 300 stray particles, and a 40 % darkening
   colour grade with a null palette — none of it configured, all of it unintended. Gate
   `_ensure_stack()` on a non-null theme. *Highest visual value per line in the repo.* (1 hr)
2. **Settle which sky system wins** (A13). Two `CanvasLayer`s at `layer = -100`. Disable the
   `ThemeManager` autoload and run the Play level: if the sky changes, your per-biome
   `sky_*_color` data has never been visible. Then delete one system. (30 min + the fix)
3. **Stop starting the game in the cheat room.** `level_gen.tscn` sets
   `starting_segment = src/levels/zoo/cheat_room.tscn`, so a new run opens in a dev room with
   both shops and free starch. (5 min)
4. **Music in all seven biomes.** Only barn and forest have a track; the run currently *starts
   silent* because `farm_biome.music` is null, and a null stream is passed into
   `AudioService`. (1 hr + audio)
5. **Fix the score formula.** `distance_to(Vector2.ZERO)` is unsigned, so rolling *left*
   scores; and `- 414` is an unexplained magic offset. (15 min)
6. **Fix the `mass²` dash and the `heal()` divide-by-zero** — both change felt behaviour.
   (`docs/tech-debt.md` A1, A5) (30 min)
7. **Document the control scheme, then simplify it.** Mouse buttons 1/2 are bound to *both*
   `roll_left`/`roll_right` and `click`/`right_click`; WASD is a four-way air dash with a
   **10×** combo multiplier; the scroll wheel is unclamped camera zoom. Some of this looks
   accidental. Note that §1.7 wants some of these inputs back. (1 hr)
8. **Make the conveyors push.** `AssetWarehouseConveyor` is 96 lines of particles with no
   physics. A belt that actually moves you is the warehouse's rule (§1.4) nearly for free.
   (2 hrs)
9. **Turn the death screen into a run summary.** `SceneLoader` currently replaces the whole
   level with `leaderboardDeath.tscn`, destroying the run. Distance, top speed, biggest smash,
   biome reached, starch banked vs spent, best-run delta — the data exists in `RunState` and
   it's the cheapest retention mechanic there is. Also the natural home for the §4.3 meta
   currency. (half day)
10. **Ship the graveyard biome.** Fully built (5 scripts, 16 resources), simply absent from
    `biome_list`, and needs the one-line atmosphere-controller path fix
    (`docs/tech-debt.md` A3) for its fog and cloud mass. Free biome. (1 hr)

Items 1, 2, 3, and 10 would change first-impression quality more than any refactor in
`docs/architecture-review.md`, and none of them is a design decision.
