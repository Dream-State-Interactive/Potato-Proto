# Open Questions

**Created** 2026-08-04 · **Updated** 2026-08-04 with Alex's answers to Q1, Q3–Q6, Q8, Q9.

Answered items are kept rather than deleted, because the answers are the design record.
Remaining items are in §2. New questions raised by the answers are in §3.

---

## 1. Answered

### Q1 — Is "high score" the actual design goal, or a placeholder? ✅

**Answered:** High score is the most concrete goal they have. The plot / linear progression /
handcrafted-campaign artifacts are "pretty obsolete at this point." Closest thing to a final
vision is **rogue-lite or rogue-like**, and the live split is **whether any progression exists
external to a single run.**

Alex has since flagged that this answer is *his* view, and partly conflicts with his Q8
answer, which reflects his partner's position. He expects the procedural runner to be part of
the game "one way or another, even if it's not the main mode."

**Effect:** `docs/design-assessment.md` §2 now names Game B (roguelite runner) as the
direction; §4.3 recommends rogue-lite with a deliberately thin meta layer; §4.4 proposes a way
to defer the campaign decision without wasting work either way. The runner being load-bearing
regardless also unblocks `docs/architecture-review.md` Phases 2–3.

### Q3 — Was the content cliff known? ✅

**Answered:** Yes, known. And the more important point Alex added: *"even if we do fill out
hazards, levels, etc, there still just isn't that much mechanics going on here. The only
really satisfying feedback we get is smashing into something at high speed — and that's not
enough to hold people's attention or even really get them interested to begin with."*

**Effect:** This is the single most consequential answer. `docs/design-assessment.md` §0 is
demoted with an explicit correction (I had over-weighted the cliff), and the new **§1.7** is
now the centre of that document: the verb set is the constraint, the impulse the game already
computes three separate ways should feed score, and `fracturable2D.gd` moves onto the critical
path. §4.1 reorders the work so the verb experiment comes *before* filling the cliff.

### Q4 — Is the near-black sky in all seven biomes deliberate? ✅ (and I was wrong)

**Answered:** No — and that isn't how it renders. The game has proper skies per biome. Alex's
hypothesis: "maybe the 'sky' is just the last layer in the parallax? Not 100 % sure what's
going on with this one."

**What I found chasing it:** The `.tres` data really is near-black in all 7 biomes, so
something else must be drawing. `ThemeManager` is an autoload that instantiates
`src/themes/visual_stack.tscn` in **every** scene, calls `_apply_frame()` — which early-returns
on a null theme — and then makes the Control visible anyway. So the stack renders with values
baked into the scene file: a **daytime blue sky** (`sky_top = (0.25, 0.45, 0.95)`), a sun at a
fixed `time_of_day = 0.25`, a starfield of **300 always-emitting** particles, and a
colour-grade overlay stuck at `amount = 0.4` with a **null palette**, which darkens its layer
by 40 %. Meanwhile `level_maker_modular._setup_sky()` builds a *second* `CanvasLayer` at the
same `layer = -100` holding the biome gradient.

Two sky systems, equal layer, draw order decided by canvas insertion order — which I can't
determine by reading. Full detail and a 30-second disambiguating experiment (disable the
`ThemeManager` autoload, run Play, see if the sky changes) in `docs/tech-debt.md` **A12/A13**.

**Effect:** My "renders as permanent night" claim is withdrawn and marked as corrected in
`architecture-review.md` §4.3 and `tech-debt.md` C10. More importantly my *other* claim — that
the ThemeManager stack "sits inert" (`architecture-review.md` §4.1(c)) — was also wrong, and
correcting it surfaced four live rendering bugs. `docs/design-assessment.md` §5 item 1 is now
the top cheap win. Good catch; this one was worth pushing back on.

### Q5 — Which branch? ✅

**Answered:** `feat_Theme_k` is the working branch. `origin/development` is entirely behind it
with no unique commits. The partner may have unpushed local work.

**Effect:** Analysis is current. Caveat retained only for the partner's unpushed work.

