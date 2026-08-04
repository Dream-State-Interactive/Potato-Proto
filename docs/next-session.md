# Next Session Prep

Written 2026-08-04 at the end of a background session on a work VM with the game **not
running**. Everything in `docs/` was derived from static reading. This file exists so the next
session — on Alex's home desktop, with the game runnable — starts by *confirming or falsifying*
that, rather than re-deriving it.

---

## 0. Before leaving this machine

**`CLAUDE.md` and `docs/` are untracked.** They exist only on this VM. Commit and push, or none
of this is available on the home desktop.

```
git add CLAUDE.md docs/
git commit -m "Add evaluation docs: architecture review, tech debt, design assessment, open questions"
git push origin feat_Theme_k
```

Docs-only, no game code touched, so it's safe on `feat_Theme_k`. If you'd rather keep the
working branch clean, a `docs/evaluation` branch works equally well — but then remember to
check it out on the other machine.

---

## 1. Pull your partner's work first

Two things in these docs are derived entirely from what's currently pushed, and both would
change if he has unpushed work:

- the biome / hazard / starch table (`design-assessment.md` §0),
- the terminal-velocity arithmetic (`design-assessment.md` §1.8.1), which assumes **no velocity
  cap exists** because I couldn't find one.

Do this before acting on either.

---

## 2. First fifteen minutes: the verification checklist

Six checks. Each one either confirms or kills something I asserted from reading alone, and each
takes two minutes. This is the highest-value quarter hour available, because five sections of
`design-assessment.md` rest on these.

### 2.1 Find the velocity cap — or establish there isn't one

*Resolves `open-questions.md` Q22. Highest priority: `§1.8.1`'s whole argument depends on it.*

```
git log -S "linear_velocity" --oneline -- src/player/
git log -S "clamp" --oneline -- src/player/player.gd
grep -rn "linear_velocity" src/ tools/ | grep -iE "clamp|limit|min\(|max_"
```

Then check your partner's branch/stash. **What it decides:** if a real cap exists, `§1.8.1`'s
`10,000 px/s` figure is wrong and the launch diagnosis in `§1.8.3` becomes the whole story
rather than half of it. If there genuinely isn't one, the lever inventory (`§1.8.6`) stands as
written.

### 2.2 The two-skies experiment

*Resolves `tech-debt.md` A13.* Comment out the `ThemeManager` line in `project.godot`'s
`[autoload]` block, run the Play level, compare.

**What to look for:** does the sky change at all? **What it decides:** if it changes,
`ThemeManager` has been drawing your sky all along and the per-biome `sky_top_color` /
`sky_bottom_color` values have never been visible — which means seven biomes' worth of sky
authoring is dead data. If it doesn't change, LevelGen's gradient is winning and the theme stack
is being covered (still worth deleting, less urgent).

### 2.3 Confirm the 40 % darkening

*Resolves `tech-debt.md` A12.* Same toggle as 2.2 — take a screenshot each way and compare
brightness. Also open the main menu and look for stray `moth.png` particles drifting (the
`Starfield` node emits 300 of them in every scene).

**What it decides:** whether the game has been rendered 40 % darker than authored this whole
time. If yes, that's the cheapest visual win in the project and it's a two-line fix.

### 2.4 Does the launch correlate with the collider morph?

*Resolves `design-assessment.md` §1.8.3.* Print or overlay `angular_velocity` and which
collision shape is enabled. Roll up to speed, hit a small bump, and watch whether the launch
coincides with ω crossing **10–12 rad/s** — the band where the capsule shrinks and the circle
grows from 44 px wide to 90 px wide, every physics frame, while in contact.

**What it decides:** whether the fix is hysteresis on the shape morph, or something else
entirely. I ruled out tunnelling (`continuous_cd` is already `CAST_SHAPE`) but this is the
hypothesis I'm least able to confirm by reading.

### 2.5 Confirm terminal velocity empirically

*Resolves `design-assessment.md` §1.8.1.* Hold roll-right on flat ground and watch the HUD speed
label. Note it reads `linear_velocity.length() / 100`, so multiply by 100 for px/s.

**What to look for:** does it asymptote, and near what? My arithmetic predicts ~10,000 px/s from
`horizontal_nudge / linear_damp` = `1000 / 0.1`. **What it decides:** whether the ceiling really
is emergent from those two numbers, which is the premise of the whole lever inventory.

### 2.6 Time a barn traversal

*Resolves `design-assessment.md` §1.8.4.* Stopwatch from entering barn (chunk 23) to leaving
(chunk 29). Predicted: **3.6 s at 4,000 px/s**, 7.2 s at 2,000.

**What it decides:** whether biome pacing is as broken as the arithmetic says, and gives you the
first real data point for authoring biome lengths in seconds rather than chunks.

---

## 3. Decisions already made — don't re-litigate these

All four answered 2026-08-04. Recorded here so the next session doesn't reopen them.

