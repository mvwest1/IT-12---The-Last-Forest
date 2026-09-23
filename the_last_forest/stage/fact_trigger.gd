class_name FactTrigger
extends Area2D
## Place-based learning: walking past an object (a burnt stump, a sign,
## a cracked riverbed) queues a fact. One-shot. Mask = layer 1 "player".
## Prefer attaching facts to things the child can SEE in the level.

@export var fact_id: StringName
## Matches LearningDirector.Priority (LOW = 0, NORMAL = 1, HIGH = 2).
@export_enum("LOW", "NORMAL", "HIGH") var fact_priority: int = 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	LearningDirector.request_fact(fact_id, fact_priority)
	set_deferred(&"monitoring", false)