### Q6 — Godot version? ✅

**Answered:** They'll move to the latest Godot in the near future; not a priority. This VM is a
background side session on a work laptop — real work happens on Alex's home desktop, so the
local 4.6.3-vs-4.4 mismatch is irrelevant.

**Effect:** Downgraded from a warning to a note. `CLAUDE.md` keeps a one-line mention since a
future session on *this* machine could still trigger a migration, but it's no longer flagged as
a risk to manage.

### Q8 — Is level-design labour available? ✅

**Answered:** Yes. Alex leans code; his partner leans assets + level design. Alex personally
favours moving away from a handcrafted campaign (one-off assets, puzzle design, added system
depth) and named his own bias: he wants to call this project done and move on. His partner
wants a campaign *in addition to* a gauntlet/runner mode, and Alex notes his partner's tendency
toward ambitious scoping — while explicitly holding that his partner's view is as valid as his
own.

**Effect:** `docs/design-assessment.md` §4.4 addresses this without picking a side: in a
rogue-lite, handcrafted set-pieces are *content*, not a separate mode, and the injection
machinery already ships (`special_chunk_list`, `handcrafted_segment_rule`, `EndMarker`). Authored
chunks give the partner's labour a home inside the runner and double as a campaign's building
blocks if that happens later — so neither branch wastes the work. §4.4 also costs a separate
campaign mode factually (roughly doubles remaining scope) without arguing it would be bad, and
notes the point that cuts *for* the partner: §1.3/§1.7 both find the mechanics ahead of the
level design justifying them, and authored content is the direct fix.

`architecture-review.md` Phase 3 is amended: don't delete the legacy generator yet — port
`hill_generator`'s authorable shape profiles into `LevelGen` first, since authored content wants
them.

### Q9 — Is this aiming at a release? ✅

**Answered:** Yes. Already published to their Steam developer page — not public — as a pipeline
experiment. This was meant to be their first completed, publicly published project; the weak
design direction is what caused both of them to drift to other projects.

**Effect:** Raises the weight on first-impression polish and scope control, lowers it on
ambitious redesign. Directly informs `design-assessment.md` §1.7(b) (the destruction channel is
also the store-page hook) and §4.2 (ship-it-small is a legitimate outcome worth agreeing on in
advance).

---

## 2. Still open

**Q2. Which generator is the future?** — *Effectively answered:* `LevelGen`. The runner stays in
the game regardless (Q1 follow-up), so `LevelGen` is load-bearing. Remaining nuance is only
whether the legacy `hill_generator`'s shape-profile model gets ported in rather than deleted —
`architecture-review.md` Phase 3 assumes ported.

**Q7. Is the `addons/godot-git-plugin/` binary payload intentional?**
~30 MB of prebuilt `.so`/`.dylib`/`.dll` dominates repo size, and `project.godot` sets
`version_control/autoload_on_startup=true`. If your partner uses the in-editor Git UI, removing
it breaks their workflow. Needs his answer, not yours. *Assumed:* leave it; flagged only.

### Q10 — Is the control scheme intentional? ✅ mostly yes

**Answered:** Mouse-button roll is **deliberate**, and "it's a bit wonky, and that's on
purpose." The **dashes are undecided** — possibly an unlockable skill, possibly always-on — and
the combo is acknowledged as crude, currently only working off dashes. **Uncapped scroll zoom is
a dev feature**; the plan is velocity-driven zoom over a clamped band the player can influence.

**Effect:** `tech-debt.md` B8 substantially revised — I'd written that "half of it looks
accidental," which was wrong. Reclassified to: mouse-roll is a *design constraint* future
sessions shouldn't try to fix; the only genuine issue left is the mouse-1/mouse-2 overlap with
`click`/`right_click`, worth checking for gameplay↔UI input bleed given the drag-and-drop
ability slots. B7 reclassified from bug to "dev feature needing a ship-time gate" —
`OS.is_debug_build()` so it can't ship as an infinite-zoom exploit.

