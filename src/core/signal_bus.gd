# =============================================================================
# signal_bus.gd - Global Event Bus
# =============================================================================
#
# WHAT IT IS:
# A pure signal relay hub. No state, no logic - just signal definitions.
# Any system can emit to these signals; any system can listen.
#
# WHY IT EXISTS:
# Decouples publishers from subscribers. The Player doesn't need to know
# about the HUD, and the HUD doesn't need a reference to the Player.
# Both just talk through SignalBus.
#
# =============================================================================
extends Node

# --- Player Signals ---
## Emitted when player health changes. HUD listens to update health bar.
signal player_health_updated(current: float, max_health: float)
## Emitted when player registration is complete. GUI shows HUD.
signal player_is_ready(player_node)

# --- Run State Signals ---
## Emitted when starch points change. HUD updates currency display.
signal starch_changed(new_amount: int)
## Emitted when a stat is upgraded. Level-up menu refreshes.
signal stat_upgraded(stat_name: String)

# --- Ability Signals ---
## Emitted when ability is equipped in slot 1.
signal ability1_equipped(ability_info: AbilityInfo)
## Emitted when ability is equipped in slot 2.
signal ability2_equipped(ability_info: AbilityInfo)
## Emitted to update ability 1 cooldown state (Ready/Active/Cooldown).
signal ability1_state_updated(state: int, progress: float)
## Emitted to update ability 2 cooldown state (Ready/Active/Cooldown).
signal ability2_state_updated(state: int, progress: float)

# --- Scene Signals ---
## Emitted before a scene change. Systems clean up references.
signal scene_changed