| Question | Decision |
|---|---|
| High-speed invincibility (Q11) | **Keep the fantasy.** It was intended — get fast enough and you plow through things. Make it *conditional* rather than removing it: selective (destructibles yes, hazards no), tuck-gated, with armor tiers as the progression. `design-assessment.md` §1.2. |
| `max_health` vs `health` (Q12) | **One int field.** `CHealth.current_health` stays the runtime value; `StatBlock` holds only the max. Add it to `STATS_TO_SAVE` — it's currently missing, so health upgrades don't survive a save. `tech-debt.md` A4. |
| Phase 1 (Q17) | **Execute next session.** §5 below. |
| Control scheme (Q10) | **Mouse-button roll is deliberate and intentionally wonky — do not "fix" it.** Dashes are still undecided (unlockable vs always-on), and the combo is known-crude. Uncapped scroll zoom is a dev feature; gate it, then replace with velocity-driven zoom over a clamped player-influenced band. |

Two threads that opened up from those answers, worth carrying into the design work rather than
Phase 1:

- **Design the dash question and the smash-chain together.** `ComboCooldownTimer` already exists
  and only dashes feed it. That *is* §1.7's chain mechanic, wired to one input. If impacts and
  smashes fed the same timer you'd get the general combo system for free instead of building a
  second one.
- **The zoom plan is already lever L21/L22.** "Velocity-driven with a clamped band the player can
  influence" is better than pure auto-zoom because it keeps agency — and it's the lever that
  raises the speed at which the level becomes a blur, so it directly widens the sweet spot.

---

## 4. Agenda for the partner conversation

The decisions that need both of you, with why each one matters and roughly what it costs.

| Topic | The decision | Why it matters | Ref |
|---|---|---|---|
| **Campaign vs runner** | Separate campaign mode, or authored *chunks* inside the runner? | The authored-chunk route gives level-design labour a home without a second mode to finish, and those chunks are a campaign's building blocks if it happens later — so neither branch wastes work. A separate mode roughly doubles remaining scope. | `design-assessment.md` §4.4 |
| **Meta-progression** | Does anything persist between runs? | My recommendation is yes but deliberately thin: one currency, unlocks gate content that *already exists* (4 abilities + 3 designed icons + the unused graveyard biome), no meta stat trees. A pure roguelike puts all retention weight on mechanical depth — the axis you've said is weak. | §4.3 |
| **Target run length** | 3 minutes? 10? 20? | Sets biome lengths, store spacing, hazard density ramps, and how much content the cliff actually needs. Nothing in the data implies a target today. | §1.8.4, Q20 |
| **Falsification criterion** | What does "the verb experiment failed" look like? | Worth agreeing *before* running it, so the answer is actionable rather than arguable. §4.2 makes the case that ship-it-small is a legitimate "no." | §4.2, Q18 |
| **Ability roster** | Do designs exist behind the `Heal` / `Shell` / `Spike` icons? | If yes that's most of the roster a rogue-lite build system needs, and it changes the §1.7 plan from "design abilities" to "implement them." | Q14 |
| **Dialogue + 5 locales** | Genuinely obsolete, or keep? | ~350 LOC plus five `.translation` files wired into `project.godot`. Q1 says the narrative direction is dead, but the localization is a real prior commitment and deleting it is one-way. | Q15 |
| **Git plugin binaries** | Can `addons/godot-git-plugin/` be removed? | ~30 MB of prebuilt `.so`/`.dylib`/`.dll` dominates repo size, but `project.godot` has `version_control/autoload_on_startup=true` — if he uses the in-editor Git UI, removing it breaks his workflow. His call, not yours. | Q7 |

---

## 5. Phase 1 task list — **confirmed for next session**

No design decisions in any of these, so it can run before the partner conversation. Full detail
in `architecture-review.md` §8 and `tech-debt.md`.

Suggested branch: `fix/phase-1-cleanup` off `feat_Theme_k`. Items 1–3 are the ones that change
what players see, so they're worth their own commits for easy revert.

1. **`ThemeManager` visual stack** — gate `_ensure_stack()` on a non-null `current_theme`, or
   keep the `Control` hidden until a theme is applied. Kills the 40 % grade, the stray sun, and
   the 300-particle emitter in one change. (A12)
2. **Atmosphere controller path** — `level_maker_modular.gd:838` loads
   `res://src/core/atmosphere_controller.gd`; the file is at `tools/LevelGen/core/`. One line,
   and it revives fog / vignette / cloud mass. (A3)
3. **Worms** — either report chunk progress to `ProgressionManager` from
   `level_maker_modular`, or gate `hazard_worm.gd` on `ctx.chunk_index` like every other hazard.
   Currently every worm deletes itself on spawn. (A2)
4. **Dead references** — remove `SceneLoader.MAIN_GAME_SCENE` and the two uncalled
   `GameManager` methods that use it; delete or fix `worm_hazard_spawner.gd`. (C2)
5. **Null-stream guard** in `AudioService.play_music`, so a biome without music doesn't push
   null into `_play_sound`. (A8)
6. **Empty-array guards** on `MenuManager.active_menu` and
   `Leaderboard.minimum_highscore`. (A9)