Two things this opens up:

- **The zoom plan is already §1.8.6 L21/L22.** "Velocity-driven with a clamped band the player
  can influence" is better than pure auto-zoom, since it keeps agency — noted in the lever
  table as confirmed rather than proposed.
- **The crude dash combo is the seed of §1.7's smash chain.** `ComboCooldownTimer` already
  exists and only dashes feed it. If impacts and smashes fed the same timer, you get the general
  combo system for free instead of building a second one. Worth designing the dash question and
  the smash-chain question *together* rather than sequentially.

### Q11 — Is high-speed invincibility a pillar or a debug convenience? ✅ pillar

**Answered:** Originally intended — "if you manage to get enough speed, you can smash through
anything without issue." Alex's own read: worth "splitting invincible smashes off from pure speed
as an upgrade or something so players can't cheese the mechanic."

**Effect:** §1.2 rewritten. The fantasy stays; what changes is that it becomes conditional and
paid-for, via three composable pieces: **selective** (invincible to destructibles, never to
hazards — a distinction the type system already draws via `CHazard` vs
`fracturable2D`/`BreakableJoint2D`), **tuck-gated** (a held choice with the no-air-control cost
built in), and **armor-tiered** (Alex's suggestion — `CArmor` and `upgrade_armor.tres` already
exist as the ladder). Lever L20 in §1.8.6 changed from "remove it" to "condition it."

That resolves the contradiction with §1.7's smash loop without losing anything: you still get to
be unstoppable, you just choose it and pay for it.

### Q12 — `max_health` or `health`? ✅ one int field

**Answered:** Original intent was `max_health` = bar size, `health` = current health — which
doesn't match how the resource is actually used. Health should be an **int**, so collapse to one
field.

**Effect:** recorded in `tech-debt.md` A4, along with a bug I found while confirming it:
`STATS_TO_SAVE` contains `"max_health"` but **not** `"health"`, so **health upgrades are silently
lost across save/load.** The saved `max_health` is always 100 because nothing upgrades it, and on
load `apply_stats_from_resource()` pushes the reverted `stats.health` back into the component.

*One nit logged there:* name the surviving field `max_health` (typed `int`) rather than `health`
— "health" reading as *current* health is the ambiguity that caused the divergence, and
`StatBlock` is a stat resource that shouldn't hold runtime state. Same decision either way;
whichever name wins, add it to `STATS_TO_SAVE`.

**Q13. Should `cheat_room.tscn` remain the live game's starting segment?** *Assumed:* no,
temporary. Listed as a 5-minute fix.

**Q14. The three unimplemented ability icons — `Heal`, `Shell`, `Spike` — designed or
speculative?** More load-bearing now: §4.3's thin meta layer wants unlockable content that
already exists, and §1.7 wants abilities reframed as verb modifiers. If there are designs behind
these three, that's most of the roster. *Assumed:* speculative art.

**Q15. Fate of the parked systems?** Partly answered by Q1 (plot/campaign artifacts are
obsolete) and Q3 (`fracturable2D` is now on the critical path). Remaining:

| System | Size | Status after your answers |
|---|---|---|
| `src/env/breakable/fracturable2D.gd` | 448 LOC | **Un-park first.** Critical path per §1.7. |
| graveyard biome | 5 scripts + 16 `.tres` | **Ship it** — one path fix away. |
| `src/env/water/` | ~400 LOC | Keep as a set-piece hazard / authored-chunk ingredient. |
| `src/components/sequencer/` | ~730 LOC | Q1 says campaign artifacts are obsolete — but this is also how you'd script a boss/gate encounter. Keep, don't invest. |
| `src/dialogue/` + 5 locales | ~350 LOC | Likely genuinely obsolete now. The 5 wired locales are the only reason to hesitate. Your call. |
| `src/hazards/knife/` | scene + config | Still unclear — a hazard that never shipped? |

