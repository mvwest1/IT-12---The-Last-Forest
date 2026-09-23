# THE LAST FOREST planting setup (Godot 4)

The demo now includes a typed global event bus, a reusable hold-to-plant zone,
a sapling scene, an interaction sensor on the player, and event hooks in the
HUD. These files extend the existing `GameState`/`Interactable` architecture.

## Autoloads

`project.godot` registers these singletons in dependency order:

1. `Music`
2. `EventBus` → `res://the_last_forest/autoload/Events.gd`
3. `GameState` → `res://the_last_forest/autoload/game_state.gd`
4. `LearningDirector`
5. `SessionLog`

The global name remains `EventBus` because the existing game scripts and HUD
use that identifier. `Events.gd` is the event bus source file. It retains the
demo's richer typed signals (`seed_collected(amount, world_position)` and
`tree_planted(zone, sapling)`) because `GameState` uses the zone and sapling
references to keep planted-tree counts accurate. It also defines
`climate_tip_triggered(tip_data)` and `stage_cleared` for the requested hooks.

## Planting zone scene

Open `res://the_last_forest/planting/planting_zone.tscn`. Its root is an
`Area2D` using `PlantingZone`, with a soil visual, collision shape, sapling
anchor, prompt and in-world `ProgressBar`. The scene sets `hold_time` to 1.5
seconds and assigns `sapling.tscn` as its `sapling_scene`.

For each placed zone, verify in the Inspector:

- `Sapling Scene`: `res://the_last_forest/planting/sapling.tscn`
- `Arid Zone`: leave empty except for zones that depend on Stage 3 watering
- `Hold Time`: 1.5 (adjust for playtesting)
- Physics layer: interactables (layer 6); collision mask: none
- The player interactor's collision mask includes layer 6

Place the root at floor level. Move `SaplingAnchor` if the ground or sapling
art needs a different planting point. `ProgressBar` is sized and positioned
above the soil; style its Fill and Background in the Inspector to suit the
level palette. The player must have the `PlayerInteractor` child and its
`CollisionShape2D`; these are already added to `player.tscn`.

## Input

`PlayerInteractor` creates the `interact` action with physical E as a runtime
safety net if it is absent. Add it permanently in Project Settings → Input Map
as `interact` (E, gamepad Y, and a touch control if needed). The player scene
includes an `Interact` `TouchScreenButton` bound to this action.

`PlayerInteractor` owns the hold timer, cancellation, and target selection.
Movement, jump, fall physics, animation and shooting continue to run in
`player.gd` unchanged. Holding interaction cancels if the player moves, jumps,
releases the button, or leaves range.

## HUD and climate tips

Keep `game_hud.gd` on the HUD `Control` inside the interface `CanvasLayer`,
with its existing unique-name children (`SeedLabel`, `TreeLabel`, `TipPanel`,
`TipLabel`, and the other counters). The HUD script sets its process mode to
`Always`, so it can update while the scene tree is paused.

Emit a climate tip like this:

```gdscript
EventBus.climate_tip_triggered.emit({"text_key": "TIP_TREES_STORE_CARBON"})
```

The HUD also accepts a translation-key `String`, or a dictionary containing
`text`. The gameplay pause is acquired and released through `GameState`, so it
does not unpause while another system still owns a pause. `tip_requested` stays
as the existing non-pausing hint channel.

## Signals

- `seed_collected(amount, world_position)` — seed pickup presentation/logging
- `tree_planted(zone, sapling)` — planting event; `GameState` counts it
- `sapling_damaged(sapling, health)` — existing typed lifecycle event
- `climate_tip_triggered(tip_data)` — paused climate-literacy message for HUD
- `stage_cleared` — stage completion hook for the stage controller

`GameState` remains the source of truth for seeds and tree totals. Planting
spends a seed with `GameState.try_spend_seed()` and emits `tree_planted` only
after the sapling is created.