7. **`git rm`** the 7 `.tmp`, 4 `.asd`, and Blender test files. Hold the git-plugin binaries
   pending §4. (C1)
8. **CI smoke check** — headless boot, load each of the five playable scenes, fail on any
   error. Would have caught items 2, 3, and 5 on its own. (B10)
9. **Collapse the health fields** per §3 — one int field on `StatBlock`. Fixes the stale
   denominator in `heal()` / `_on_health_changed()`, which is a *runtime* bug in every run. **Skip
   the `STATS_TO_SAVE` half** — it's a real omission but it's in a system that's getting reworked
   (§6b). (A4)
9b. **Delete the dangling connection** in `starch_point.tscn` — it fires `body_entered` at
   `_on_body_entered`, which doesn't exist on `StarchPoint`, `Collectible`, or `Area2D`. The real
   handler (`_on_triggered`) is wired in code. Starch points spawn in the hundreds per run, so
   this is a meaningful share of the console noise. One line. (A14)
10. **Gate the dev zoom** behind `OS.is_debug_build()` so uncapped scroll can't ship as an
    infinite-zoom exploit. Doesn't pre-empt the L21 velocity-zoom work — just stops the dev tool
    leaking into a build. (B7)

Two cheap extras if there's time, both pure data and both visible immediately:

11. **Ship the graveyard biome** — add `graveyard_biome.tres` to `level_gen.tscn`'s `biome_list`.
    Fully built (5 scripts, 16 resources) and only absent from that array; item 2 above gives it
    its fog and cloud mass. (C6/C7)
12. **Fix the `mass²` dash** (A1) and the **`heal()` divide-by-zero** (A5). Both change felt
    behaviour, both one-liners, and A1 is worth doing regardless of how the dash design lands.

---

## 6b. Save/load is parked — don't invest in it

Confirmed 2026-08-04: save/load was built early when the direction was unclear, and will likely be
reworked wholesale if it's ever revisited. Practical consequences:

- **Don't patch save/load bugs.** `STATS_TO_SAVE` omitting the upgraded health field (A4) is real
  but not worth fixing in a system that's being replaced. Note it for whoever does the rework.
- **A whole dependency tree hangs off it** (A15): `Collectible.unique_id`, the `CollectibleBaker`
  autoload, the `id_assigner_plugin` editor plugin, `RunState.collected_items`, and the
  collectible-culling loop in `GameManager.load_game_after_player_ready()`. All of it exists so
  hand-placed collectibles don't respawn after a load, and *none* of it does anything in the live
  procedural game. If save/load goes or changes shape, that's an autoload and an editor plugin
  that can go too — decide it as one thing, not piecemeal.
- **If the rogue-lite framing lands, this gets simpler, not harder.** A meta-progression ledger
  (one currency + a set of unlocked IDs) is far less than the current system, which serialises
  position, velocity, rotation, health, and peel decals to resume *mid-level*. Rogue-lite runs
  aren't resumable — only the between-run state persists. See `design-assessment.md` §4.3, where
  I've corrected an over-optimistic cost estimate that assumed `SaveManager` was reusable.

## 6. Instrumentation spec

Step 1 of the work order (`design-assessment.md` §4.1) and worth specifying now while it's
fresh. `hud.gd` already draws an FPS label and a speed label; this extends that into a
toggleable debug overlay so speed tuning produces numbers instead of impressions.

Fields, grouped:

- **Velocity** — `v.x`, `v.y`, `|v|` in px/s (not the current `/100` "MPH"); a rolling max;
  and current predicted terminal velocity so you can see the asymptote you're approaching.
- **Rotation** — `angular_velocity` in rad/s, plus which collision shape is currently enabled
  (polygon / capsule / circle / blending). Directly serves check 2.4.
- **Airtime** — current airborne duration and the longest this run. This is the number that
  actually corresponds to "skipped a whole biome," more than speed does.
- **World** — px/sec, chunks/sec, current chunk index, current biome, seconds spent in the
  current biome. Makes §1.8.4's pacing table verifiable live.
- **Impact** — last impact impulse and the running max, since §1.7 wants that value driving
  score and you'll want to see its real range before picking thresholds.

Bind it to a debug key rather than leaving it on. Note `project.godot` has no unused obvious
debug action yet — `F3` is free.

---

## 7. Don'ts

- **Don't open the project in a newer Godot without deciding on the upgrade.** It migrates
  files. An upgrade is planned but low priority (Q6) — just make it a deliberate commit.
- **Don't delete the legacy generator yet.** `hill_generator`'s authorable shape profiles
  (including `UPHILL`, which is the most diegetic speed governor available — L18) are what
  authored content wants. Port, then delete. (`architecture-review.md` §8 Phase 3)
- **Don't tune biome pacing, hazard density, or store spacing before the speed levers.** All
  three are denominated in a top speed that's currently an accident; you'd tune them twice.
- **Don't add `print()`.** There are already 109 in shipping paths, some per-frame.
- **Don't trust the §0 content table or §1.8 arithmetic until step 1 and step 2 are done.** Both
  are static-read derivations, and step 2.1 in particular could invalidate a whole section.
