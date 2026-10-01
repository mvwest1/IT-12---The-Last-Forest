class_name QuizQuestion
extends Resource
## One picture-friendly multiple-choice question. Text fields are
## TRANSLATION KEYS (data/translations/ui.csv) so EN/FIL share one resource.

@export var prompt_key: String = ""
## 2–3 choices. Keep them short (≤ 5 words) for early readers.
@export var choice_keys: Array[String] = []
## Index into choice_keys of the right answer (before on-screen shuffling).
@export var correct_index: int = 0
@export var image: Texture2D
