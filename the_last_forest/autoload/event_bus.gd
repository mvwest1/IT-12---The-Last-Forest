extends Node
## EventBus (Autoload #1) — global signal hub for THE LAST FOREST.
##
## Rules:
##   1. This script holds NO state and NO logic. Signals only.
##   2. Emitters never know who listens. Listeners never call emitters back.
##   3. State lives in GameState. Objects mutate GameState through its methods;
##      GameState then emits the matching *_changed signal here.
##   4. Node references passed through signals may be freed later —
##      always guard with is_instance_valid() before storing/using them.
@warning_ignore_start("unused_signal")

# ---------------------------------------------------------------- Inventory
## A seed pickup was touched (for SFX / VFX / logging). Count lives in GameState.
signal seed_collected(amount: int, world_position: Vector2)
signal seeds_changed(total: int)
signal water_collected(amount: int)
signal water_changed(carried: int, capacity: int)

# ---------------------------------------------------------------- Generic hold-to-interact (plant, water, revive)
signal interaction_started(target: Node2D)
signal interaction_progress(target: Node2D, ratio: float)
signal interaction_cancelled(target: Node2D)
signal interaction_completed(target: Node2D)
## reason: &"no_seeds", &"occupied", &"no_water", &"not_on_floor"
signal interaction_denied(target: Node2D, reason: StringName)

# ---------------------------------------------------------------- Planting & sapling lifecycle
signal tree_planted(zone: Node2D, sapling: Node2D)
signal trees_planted_changed(total: int, goal: int)
signal sapling_stage_changed(sapling: Node2D, stage: int)
signal sapling_damaged(sapling: Node2D, health: int)
signal sapling_wilted(sapling: Node2D)
signal sapling_revived(sapling: Node2D)
signal sapling_matured(sapling: Node2D)

# ---------------------------------------------------------------- Pests (Stage 2)
signal pest_spawned(pest: Node2D)
signal pest_removed(pest: Node2D)

# ---------------------------------------------------------------- Water (Stage 3)
signal water_delivered(zone: Node2D, amount: int)
signal arid_zone_hydrated(zone: Node2D)

# ---------------------------------------------------------------- Environment feedback
## 0.0 = fully burnt, 1.0 = fully restored (visual value, includes stage base).
signal restoration_changed(ratio: float)
## milestone_index 0..3  ->  25% / 50% / 75% / 100% of the stage goal.
signal restoration_milestone_reached(milestone_index: int)

# ---------------------------------------------------------------- Player
signal player_health_changed(current: int, maximum: int)
signal player_damaged(amount: int)
signal player_defeated()

# ---------------------------------------------------------------- Stage flow
signal stage_started(stage_id: StringName)
signal objective_updated(text_key: String)
signal stage_completed(stage_id: StringName)

# ---------------------------------------------------------------- Climate literacy
signal climate_fact_unlocked(fact_id: StringName)
signal fact_card_opened(fact_id: StringName)
signal fact_card_closed(fact_id: StringName, seconds_open: float)
## Non-pausing speech-bubble tip (translation key).
signal tip_requested(text_key: String)
## Rich climate-literacy message. GameHUD may pause while this is displayed.
signal climate_tip_triggered(tip_data: Variant)

## Emitted after the active stage's objectives have been met.
signal stage_cleared

@warning_ignore_restore("unused_signal")