**Q16. `ProgressionManager` — retire it or wire it into `LevelGen`?** *Assumed:* wire it in —
it's the cheaper fix for the never-spawning worms and its string-hash seeding is better than
`LevelGen`'s. Unchanged by your answers.

### Q17 — Execute the cleanup, or hold? ✅ execute Phase 1 next session

**Answered:** Phase 1 next session.

**Effect:** `next-session.md` §5 is now the plan rather than a contingency, with the two
decisions above folded in as extra items (collapse the health fields + add to `STATS_TO_SAVE`;
gate the dev zoom behind `OS.is_debug_build()`). Nothing in Phase 1 requires a design decision,
so it can run before the partner conversation.

---

## 3. New questions from your answers

**Q18. What's the falsification criterion for the verb experiment?**
`design-assessment.md` §4.1 step 2 (held tuck + speed risk + impulse→combo + one destructible)
is a few days of work and it's meant to answer "is this fun to play for ten minutes." Worth
agreeing with your partner *in advance* on what a "no" looks like, so the answer is actionable
rather than arguable. §4.2 makes the case that ship-it-small is a legitimate "no."

### Q19 — Verb set or inert world? ✅ *Both, plus a third thing I'd missed*

**Answered:** Both. The world generator is solid and easy to extend (new terrain types,
biomes, obstacles, hazards, scenery are all straightforward), but there are few player
abilities and the biomes are under-populated and unpolished. Plus the part I hadn't seen:

> "The one stat that you really feel right now (roll speed) quickly gets out of hand — you
> start rolling so fast that you hit a small bump, get launched into the air, and skip over a
> whole biome. We've already capped the player's max velocity […] but even that level of speed
> results in the player flying off into the sky, produces collision issues, and generally
> breaks the game in a way that's hard to account for. We do want the player to be able to do
> a cool launch off of a ramp if they hit it at speed, but right now it's way too easy to
> launch into the air and blow past everything."

**Effect:** New **§1.8** in `design-assessment.md` — a full diagnosis with causes and fixes,
and it moved to the *front* of the work order in §4.1, ahead of even the verb experiment,
because every other tunable number is denominated in a top speed nobody chose. Highlights:

- Top speed is `horizontal_nudge / default_linear_damp` = `1000 / 0.1` = **10,000 px/s**, an
  emergent number from a stat whose own comment calls it a helper. Mass cancels out.
- **Air control applies forward thrust with no drag counterpart**, so a launched player keeps
  accelerating horizontally for the whole flight (toward 8,000 px/s) — that, not the launch
  itself, is what skips biomes. It's also positive feedback, since the thrust scales with
  current speed.
- `upgrade_roll_speed.upgrade_value = 5000` on a base of `2500` = **+200 % per purchase**,
  versus +37 % (jump), +10 % (health). That's why roll speed is the only upgrade you feel, and
  it's a `.tres` edit.
