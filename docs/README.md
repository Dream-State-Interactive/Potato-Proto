# docs/

Evaluation pass on `feat_Theme_k` @ `5f542a2`. **Created 2026-08-04, revised 2026-08-04** after
Alex answered most of the open questions — the design recommendation changed materially, and one
of my findings was corrected into four new bugs. Read-only: no game code has been changed.

**→ Resuming on another machine? Start with [next-session.md](next-session.md).** It has the
commit-and-push step (these docs are untracked), a 15-minute verification checklist for the
things only answerable with the game running, the partner-conversation agenda, and the Phase 1
task list.

Read in this order:

1. **[design-assessment.md](design-assessment.md)** — the gameplay-loop question. Two sections
   carry it: **§1.7** (the verb set is the real constraint — the impulse the game already
   computes three separate ways should be feeding the score) and **§1.8** (why speed runs away,
   launches skip biomes, and collisions break — with the arithmetic). §4.1 is the work order,
   §4.3 the meta-progression call, §4.4 a way to defer the campaign-vs-runner decision without
   wasting work either way.
2. **[architecture-review.md](architecture-review.md)** — folder hierarchy, logical architecture,
   what's good, what's duplicated, and a phased cleanup sequence (§8). Phase 1 now contains live
   bugs, not just hygiene.
3. **[tech-debt.md](tech-debt.md)** — itemized defects, dead code, and hygiene with `file:line`
   references, severity A/B/C. **A12/A13** are the newest and most immediately actionable.
4. **[open-questions.md](open-questions.md)** — §1 answered (kept as the design record), §2 still
   open, §3 new questions raised by the answers.

Project-level orientation for future sessions lives in [`../CLAUDE.md`](../CLAUDE.md).

## Corrections log

Kept visible on purpose — these were wrong in the first pass and the corrections were productive.

- **"All biomes render as permanent night."** Withdrawn. The biome `sky_*_color` data really is
  near-black, but that isn't what renders. Chasing why produced A12/A13.
- **"`ThemeManager`'s visual stack sits inert."** Wrong — it renders in every scene with
  unconfigured baked values: a hardcoded blue sky, a fixed sun, 300 always-emitting particles,
  and a colour grade stuck at 40 % with a null palette.
- **"Filling the content cliff comes first."** Reordered. The cliff is real and known, but more
  hazards is more of one verb; the verb experiment should come first (§4.1).
- **"Smallest hazard `slot_cost` is 3."** It's 1. The conclusion about flat-floor biomes holds
  for the configs actually in use (16 and 32).
- **Assumed the launch bug was collision tunnelling.** It isn't — `player.tscn` already sets
  `continuous_cd = CCD_MODE_CAST_SHAPE`. The cause is per-frame collider resizing while in
  contact (§1.8.3).
- **"Cap horizontal velocity."** Withdrawn — that's an invisible wall. §1.8.6 is now a
  24-lever inventory with the hard clamp listed last, and the framing corrected: the two ends
  of the speed window are governed by different mechanisms, and half the levers make high
  speed *survivable* rather than unreachable.
- **"Half the control scheme looks accidental."** Wrong. Mouse-button roll is deliberate and
  intentionally wonky; the uncapped scroll zoom is a dev feature with a velocity-zoom
  replacement already planned. `tech-debt.md` B7/B8 reclassified.
- **"Remove high-speed invincibility."** It's an intended pillar, not an oversight. §1.2 now
  keeps the fantasy and makes it conditional and paid-for instead.

## Unverified premise

`docs/open-questions.md` **Q22**: Alex reports an existing max-velocity cap; I can't find one
anywhere in the pushed code. §1.8's terminal-velocity arithmetic assumes there isn't one.
Confirm before acting on that section.
