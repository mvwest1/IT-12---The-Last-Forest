class_name StageData
extends Resource
## Per-stage configuration. One .tres per stage, assigned to StageController.
## Designers/teachers can rebalance goals and facts without touching code.

@export var stage_id: StringName = &"stage_1"
## 1..4 — the value written to SQLite (session_records.stage_index).
@export_range(1, 4) var stage_index: int = 1
@export var title_key: String = ""
@export var objective_key: String = ""
## Trees that must reach full size (matured) to clear the stage.
@export_range(1, 50) var tree_goal: int = 5
@export var starting_seeds: int = 0
## Tree guards (Stage 2 barrier tool) the player starts with.
@export var starting_guards: int = 0
## Visual restoration at the start (Stage 1: 0.0, Stage 4 sanctuary: ~0.75).
@export_range(0.0, 1.0) var base_restoration: float = 0.0
## Shown (HIGH priority) right after the stage starts. Keep to ONE.
@export var intro_fact_ids: Array[StringName] = []
## Index 0..3 -> shown at 25 / 50 / 75 / 100 % of the goal. Leave "" to skip.
@export var milestone_fact_ids: Array[StringName] = []
## Forced card on stage clear (recap / check-for-understanding).
@export var outro_fact_id: StringName = &""
## Stage 3: every AridZone must also be hydrated.
@export var require_all_arid_zones: bool = false
## Falling below this Y costs 1 heart and respawns at the checkpoint.
@export var kill_y: float = 800.0
## Legacy: stage order now lives in AppFlow.STAGE_SCENES.
@export_file("*.tscn") var next_scene: String = ""
