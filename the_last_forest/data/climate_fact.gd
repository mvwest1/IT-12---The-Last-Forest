class_name ClimateFact
extends Resource
## One micro-learning card. Create one .tres per fact in data/facts/.
## Text fields are TRANSLATION KEYS (see data/translations/facts.csv),
## so English and Filipino come from the same resource.

enum Delivery {
	CARD, ## Pauses the game, shows a picture card. Use for milestone facts.
	TIP,  ## Non-pausing speech bubble for 4 s. Use for small hints.
}

@export var id: StringName
@export var title_key: String
@export var body_key: String
## Picture-first: early readers understand the image before the words.
@export var image: Texture2D
## Optional narrated line (record in English AND Filipino if possible).
@export var voice_over: AudioStream
@export var delivery: Delivery = Delivery.CARD
@export_range(1, 4) var stage: int = 1
## Where this fact was verified (for the capstone panel). Not shown in-game.
@export_multiline var source_note: String = ""