- `update_collision_shapes()` rebuilds colliders **every physics frame** and grows them while
  in contact, roughly doubling body width across ω 10→12 rad/s. Penetration → solver ejection
  → almost certainly your "flying off into the sky." (`continuous_cd` is already
  `CAST_SHAPE`, so tunnelling is *not* the cause — I'd assumed it was.)
- The whole authored biome sequence is 417,792 px — **1 m 44 s at 4,000 px/s, 42 s at
  terminal**. Barn is 3.6 s. Biome lengths should be authored in seconds, not chunks.
- `render_distance_px = 4000` is 1 second of lookahead, and the generation `while` loop has no
  iteration cap — so outrunning it builds chunks synchronously until it catches up. That's the
  hitch after a launch.
- §1.8.6 gives the "keep the cool launches, lose the skipping" answer: launches are *vertical*,
  skipping is *horizontal carry*, and those are separable.

Also worth noting: held-tuck (§1.7 verb 1) is simultaneously the design fix here — right now
there is no brake, because rolling right at full speed is free.

**⚠️ One thing to check before acting on any of the above (new Q22):** I could not find a
velocity cap anywhere in the pushed code.

**Q20. Is there a target run length?**
It changes almost every pacing number: biome chunk counts, store frequency, hazard density
ramps, how much content the cliff actually needs. A 3-minute run and a 20-minute run want very
different `biome_list` arrays. Currently there's no target implied anywhere in the data.

**Q21. Does the partner have unpushed work that would invalidate any of this?**
Q5 says maybe. If he's touched `LevelGen`, the biome/hazard tables in
`design-assessment.md` §0 could already be out of date — that table is the factual basis for a
lot of the above and is worth re-checking against his tree before acting on it. Q22 below is
now the sharpest instance of this.

**Q22. Where is the velocity cap?** *(highest-priority open item)*
You mentioned having already capped max velocity. I grepped `src/` and `tools/` for every form
of clamp/limit/min/max against `linear_velocity`, plus `max_speed` / `speed_limit` /
`MAX_VEL` / `terminal`, and found **nothing**. `player.tscn` also sets no `linear_damp` or
`angular_damp` override, and `project.godot` has no `[physics]` section at all. The only speed
constant on the player is `INDESTRUCTIBLE_VELOCITY = 4000.0`, which gates invincibility rather
than capping anything.

Three possibilities: (a) it's in your partner's unpushed tree; (b) it's the 4000 constant
remembered as a cap; (c) it's expressed somewhere I didn't think to look. Which it is changes
§1.8 materially — if a real cap exists, the terminal-velocity arithmetic in §1.8.1 is wrong and
the launch diagnosis in §1.8.3 becomes the whole story instead of half of it.

### Q23 — What top speed do you want? ✅ *wrong question, and my recommendation was wrong too*

**Answered:** Not answerable off the top of his head, and deliberately so:

> "We want to let players go as fast as possible — but at some point, the level turns into a
> blur and there's no time to react. We're aiming for the fun nestled between 'I can't go
> faster than this??' and going so fast that you blinked and missed a whole biome. That sweet
> spot is going to have to be resolved through playtesting and tuning — and it may be in our
> best interest to not just have a hard speed cap as the solution. I'd like to have as many
> levers to address this problem as I can. Damping, gravity, terrain, how fast speed actually
> scales […] it shouldn't be addressed by arbitrarily saying '4000px/s and no faster.' That's
> the mechanical equivalent of an invisible wall — it's a tool in the kit, but should be the
> last line of defense."

**Effect:** §1.8.6 was rewritten from "pick a number and cap horizontal velocity" into a
**lever inventory** — 24 levers across damping, propulsion authority, gravity/airtime, terrain,
and player choice/incentive, each tagged soft-vs-hard with a cost and a note on what it does to
the speed curve. The hard `clamp()` is L24, listed explicitly as the last resort. §4.1 step 1
now leads with instrumentation rather than with a target number.

Two things I'd got wrong and one I'd missed:

- **Wrong:** "cap horizontal only" was in my previous §1.8.6 as item 3. That's the invisible
  wall — withdrawn.
- **Wrong emphasis:** I framed this as "choose a terminal velocity," implying one dial. The
  useful framing is that the *two ends of the window are governed by different mechanisms* —
  the lower bound is propulsion authority, the upper bound is reaction time. Roughly half the
  available levers make higher speeds **survivable** rather than unreachable.
- **Missed:** the camera. `c_zoom.gd` already has `_target_zoom` and smooth lerping on the
  player's `Camera2D`; driving it from `|linear_velocity|` raises the speed at which the level
  becomes a blur without touching physics at all. That widens the sweet spot from the
  perception side and it's roughly an hour of work (L21).

Also promoted: **score is a speed lever.** Score is currently `distance · 0.1 + starch · 10`,
so the *incentive* is to redline. If it came from smash/combo chains (§1.7), the player's own
reason to max out drops (L23). An economic lever rather than a physical one.

**Still open within this:** nothing blocking — the numbers come out of playtesting, as you say.
The one prerequisite is the debug overlay, since "resolved through playtesting" needs dials to
read. That's §4.1 step 1 and it's about an hour.
